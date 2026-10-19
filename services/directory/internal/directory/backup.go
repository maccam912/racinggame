package directory

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"time"
)

// The manifest is a completion marker. A folder without it is never restorable.
// Keys are held separately: KeyID detects accidentally selecting another deployment.
type BackupManifest struct {
	Format  int    `json:"format"`
	Service string `json:"service"`
	Created string `json:"created_at_utc"`
	Schema  int    `json:"schema"`
	Bytes   int64  `json:"bytes"`
	SHA256  string `json:"sha256"`
	KeyID   string `json:"key_id"`
}

func backupKeys(folder string) ([]byte, string, error) {
	encryption, signing, err := LoadKeys(folder)
	if err != nil {
		return nil, "", err
	}
	public, err := PublicPEM(&signing.PublicKey)
	if err != nil {
		return nil, "", err
	}
	h := sha256.New()
	h.Write(encryption)
	h.Write(public)
	return encryption, hex.EncodeToString(h.Sum(nil)), nil
}

func readDatabase(filename string, immutable bool) (*sql.DB, error) {
	full, err := filepath.Abs(filename)
	if err != nil {
		return nil, err
	}
	info, err := os.Lstat(full)
	if err != nil || !info.Mode().IsRegular() {
		return nil, errors.New("database must be an existing regular file")
	}
	query := url.Values{"mode": {"ro"}}
	if immutable {
		query.Set("immutable", "1")
	}
	uri := url.URL{Scheme: "file", Path: filepath.ToSlash(full), RawQuery: query.Encode()}
	db, err := sql.Open("sqlite", uri.String())
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	if _, err = db.Exec(`PRAGMA busy_timeout=5000; PRAGMA synchronous=FULL;`); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

func inspectDatabase(ctx context.Context, db *sql.DB, key []byte) (int, error) {
	var version int
	if err := db.QueryRowContext(ctx, `PRAGMA user_version`).Scan(&version); err != nil {
		return 0, err
	}
	if version > databaseVersion {
		return 0, errFutureDatabase
	}
	if version < 1 {
		return 0, errors.New("not a supported directory database")
	}
	var result string
	if err := db.QueryRowContext(ctx, `PRAGMA integrity_check`).Scan(&result); err != nil {
		return 0, err
	}
	if result != "ok" {
		return 0, errors.New("database integrity check failed")
	}
	rows, err := db.QueryContext(ctx, `PRAGMA foreign_key_check`)
	if err != nil {
		return 0, err
	}
	broken := rows.Next()
	err = rows.Err()
	rows.Close()
	if err != nil {
		return 0, err
	}
	if broken {
		return 0, errors.New("database foreign key check failed")
	}
	// Require the complete historical service layout, not just an arbitrary user_version.
	var count int
	if err = db.QueryRowContext(ctx, `SELECT count(*) FROM sqlite_schema WHERE type='table' AND name IN ('guests','nonces','sessions','rate_events','workers','rooms','reservations','worker_commands','service_events')`).Scan(&count); err != nil {
		return 0, err
	}
	if count != 9 {
		return 0, errors.New("incomplete directory database")
	}
	rows, err = db.QueryContext(ctx, `SELECT id,secret FROM guests`)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		var ciphertext []byte
		if err = rows.Scan(&id, &ciphertext); err != nil {
			return 0, err
		}
		secret, err := decryptSecret(key, ciphertext, id)
		if err != nil || !validUUID(id) || len(secret) != 32 {
			return 0, errors.New("database identity key verification failed")
		}
	}
	return version, rows.Err()
}

func syncFile(filename string) error {
	file, err := os.OpenFile(filename, os.O_RDWR, 0)
	if err != nil {
		return err
	}
	defer file.Close()
	return file.Sync()
}
func syncFolder(folder string) error {
	file, err := os.Open(folder)
	if err != nil {
		return err
	}
	defer file.Close()
	return file.Sync()
}
func fileDigest(filename string) (string, int64, error) {
	file, err := os.Open(filename)
	if err != nil {
		return "", 0, err
	}
	defer file.Close()
	h := sha256.New()
	size, err := io.Copy(h, file)
	return hex.EncodeToString(h.Sum(nil)), size, err
}

// BackupDatabase snapshots a live WAL database. It neither creates nor migrates
// the source. Only our new folder is ever removed on an unsuccessful attempt.
func BackupDatabase(ctx context.Context, source, folder, keys string) (manifest BackupManifest, err error) {
	encryption, keyID, err := backupKeys(keys)
	if err != nil {
		return manifest, err
	}
	db, err := readDatabase(source, false)
	if err != nil {
		return manifest, err
	}
	defer db.Close()
	var version int
	if err = db.QueryRowContext(ctx, `PRAGMA user_version`).Scan(&version); err != nil {
		return manifest, err
	}
	if version > databaseVersion {
		return manifest, errFutureDatabase
	}
	if version < 1 {
		return manifest, errors.New("not a supported directory database")
	}
	full, err := filepath.Abs(folder)
	if err != nil {
		return manifest, err
	}
	if err = os.MkdirAll(filepath.Dir(full), 0700); err != nil {
		return manifest, err
	}
	if err = os.Mkdir(full, 0700); err != nil {
		return manifest, errors.New("backup output must be a new folder")
	}
	defer func() {
		if err != nil {
			_ = os.RemoveAll(full)
		}
	}()
	target := filepath.Join(full, "directory.sqlite")
	file, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_RDWR, 0600)
	if err != nil {
		return manifest, err
	}
	if err = file.Close(); err != nil {
		return manifest, err
	}
	// Bound SQL parameter: paths containing quotes, '?', '#' and spaces stay paths.
	if _, err = db.ExecContext(ctx, `VACUUM INTO ?`, target); err != nil {
		return manifest, err
	}
	snapshot, err := readDatabase(target, true)
	if err != nil {
		return manifest, err
	}
	version, err = inspectDatabase(ctx, snapshot, encryption)
	closeErr := snapshot.Close()
	if err != nil {
		return manifest, err
	}
	if closeErr != nil {
		return manifest, closeErr
	}
	if err = syncFile(target); err != nil {
		return manifest, err
	}
	checksum, size, err := fileDigest(target)
	if err != nil {
		return manifest, err
	}
	manifest = BackupManifest{1, "pacific-rush-directory", time.Now().UTC().Format(time.RFC3339), version, size, checksum, keyID}
	file, err = os.OpenFile(filepath.Join(full, "manifest.pending"), os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return manifest, err
	}
	err = json.NewEncoder(file).Encode(manifest)
	if err == nil {
		err = file.Sync()
	}
	closeErr = file.Close()
	if err != nil {
		return manifest, err
	}
	if closeErr != nil {
		return manifest, closeErr
	}
	if err = os.Rename(filepath.Join(full, "manifest.pending"), filepath.Join(full, "manifest.json")); err != nil {
		return manifest, err
	}
	if err = syncFolder(full); err != nil {
		return manifest, err
	}
	err = syncFolder(filepath.Dir(full))
	return manifest, err
}

func readManifest(folder string) (BackupManifest, error) {
	var manifest BackupManifest
	filename := filepath.Join(folder, "manifest.json")
	info, err := os.Lstat(filename)
	if err != nil || !info.Mode().IsRegular() || info.Size() > 16384 {
		return manifest, errors.New("missing or invalid backup manifest")
	}
	file, err := os.Open(filename)
	if err != nil {
		return manifest, err
	}
	defer file.Close()
	decoder := json.NewDecoder(io.LimitReader(file, 16385))
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&manifest); err != nil {
		return manifest, errors.New("invalid backup manifest")
	}
	var trailing any
	if decoder.Decode(&trailing) != io.EOF {
		return manifest, errors.New("invalid backup manifest trailing data")
	}
	_, dateErr := time.Parse(time.RFC3339, manifest.Created)
	if manifest.Format != 1 || manifest.Service != "pacific-rush-directory" || manifest.Schema < 1 || manifest.Schema > databaseVersion || manifest.Bytes < 512 || !validBackupHash(manifest.SHA256) || !validBackupHash(manifest.KeyID) || dateErr != nil {
		return manifest, errors.New("unsupported or invalid backup manifest")
	}
	return manifest, nil
}

func requireAbsentDatabase(filename string) error {
	for _, suffix := range []string{"", "-wal", "-shm", "-journal"} {
		if _, err := os.Lstat(filename + suffix); !os.IsNotExist(err) {
			return errors.New("restore destination and SQLite sidecars must not exist")
		}
	}
	return nil
}

// RestoreDatabase always publishes to a new path. Restarting live game processes
// from a database is impossible; ephemeral admission/session state is discarded.
func RestoreDatabase(ctx context.Context, folder, destination, keys string) (BackupManifest, error) {
	manifest, err := readManifest(folder)
	if err != nil {
		return manifest, err
	}
	encryption, keyID, err := backupKeys(keys)
	if err != nil {
		return manifest, err
	}
	if keyID != manifest.KeyID {
		return manifest, errors.New("backup belongs to different operator keys")
	}
	source := filepath.Join(folder, "directory.sqlite")
	info, err := os.Lstat(source)
	if err != nil || !info.Mode().IsRegular() || info.Size() != manifest.Bytes {
		return manifest, errors.New("missing or incomplete backup database")
	}
	for _, suffix := range []string{"-wal", "-shm", "-journal"} {
		if _, err = os.Lstat(source + suffix); !os.IsNotExist(err) {
			return manifest, errors.New("backup must be a standalone SQLite snapshot")
		}
	}
	full, err := filepath.Abs(destination)
	if err != nil {
		return manifest, err
	}
	if err = requireAbsentDatabase(full); err != nil {
		return manifest, err
	}
	if err = os.MkdirAll(filepath.Dir(full), 0700); err != nil {
		return manifest, err
	}
	stage, err := os.MkdirTemp(filepath.Dir(full), ".directory-restore-")
	if err != nil {
		return manifest, err
	}
	defer os.RemoveAll(stage)
	staged := filepath.Join(stage, "directory.sqlite")
	input, err := os.Open(source)
	if err != nil {
		return manifest, err
	}
	output, err := os.OpenFile(staged, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		input.Close()
		return manifest, err
	}
	h := sha256.New()
	size, copyErr := io.Copy(io.MultiWriter(output, h), input)
	input.Close()
	closeErr := output.Close()
	if copyErr != nil {
		return manifest, copyErr
	}
	if closeErr != nil {
		return manifest, closeErr
	}
	if size != manifest.Bytes || hex.EncodeToString(h.Sum(nil)) != manifest.SHA256 {
		return manifest, errors.New("backup checksum mismatch")
	}
	snapshot, err := readDatabase(staged, true)
	if err != nil {
		return manifest, err
	}
	version, err := inspectDatabase(ctx, snapshot, encryption)
	snapshot.Close()
	if err != nil {
		return manifest, err
	}
	if version != manifest.Schema {
		return manifest, errors.New("backup schema does not match manifest")
	}
	// Migrate only the isolated copy. Original backup bytes remain unchanged.
	store, err := OpenStore(staged)
	if err != nil {
		return manifest, err
	}
	_, err = store.db.ExecContext(ctx, `BEGIN IMMEDIATE; DELETE FROM worker_commands; DELETE FROM reservations; DELETE FROM rooms; DELETE FROM workers; DELETE FROM nonces; DELETE FROM sessions; COMMIT;`)
	if err == nil {
		err = store.Prune(ctx, time.Now().Unix())
	}
	if err == nil {
		_, err = store.db.ExecContext(ctx, `PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE;`)
	}
	closeErr = store.Close()
	if err != nil {
		return manifest, err
	}
	if closeErr != nil {
		return manifest, closeErr
	}
	if err = syncFile(staged); err != nil {
		return manifest, err
	}
	if err = requireAbsentDatabase(full); err != nil {
		return manifest, err
	}
	// Link publishes atomically and cannot replace an existing file, even in a race.
	if err = os.Link(staged, full); err != nil {
		return manifest, err
	}
	if err = syncFolder(filepath.Dir(full)); err != nil {
		return manifest, err
	}
	return manifest, nil
}

func validBackupHash(value string) bool {
	data, err := hex.DecodeString(value)
	return err == nil && len(data) == 32 && hex.EncodeToString(data) == value
}
