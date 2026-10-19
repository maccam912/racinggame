package directory

import (
	"context"
	"crypto/subtle"
	"database/sql"

	"github.com/maccam912/racinggame/services/directory/internal/names"
)

func checkRate(ctx context.Context, tx *sql.Tx, subject, kind string, now, window int64, limit int) error {
	var count int
	if err := tx.QueryRowContext(ctx, `SELECT count(*) FROM rate_events WHERE subject=? AND kind=? AND at>?`, subject, kind, now-window).Scan(&count); err != nil {
		return err
	}
	if count >= limit {
		return &APIError{Code: "rate_limited", Status: 429, Retry: int(window)}
	}
	_, err := tx.ExecContext(ctx, `INSERT INTO rate_events(subject,kind,at) VALUES(?,?,?)`, subject, kind, now)
	return err
}
func newSession(ctx context.Context, tx *sql.Tx, guest, name string, now int64) (Session, error) {
	result := Session{Guest: guest, Name: name, Token: randomToken(), Expires: now + 3600}
	_, err := tx.ExecContext(ctx, `INSERT INTO sessions(hash,guest,expires) VALUES(?,?,?)`, digest(result.Token), guest, result.Expires)
	return result, err
}
func (s *Service) Register(ctx context.Context, guest, secretValue, nameValue string) (Session, error) {
	if !validUUID(guest) {
		return Session{}, apiError(400, "invalid_guest")
	}
	secret, err := decodeSecret(secretValue)
	if err != nil {
		return Session{}, apiError(400, "invalid_guest")
	}
	name, err := names.Validate(nameValue, 16)
	if err != nil {
		return Session{}, apiError(400, "invalid_name")
	}
	ciphertext, err := encryptSecret(s.config.EncryptionKey, secret, guest)
	if err != nil {
		return Session{}, err
	}
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return Session{}, err
	}
	defer tx.Rollback()
	var existingName string
	var existing []byte
	var banned int
	err = tx.QueryRowContext(ctx, `SELECT name,secret,banned FROM guests WHERE id=?`, guest).Scan(&existingName, &existing, &banned)
	now := s.config.Now().Unix()
	if err == sql.ErrNoRows {
		_, err = tx.ExecContext(ctx, `INSERT INTO guests(id,name,secret,created) VALUES(?,?,?,?)`, guest, name, ciphertext, now)
	} else if err == nil {
		stored, decryptErr := decryptSecret(s.config.EncryptionKey, existing, guest)
		if decryptErr != nil || subtle.ConstantTimeCompare(stored, secret) != 1 || banned != 0 {
			return Session{}, apiError(409, "invalid_guest")
		}
		if name != existingName {
			if err = checkRate(ctx, tx, guest, "name", now, 3600, 5); err != nil {
				return Session{}, err
			}
			_, err = tx.ExecContext(ctx, `UPDATE guests SET name=? WHERE id=?`, name, guest)
		}
	}
	if err != nil {
		return Session{}, err
	}
	session, err := newSession(ctx, tx, guest, name, now)
	if err != nil {
		return Session{}, err
	}
	if err = tx.Commit(); err != nil {
		return Session{}, err
	}
	return session, nil
}
func (s *Service) Challenge(ctx context.Context, guest string) (string, int64, error) {
	if !validUUID(guest) {
		return "", 0, apiError(400, "invalid_guest")
	}
	nonce := randomToken()
	expires := s.config.Now().Unix() + 60
	// Unknown guests get the same response shape and timing contract.
	_, err := s.store.db.ExecContext(ctx, `INSERT INTO nonces(hash,guest,expires) SELECT ?,id,? FROM guests WHERE id=? AND banned=0`, digest(nonce), expires, guest)
	return nonce, expires, err
}
func (s *Service) Authenticate(ctx context.Context, guest, nonce, proof, nameValue string) (Session, error) {
	name, err := names.Validate(nameValue, 16)
	if err != nil {
		return Session{}, apiError(400, "invalid_name")
	}
	if !validUUID(guest) || len(nonce) != 43 {
		return Session{}, apiError(401, "invalid_auth")
	}
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return Session{}, err
	}
	defer tx.Rollback()
	now := s.config.Now().Unix()
	var expires int64
	var ciphertext []byte
	var oldName string
	var banned int
	err = tx.QueryRowContext(ctx, `SELECT n.expires,g.secret,g.name,g.banned FROM nonces n JOIN guests g ON g.id=n.guest WHERE n.hash=? AND n.guest=?`, digest(nonce), guest).Scan(&expires, &ciphertext, &oldName, &banned)
	if err == sql.ErrNoRows {
		return Session{}, apiError(401, "invalid_auth")
	}
	if err != nil {
		return Session{}, err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM nonces WHERE hash=? AND guest=?`, digest(nonce), guest); err != nil {
		return Session{}, err
	}
	secret, err := decryptSecret(s.config.EncryptionKey, ciphertext, guest)
	valid := err == nil && expires > now && banned == 0 && equalString(AuthProof(secret, guest, nonce, name), proof)
	if !valid {
		if err = tx.Commit(); err != nil {
			return Session{}, err
		}
		return Session{}, apiError(401, "invalid_auth")
	}
	if oldName != name {
		if err = checkRate(ctx, tx, guest, "name", now, 3600, 5); err != nil {
			_ = tx.Commit()
			return Session{}, err
		}
		if _, err = tx.ExecContext(ctx, `UPDATE guests SET name=? WHERE id=?`, name, guest); err != nil {
			return Session{}, err
		}
	}
	session, err := newSession(ctx, tx, guest, name, now)
	if err != nil {
		return Session{}, err
	}
	if err = tx.Commit(); err != nil {
		return Session{}, err
	}
	return session, nil
}
func (s *Service) Authorize(ctx context.Context, token string) (Session, error) {
	if _, err := decodeSecret(token); err != nil {
		return Session{}, apiError(401, "unauthorized")
	}
	var result Session
	err := s.store.db.QueryRowContext(ctx, `SELECT g.id,g.name,s.expires FROM sessions s JOIN guests g ON g.id=s.guest WHERE s.hash=? AND s.expires>? AND g.banned=0`, digest(token), s.config.Now().Unix()).Scan(&result.Guest, &result.Name, &result.Expires)
	if err == sql.ErrNoRows {
		return Session{}, apiError(401, "unauthorized")
	}
	return result, err
}
