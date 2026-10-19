package directory

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func backupService(t *testing.T) (*Service, string, string) {
	t.Helper()
	root := t.TempDir()
	keys := filepath.Join(root, "keys")
	if err := GenerateKeys(keys); err != nil {
		t.Fatal(err)
	}
	encryption, signing, err := LoadKeys(keys)
	if err != nil {
		t.Fatal(err)
	}
	filename := filepath.Join(root, "live.sqlite")
	store, err := OpenStore(filename)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.Close() })
	service, err := New(store, Config{EncryptionKey: encryption, SigningKey: signing, Protocol: 5, Content: strings.Repeat("a", 64)})
	if err != nil {
		t.Fatal(err)
	}
	return service, filename, keys
}
func backupCount(t *testing.T, db *sql.DB, table string) int {
	t.Helper()
	var count int
	if err := db.QueryRow(`SELECT count(*) FROM ` + table).Scan(&count); err != nil {
		t.Fatal(err)
	}
	return count
}

func TestLiveWALBackupRestoresIdentityButNotLeasesOrReplayState(t *testing.T) {
	s, filename, keys := backupService(t)
	ctx := context.Background()
	newAllocator(s)
	guest, secret := UUID(), randomBytes(32)
	session, err := s.Register(ctx, guest, raw64.EncodeToString(secret), "Café Driver")
	if err != nil {
		t.Fatal(err)
	}
	banned := guestFor(t, s)
	created := createFor(t, s, session, false)
	if _, _, err = s.Challenge(ctx, guest); err != nil {
		t.Fatal(err)
	}
	if err = s.store.Ban(banned.Guest, true); err != nil {
		t.Fatal(err)
	}
	if _, err = s.store.db.Exec(`INSERT INTO worker_commands VALUES(?,?,?,?,?)`, UUID(), created.Worker, "kick", guest, time.Now().Unix()); err != nil {
		t.Fatal(err)
	}
	var encrypted []byte
	if err = s.store.db.QueryRow(`SELECT secret FROM guests WHERE id=?`, guest).Scan(&encrypted); err != nil {
		t.Fatal(err)
	}
	if _, err = s.store.db.Exec(`PRAGMA wal_autocheckpoint=0`); err != nil {
		t.Fatal(err)
	}
	// Hold a reader at the old snapshot so these committed writes stay in WAL.
	reader, err := readDatabase(filename, false)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	tx, err := reader.Begin()
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback()
	var count int
	if err = tx.QueryRow(`SELECT count(*) FROM guests`).Scan(&count); err != nil {
		t.Fatal(err)
	}
	var writes atomic.Int64
	var wg sync.WaitGroup
	stop := make(chan struct{})
	failures := make(chan error, 1)
	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			select {
			case <-stop:
				return
			default:
			}
			if _, err := s.store.db.Exec(`BEGIN IMMEDIATE; INSERT INTO rate_events VALUES('backup-counter','a',?); INSERT INTO rate_events VALUES('backup-counter','b',?); COMMIT;`, time.Now().Unix(), time.Now().Unix()); err != nil {
				failures <- err
				return
			}
			writes.Add(1)
			time.Sleep(time.Millisecond)
		}
	}()
	defer func() {
		close(stop)
		wg.Wait()
		select {
		case err := <-failures:
			t.Error(err)
		default:
		}
	}()
	for writes.Load() < 3 {
		time.Sleep(time.Millisecond)
	}
	wal, err := os.Stat(filename + "-wal")
	if err != nil || wal.Size() == 0 {
		t.Fatal("fixture did not retain committed WAL")
	}
	folder := filepath.Join(t.TempDir(), "snapshot 'quotes' ? # spaces")
	manifest, err := BackupDatabase(ctx, filename, folder, keys)
	if err != nil {
		t.Fatal(err)
	}
	if manifest.Schema != DatabaseSchemaVersion || manifest.Bytes < 4096 || manifest.KeyID == "" {
		t.Fatal(manifest)
	}
	snapshot := filepath.Join(folder, "directory.sqlite")
	db, err := readDatabase(snapshot, true)
	if err != nil {
		t.Fatal(err)
	}
	if backupCount(t, db, "workers") != 1 || backupCount(t, db, "guests") != 2 {
		t.Fatal("backup missed live rows")
	}
	var left, right int
	if err = db.QueryRow(`SELECT sum(kind='a'),sum(kind='b') FROM rate_events WHERE subject='backup-counter'`).Scan(&left, &right); err != nil || left < 3 || left != right {
		t.Fatal("inconsistent concurrent snapshot", left, right, err)
	}
	db.Close()
	before, _ := os.ReadFile(snapshot)
	restored := filepath.Join(t.TempDir(), "restored.sqlite")
	if _, err = RestoreDatabase(ctx, folder, restored, keys); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(snapshot)
	if !bytes.Equal(before, after) {
		t.Fatal("restore changed backup")
	}
	recovered, err := OpenStore(restored)
	if err != nil {
		t.Fatal(err)
	}
	defer recovered.Close()
	for _, table := range []string{"workers", "rooms", "reservations", "worker_commands", "nonces", "sessions"} {
		if backupCount(t, recovered.db, table) != 0 {
			t.Fatal("restored ephemeral state", table)
		}
	}
	var recoveredBytes []byte
	if err = recovered.db.QueryRow(`SELECT secret FROM guests WHERE id=?`, guest).Scan(&recoveredBytes); err != nil || !bytes.Equal(encrypted, recoveredBytes) {
		t.Fatal("encrypted identity changed", err)
	}
	service, err := New(recovered, s.config)
	if err != nil {
		t.Fatal(err)
	}
	_, err = service.Authorize(ctx, session.Token)
	expectCode(t, err, "unauthorized")
	nonce, _, err := service.Challenge(ctx, guest)
	if err != nil {
		t.Fatal(err)
	}
	result, err := service.Authenticate(ctx, guest, nonce, AuthProof(secret, guest, nonce, session.Name), session.Name)
	if err != nil || result.Guest != guest {
		t.Fatal("original identity failed authentication", err)
	}
	if _, err = service.Register(ctx, banned.Guest, randomToken(), banned.Name); err == nil {
		t.Fatal("ban was lost")
	}
	if backupCount(t, s.store.db, "workers") != 1 {
		t.Fatal("live source was cleared")
	}
	info, _ := os.Stat(restored)
	if info.Mode().Perm() != 0600 {
		t.Fatal("restore permissions", info.Mode())
	}
}

func TestBackupRestoreRefusesExistingIncompleteCorruptWrongKeysAndFuture(t *testing.T) {
	s, filename, keys := backupService(t)
	guestFor(t, s)
	ctx := context.Background()
	folder := filepath.Join(t.TempDir(), "backup")
	if _, err := BackupDatabase(ctx, filename, folder, keys); err != nil {
		t.Fatal(err)
	}
	manifestBefore, _ := os.ReadFile(filepath.Join(folder, "manifest.json"))
	if _, err := BackupDatabase(ctx, filename, folder, keys); err == nil {
		t.Fatal("overwrote backup folder")
	}
	unchanged, _ := os.ReadFile(filepath.Join(folder, "manifest.json"))
	if !bytes.Equal(manifestBefore, unchanged) {
		t.Fatal("existing backup changed")
	}
	missing := filepath.Join(t.TempDir(), "does-not-exist.sqlite")
	if _, err := BackupDatabase(ctx, missing, filepath.Join(t.TempDir(), "new"), keys); err == nil {
		t.Fatal("created absent source")
	}
	if _, err := os.Stat(missing); !os.IsNotExist(err) {
		t.Fatal("missing source was created")
	}
	otherKeys := filepath.Join(t.TempDir(), "wrong-keys")
	if err := GenerateKeys(otherKeys); err != nil {
		t.Fatal(err)
	}
	destination := filepath.Join(t.TempDir(), "restored.sqlite")
	if _, err := RestoreDatabase(ctx, folder, destination, otherKeys); err == nil {
		t.Fatal("accepted wrong keys")
	}
	if _, err := os.Stat(destination); !os.IsNotExist(err) {
		t.Fatal("wrong keys wrote output")
	}
	for _, suffix := range []string{"", "-wal", "-shm", "-journal"} {
		target := filepath.Join(t.TempDir(), "occupied.sqlite")
		if err := os.WriteFile(target+suffix, []byte("preserve exact bytes"), 0600); err != nil {
			t.Fatal(err)
		}
		if _, err := RestoreDatabase(ctx, folder, target, keys); err == nil {
			t.Fatal("replaced existing database/sidecar", suffix)
		}
		data, _ := os.ReadFile(target + suffix)
		if string(data) != "preserve exact bytes" {
			t.Fatal("changed destination")
		}
	}
	for _, mode := range []string{"incomplete", "checksum", "truncated", "future", "foreign-key", "identity-key", "trailing-manifest", "symlink"} {
		t.Run(mode, func(t *testing.T) {
			root := t.TempDir()
			copyFolder := filepath.Join(root, "backup")
			os.Mkdir(copyFolder, 0700)
			payload, _ := os.ReadFile(filepath.Join(folder, "directory.sqlite"))
			os.WriteFile(filepath.Join(copyFolder, "directory.sqlite"), payload, 0600)
			os.WriteFile(filepath.Join(copyFolder, "manifest.json"), manifestBefore, 0600)
			switch mode {
			case "incomplete":
				os.Remove(filepath.Join(copyFolder, "manifest.json"))
			case "checksum":
				payload[len(payload)/2] ^= 0xff
				os.WriteFile(filepath.Join(copyFolder, "directory.sqlite"), payload, 0600)
			case "truncated":
				os.WriteFile(filepath.Join(copyFolder, "directory.sqlite"), payload[:512], 0600)
			case "future", "foreign-key", "identity-key":
				db, err := sql.Open("sqlite", filepath.Join(copyFolder, "directory.sqlite"))
				if err != nil {
					t.Fatal(err)
				}
				query := `PRAGMA user_version=99`
				if mode == "foreign-key" {
					query = `INSERT INTO sessions VALUES(X'01','missing-guest',9999999999)`
				}
				if mode == "identity-key" {
					query = `UPDATE guests SET secret=X'01'`
				}
				if _, err = db.Exec(query); err != nil {
					t.Fatal(err)
				}
				db.Close()
				var manifest BackupManifest
				json.Unmarshal(manifestBefore, &manifest)
				manifest.SHA256, manifest.Bytes, _ = fileDigest(filepath.Join(copyFolder, "directory.sqlite"))
				if mode == "future" {
					manifest.Schema = 99
				}
				data, _ := json.Marshal(manifest)
				os.WriteFile(filepath.Join(copyFolder, "manifest.json"), data, 0600)
			case "trailing-manifest":
				os.WriteFile(filepath.Join(copyFolder, "manifest.json"), append(manifestBefore, []byte(` {"format":1}`)...), 0600)
			case "symlink":
				os.Remove(filepath.Join(copyFolder, "directory.sqlite"))
				if err := os.Symlink(filepath.Join(folder, "directory.sqlite"), filepath.Join(copyFolder, "directory.sqlite")); err != nil {
					t.Skip(err)
				}
			}
			target := filepath.Join(root, "output.sqlite")
			if _, err := RestoreDatabase(ctx, copyFolder, target, keys); err == nil {
				t.Fatal("accepted invalid backup", mode)
			}
			if _, err := os.Stat(target); !os.IsNotExist(err) {
				t.Fatal("invalid backup published output")
			}
		})
	}
	// Backup itself refuses future source versions without migration or byte edits.
	if _, err := s.store.db.Exec(`PRAGMA user_version=99; PRAGMA wal_checkpoint(TRUNCATE)`); err != nil {
		t.Fatal(err)
	}
	sourceBefore, _ := os.ReadFile(filename)
	if _, err := BackupDatabase(ctx, filename, filepath.Join(t.TempDir(), "future"), keys); err == nil {
		t.Fatal("backed up unsupported future schema")
	}
	sourceAfter, _ := os.ReadFile(filename)
	if !bytes.Equal(sourceBefore, sourceAfter) {
		t.Fatal("future source bytes changed")
	}
}

func TestBackupHistoricalSchemasRestoreOnCopy(t *testing.T) {
	for _, version := range []int{1, 2, 3} {
		t.Run(string(rune('0'+version)), func(t *testing.T) {
			s, filename, keys := backupService(t)
			s.store.Close()
			os.Remove(filename)
			db, err := sql.Open("sqlite", filename)
			if err != nil {
				t.Fatal(err)
			}
			fixture, err := os.ReadFile(filepath.Join("testdata", "schema"+string(rune('0'+version))+".sql"))
			if err != nil {
				t.Fatal(err)
			}
			if _, err = db.Exec(string(fixture) + "; PRAGMA user_version=" + string(rune('0'+version))); err != nil {
				t.Fatal(err)
			}
			guest, secret := UUID(), randomBytes(32)
			encrypted, err := encryptSecret(s.config.EncryptionKey, secret, guest)
			if err != nil {
				t.Fatal(err)
			}
			if _, err = db.Exec(`INSERT INTO guests(id,name,secret,created) VALUES(?,?,?,?)`, guest, "Driver", encrypted, time.Now().Unix()); err != nil {
				t.Fatal(err)
			}
			db.Close()
			ctx := context.Background()
			folder := filepath.Join(t.TempDir(), "backup")
			manifest, err := BackupDatabase(ctx, filename, folder, keys)
			if err != nil || manifest.Schema != version {
				t.Fatal("historical snapshot", manifest, err)
			}
			before, _ := os.ReadFile(filepath.Join(folder, "directory.sqlite"))
			output := filepath.Join(t.TempDir(), "upgraded.sqlite")
			if _, err = RestoreDatabase(ctx, folder, output, keys); err != nil {
				t.Fatal(err)
			}
			restored, err := OpenStore(output)
			if err != nil {
				t.Fatal(err)
			}
			defer restored.Close()
			var current int
			restored.db.QueryRow(`PRAGMA user_version`).Scan(&current)
			if current != DatabaseSchemaVersion || backupCount(t, restored.db, "guests") != 1 {
				t.Fatal("copy migration failed")
			}
			after, _ := os.ReadFile(filepath.Join(folder, "directory.sqlite"))
			if !bytes.Equal(before, after) {
				t.Fatal("migrated original backup")
			}
		})
	}
}
