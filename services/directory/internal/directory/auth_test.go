package directory

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"errors"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

var testKey *rsa.PrivateKey
var testKeyOnce sync.Once

func testService(t *testing.T) (*Service, *atomic.Int64) {
	t.Helper()
	testKeyOnce.Do(func() {
		var err error
		testKey, err = rsa.GenerateKey(rand.Reader, 2048)
		if err != nil {
			panic(err)
		}
	})
	store, err := OpenStore(filepath.Join(t.TempDir(), "directory.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.Close() })
	clock := &atomic.Int64{}
	clock.Store(1800000000)
	service, err := New(store, Config{EncryptionKey: randomBytes(32), SigningKey: testKey, Protocol: 3, Content: strings.Repeat("a", 64), Now: func() time.Time { return time.Unix(clock.Load(), 0) }})
	if err != nil {
		t.Fatal(err)
	}
	return service, clock
}
func expectCode(t *testing.T, err error, code string) {
	t.Helper()
	var api *APIError
	if !errors.As(err, &api) || api.Code != code {
		t.Fatalf("wanted %s, got %v", code, err)
	}
}
func TestGuestEncryptionAuthenticationReplayAndExpiry(t *testing.T) {
	s, clock := testService(t)
	ctx := context.Background()
	guest := UUID()
	secret := randomBytes(32)
	session, err := s.Register(ctx, guest, raw64.EncodeToString(secret), "Cafe\u0301")
	if err != nil {
		t.Fatal(err)
	}
	if session.Name != "Café" || session.Expires != clock.Load()+3600 {
		t.Fatal("canonical name/session expiry")
	}
	var encrypted, tokenHash []byte
	if err = s.store.db.QueryRow(`SELECT secret FROM guests WHERE id=?`, guest).Scan(&encrypted); err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encrypted, secret) {
		t.Fatal("plaintext secret stored")
	}
	if _, err = decryptSecret(s.config.EncryptionKey, encrypted, UUID()); err == nil {
		t.Fatal("ciphertext was not guest-bound")
	}
	if err = s.store.db.QueryRow(`SELECT hash FROM sessions`).Scan(&tokenHash); err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(tokenHash, []byte(session.Token)) || !bytes.Equal(tokenHash, digest(session.Token)) {
		t.Fatal("bearer token not stored as digest")
	}
	if authorized, err := s.Authorize(ctx, session.Token); err != nil || authorized.Guest != guest {
		t.Fatal("session authorization")
	}
	nonce, expires, err := s.Challenge(ctx, guest)
	if err != nil || expires != clock.Load()+60 {
		t.Fatal("challenge expiry")
	}
	proof := AuthProof(secret, guest, nonce, "Café")
	if _, err = s.Authenticate(ctx, guest, nonce, proof, "Cafe\u0301"); err != nil {
		t.Fatal(err)
	}
	_, err = s.Authenticate(ctx, guest, nonce, proof, "Café")
	expectCode(t, err, "invalid_auth")
	nonce, _, _ = s.Challenge(ctx, guest)
	_, err = s.Authenticate(ctx, guest, nonce, strings.Repeat("x", 43), "Café")
	expectCode(t, err, "invalid_auth")
	_, err = s.Authenticate(ctx, guest, nonce, AuthProof(secret, guest, nonce, "Café"), "Café")
	expectCode(t, err, "invalid_auth")
	nonce, _, _ = s.Challenge(ctx, guest)
	clock.Add(60)
	_, err = s.Authenticate(ctx, guest, nonce, AuthProof(secret, guest, nonce, "Café"), "Café")
	expectCode(t, err, "invalid_auth")
	clock.Add(3540)
	_, err = s.Authorize(ctx, session.Token)
	expectCode(t, err, "unauthorized")
	if err = s.store.Prune(ctx, clock.Load()); err != nil {
		t.Fatal(err)
	}
	var count int
	s.store.db.QueryRow(`SELECT count(*) FROM sessions`).Scan(&count)
	if count != 0 {
		t.Fatal("expired sessions were not pruned")
	}
}
func TestNonceBindingNameRateLimitAndBan(t *testing.T) {
	s, _ := testService(t)
	ctx := context.Background()
	guest := UUID()
	secret := randomToken()
	if _, err := s.Register(ctx, guest, secret, "Driver Original"); err != nil {
		t.Fatal(err)
	}
	nonce, _, _ := s.Challenge(ctx, guest)
	bytes, _ := decodeSecret(secret)
	_, err := s.Authenticate(ctx, UUID(), nonce, AuthProof(bytes, guest, nonce, "Driver Original"), "Driver Original")
	expectCode(t, err, "invalid_auth")
	if _, err = s.Authenticate(ctx, guest, nonce, AuthProof(bytes, guest, nonce, "Driver Original"), "Driver Original"); err != nil {
		t.Fatal("wrong guest consumed another guest's nonce")
	}
	for _, name := range []string{"Driver A", "Driver B", "Driver C", "Driver D", "Driver E"} {
		if _, err = s.Register(ctx, guest, secret, name); err != nil {
			t.Fatal(err)
		}
	}
	_, err = s.Register(ctx, guest, secret, "Driver F")
	expectCode(t, err, "rate_limited")
	_, err = s.Register(ctx, guest, randomToken(), "Driver E")
	expectCode(t, err, "invalid_guest")
	session, err := s.Register(ctx, guest, secret, "Driver E")
	if err != nil {
		t.Fatal("idempotent registration retry", err)
	}
	s.store.db.Exec(`UPDATE guests SET banned=1 WHERE id=?`, guest)
	_, err = s.Authorize(ctx, session.Token)
	expectCode(t, err, "unauthorized")
}
func TestTicketSignatureBindingsExpiryAndPacketBudget(t *testing.T) {
	s, clock := testService(t)
	claims := TicketClaims{Version: 1, Guest: UUID(), Name: strings.Repeat("👨‍👩‍👧‍👦", 3) + "ab", Room: UUID(), Worker: UUID(), Protocol: 3, Content: s.config.Content, Issued: clock.Load(), Expires: clock.Load() + 60, Nonce: "0123456789abcdef0123456789abcdef"}
	ticket, err := SignTicket(s.config.SigningKey, claims)
	if err != nil {
		t.Fatal(err)
	}
	if len(ticket)+80 > 1200 {
		t.Fatal("admission hello exceeds datagram budget")
	}
	verify := func(value, room, worker string, now int64) error {
		_, err := VerifyTicket(&testKey.PublicKey, value, time.Unix(now, 0), room, worker, 3, s.config.Content)
		return err
	}
	if err = verify(ticket, claims.Room, claims.Worker, clock.Load()); err != nil {
		t.Fatal(err)
	}
	if verify(ticket, UUID(), claims.Worker, clock.Load()) == nil || verify(ticket, claims.Room, UUID(), clock.Load()) == nil {
		t.Fatal("ticket was not room/worker bound")
	}
	if verify(ticket, claims.Room, claims.Worker, clock.Load()+60) == nil {
		t.Fatal("ticket valid at expiry")
	}
	altered := []byte(ticket)
	altered[12] = 'A'
	if verify(string(altered), claims.Room, claims.Worker, clock.Load()) == nil {
		t.Fatal("altered ticket accepted")
	}
}
