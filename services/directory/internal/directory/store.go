package directory

import (
	"context"
	"database/sql"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

type Store struct{ db *sql.DB }

func OpenStore(filename string) (*Store, error) {
	full, err := filepath.Abs(filename)
	if err != nil {
		return nil, err
	}
	if err = os.MkdirAll(filepath.Dir(full), 0700); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(full, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, err
	}
	file.Close()
	if err = os.Chmod(full, 0600); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", full)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	fail := func(err error) (*Store, error) { db.Close(); return nil, err }
	if _, err = db.Exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;`); err != nil {
		return fail(err)
	}
	var version int
	if err = db.QueryRow(`PRAGMA user_version`).Scan(&version); err != nil {
		return fail(err)
	}
	if version > 1 {
		return fail(errFutureDatabase)
	}
	if _, err = db.Exec(schema); err != nil {
		return fail(err)
	}
	return &Store{db: db}, nil
}
func (s *Store) Close() error { return s.db.Close() }
func (s *Store) Prune(ctx context.Context, now int64) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM nonces WHERE expires<=?; DELETE FROM sessions WHERE expires<=?; DELETE FROM rate_events WHERE at<?; DELETE FROM reservations WHERE expires<=?;`, now, now, now-86400, now)
	return err
}

const schema = `
CREATE TABLE IF NOT EXISTS guests(id TEXT PRIMARY KEY, name TEXT NOT NULL, secret BLOB NOT NULL, created INTEGER NOT NULL, banned INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS nonces(hash BLOB PRIMARY KEY, guest TEXT NOT NULL REFERENCES guests(id), expires INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS sessions(hash BLOB PRIMARY KEY, guest TEXT NOT NULL REFERENCES guests(id), expires INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS rate_events(subject TEXT NOT NULL, kind TEXT NOT NULL, at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS rate_lookup ON rate_events(subject,kind,at);
CREATE TABLE IF NOT EXISTS workers(id TEXT PRIMARY KEY, room TEXT UNIQUE NOT NULL, token_hash BLOB NOT NULL, port INTEGER UNIQUE NOT NULL, heartbeat INTEGER NOT NULL, ready INTEGER NOT NULL DEFAULT 0, state TEXT NOT NULL, guests TEXT NOT NULL DEFAULT '[]');
CREATE TABLE IF NOT EXISTS rooms(id TEXT PRIMARY KEY, worker TEXT UNIQUE NOT NULL REFERENCES workers(id), name TEXT NOT NULL, private INTEGER NOT NULL, code TEXT UNIQUE NOT NULL, created INTEGER NOT NULL, creator TEXT NOT NULL REFERENCES guests(id), rules TEXT NOT NULL, protocol INTEGER NOT NULL, content TEXT NOT NULL, closed INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS reservations(room TEXT NOT NULL REFERENCES rooms(id), guest TEXT NOT NULL REFERENCES guests(id), nonce TEXT NOT NULL UNIQUE, expires INTEGER NOT NULL, consumed INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(room,guest));
PRAGMA user_version=1;
`
