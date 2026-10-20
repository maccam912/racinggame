package directory

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakeAllocator struct {
	service     *Service
	mu          sync.Mutex
	allocations map[string]Allocation
	noReady     bool
	fail        bool
	stopped     int
}

func newAllocator(s *Service) *fakeAllocator {
	a := &fakeAllocator{service: s, allocations: map[string]Allocation{}}
	s.config.Allocator = a
	return a
}
func (a *fakeAllocator) Start(ctx context.Context, allocation Allocation) error {
	a.mu.Lock()
	a.allocations[allocation.ID] = allocation
	a.mu.Unlock()
	if a.fail {
		return errors.New("start failed")
	}
	if a.noReady {
		return nil
	}
	_, err := a.service.Heartbeat(ctx, allocation.ID, allocation.Token, heartbeatFor(allocation, "Lobby", nil))
	return err
}
func (a *fakeAllocator) Stop(id string) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.stopped++
	delete(a.allocations, id)
	return nil
}
func (a *fakeAllocator) get(id string) Allocation {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.allocations[id]
}
func heartbeatFor(a Allocation, state string, guests []string) HeartbeatRequest {
	if guests == nil {
		guests = []string{}
	}
	return HeartbeatRequest{State: state, Ready: true, Guests: guests, Rules: a.Rules, Name: a.Name, Private: a.Private}
}
func guestFor(t *testing.T, s *Service) Session {
	t.Helper()
	session, err := s.Register(context.Background(), UUID(), randomToken(), "Test Driver")
	if err != nil {
		t.Fatal(err)
	}
	return session
}
func createFor(t *testing.T, s *Service, guest Session, private bool) JoinReply {
	t.Helper()
	reply, err := s.CreateRoom(context.Background(), guest, CreateRequest{Name: "Test Room", Private: private, Region: s.config.Region, Rules: Rules{Track: 0, Laps: 2, BotFill: true, Difficulty: 1, Contact: true}, Protocol: s.config.Protocol, Content: s.config.Content})
	if err != nil {
		t.Fatal(err)
	}
	return reply
}
func claimsFor(t *testing.T, s *Service, reply JoinReply) TicketClaims {
	t.Helper()
	claims, err := VerifyTicket(&s.config.SigningKey.PublicKey, reply.Ticket, s.config.Now(), reply.Room, reply.Worker, s.config.Protocol, s.config.Content)
	if err != nil {
		t.Fatal(err)
	}
	return claims
}

func TestConcurrentFinalSeatAndTicketConsumption(t *testing.T) {
	s, clock := testService(t)
	a := newAllocator(s)
	ctx := context.Background()
	host := guestFor(t, s)
	created := createFor(t, s, host, false)
	people := make([]Session, 12)
	for index := range people {
		people[index] = guestFor(t, s)
	}
	var wg sync.WaitGroup
	replies := make(chan JoinReply, len(people))
	failures := make(chan error, len(people))
	for _, guest := range people {
		wg.Add(1)
		go func(guest Session) {
			defer wg.Done()
			reply, err := s.JoinRoom(ctx, guest, created.Room, 3, s.config.Content)
			if err != nil {
				failures <- err
			} else {
				replies <- reply
			}
		}(guest)
	}
	wg.Wait()
	close(replies)
	close(failures)
	if len(replies) != 7 || len(failures) != 5 {
		t.Fatalf("seats %d failures %d", len(replies), len(failures))
	}
	for err := range failures {
		expectCode(t, err, "room_unavailable")
	}
	rooms, err := s.Rooms(ctx, 3, s.config.Content, true)
	if err != nil || len(rooms) != 1 || rooms[0].Humans != 8 {
		t.Fatal("eight-seat union", rooms, err)
	}
	allocation := a.get(created.Worker)
	claims := claimsFor(t, s, created)
	if err = s.Consume(ctx, created.Worker, allocation.Token, host.Guest, claims.Nonce); err != nil {
		t.Fatal(err)
	}
	if err = s.Consume(ctx, created.Worker, allocation.Token, host.Guest, claims.Nonce); err != nil {
		t.Fatal("HTTP retry not idempotent", err)
	}
	if err = s.Consume(ctx, created.Worker, randomToken(), host.Guest, claims.Nonce); err == nil {
		t.Fatal("wrong worker credential accepted")
	}
	// Refreshing the same guest replaces the nonce, never adds a seat.
	newer, err := s.JoinRoom(ctx, host, created.Room, 3, s.config.Content)
	if err != nil {
		t.Fatal(err)
	}
	expectCode(t, s.Consume(ctx, created.Worker, allocation.Token, host.Guest, claims.Nonce), "admission_expired")
	claims = claimsFor(t, s, newer)
	// Every original hold expires. Eight fresh guests reserve the seats.
	clock.Add(15)
	_, err = s.Heartbeat(ctx, allocation.ID, allocation.Token, heartbeatFor(allocation, "Lobby", nil))
	if err != nil {
		t.Fatal(err)
	}
	for _, guest := range people[:8] {
		if _, err = s.JoinRoom(ctx, guest, created.Room, 3, s.config.Content); err != nil {
			t.Fatal(err)
		}
	}
	expectCode(t, s.Consume(ctx, created.Worker, allocation.Token, host.Guest, claims.Nonce), "room_unavailable")
	clock.Add(45)
	expectCode(t, s.Consume(ctx, created.Worker, allocation.Token, host.Guest, claims.Nonce), "admission_expired")
}
func TestVisibilityCodesLivenessAndWorkerCommands(t *testing.T) {
	s, clock := testService(t)
	a := newAllocator(s)
	ctx := context.Background()
	host := guestFor(t, s)
	private := createFor(t, s, host, true)
	public := createFor(t, s, host, false)
	other := guestFor(t, s)
	rooms, err := s.Rooms(ctx, 3, s.config.Content, false)
	if err != nil || len(rooms) != 1 || rooms[0].ID != public.Room {
		t.Fatal("private room advertised", rooms, err)
	}
	_, err = s.JoinRoom(ctx, other, private.Room, 3, s.config.Content)
	expectCode(t, err, "room_unavailable")
	_, err = s.JoinCode(ctx, other, "bad-code", 3, s.config.Content)
	expectCode(t, err, "room_unavailable")
	_, err = s.JoinCode(ctx, other, private.Code, 99, s.config.Content)
	expectCode(t, err, "room_unavailable")
	formatted := strings.ToLower(private.Code[:4] + "-" + private.Code[4:])
	joined, err := s.JoinCode(ctx, other, formatted, 3, s.config.Content)
	if err != nil {
		t.Fatal(err)
	}
	allocation := a.get(joined.Worker)
	claims := claimsFor(t, s, joined)
	// Another worker's credentials cannot consume this reservation.
	different := a.get(public.Worker)
	expectCode(t, s.Consume(ctx, different.ID, different.Token, other.Guest, claims.Nonce), "admission_expired")
	if err = s.Consume(ctx, allocation.ID, allocation.Token, other.Guest, claims.Nonce); err != nil {
		t.Fatal(err)
	}
	if err = s.LeaveRoom(ctx, other, joined.Room); err != nil {
		t.Fatal(err)
	}
	if err = s.LeaveRoom(ctx, other, joined.Room); err != nil {
		t.Fatal(err)
	}
	heartbeat := heartbeatFor(allocation, "Lobby", []string{host.Guest, other.Guest})
	reply, err := s.Heartbeat(ctx, allocation.ID, allocation.Token, heartbeat)
	if err != nil || len(reply.Commands) != 1 || reply.Commands[0].Guest != other.Guest || reply.Commands[0].Kind != "leave" {
		t.Fatal("leave command", reply, err)
	}
	heartbeat.Acknowledged = []string{reply.Commands[0].ID}
	heartbeat.Guests = []string{host.Guest}
	reply, err = s.Heartbeat(ctx, allocation.ID, allocation.Token, heartbeat)
	if err != nil || len(reply.Commands) != 0 {
		t.Fatal("command ack", err)
	}
	// Private failures have the same fixed status/code whether unknown or started.
	heartbeat.State = "InRace"
	s.Heartbeat(ctx, allocation.ID, allocation.Token, heartbeat)
	_, err = s.JoinCode(ctx, other, private.Code, 3, s.config.Content)
	var api *APIError
	if !errors.As(err, &api) || api.Status != 404 || api.Code != "room_unavailable" {
		t.Fatal(err)
	}
	clock.Add(15)
	rooms, err = s.Rooms(ctx, 3, s.config.Content, true)
	if err != nil || len(rooms) != 0 {
		t.Fatal("stale worker advertised", rooms, err)
	}
	_, err = s.JoinRoom(ctx, other, public.Room, 3, s.config.Content)
	expectCode(t, err, "room_unavailable")
	if err = s.ReleaseWorker(ctx, allocation.ID); err != nil {
		t.Fatal("worker release", err)
	}
	if err = s.ReleaseWorker(ctx, allocation.ID); err != nil {
		t.Fatal("release not idempotent", err)
	}
}
func TestReadinessFailurePoolReuseAndCreateLimits(t *testing.T) {
	s, clock := testService(t)
	a := newAllocator(s)
	s.config.MaxWorkers = 1
	s.config.ReadyTimeout = 40 * time.Millisecond
	a.noReady = true
	guest := guestFor(t, s)
	ctx := context.Background()
	request := CreateRequest{Name: "Test Room", Region: s.config.Region, Rules: Rules{Laps: 2}, Protocol: 3, Content: s.config.Content}
	_, err := s.CreateRoom(ctx, guest, request)
	expectCode(t, err, "capacity")
	if a.stopped != 1 {
		t.Fatal("not stopped")
	}
	// The 40 ms budget belongs to the deliberate no-heartbeat case only.
	// Successful SQLite/crypto work must not race that tiny fixture deadline.
	s.config.ReadyTimeout = time.Second
	a.noReady = false
	created := createFor(t, s, guest, false)
	other := guestFor(t, s)
	_, err = s.CreateRoom(ctx, other, request)
	expectCode(t, err, "capacity")
	if err = s.ReleaseWorker(ctx, created.Worker); err != nil {
		t.Fatal(err)
	}
	created = createFor(t, s, guest, false)
	s.ReleaseWorker(ctx, created.Worker)
	_, err = s.CreateRoom(ctx, guest, request)
	expectCode(t, err, "rate_limited") // failed start counts as an allocation attempt.
	clock.Add(60)
	for index := 0; index < 7; index++ {
		created = createFor(t, s, guest, false)
		s.ReleaseWorker(ctx, created.Worker)
		clock.Add(21)
	}
	_, err = s.CreateRoom(ctx, guest, request)
	expectCode(t, err, "rate_limited")
	clock.Add(3600)
	createFor(t, s, guest, false)
}
func TestCodeBruteforceQuotaIncludesUnknownAndInvalid(t *testing.T) {
	s, clock := testService(t)
	guest := guestFor(t, s)
	for index := 0; index < 20; index++ {
		_, err := s.JoinCode(context.Background(), guest, "invalid", 3, s.config.Content)
		expectCode(t, err, "room_unavailable")
	}
	_, err := s.JoinCode(context.Background(), guest, "23456789", 3, s.config.Content)
	expectCode(t, err, "rate_limited")
	clock.Add(60)
	_, err = s.JoinCode(context.Background(), guest, "23456789", 3, s.config.Content)
	expectCode(t, err, "room_unavailable")
}
func TestMigrationAndFutureSchemaPreservation(t *testing.T) {
	filename := filepath.Join(t.TempDir(), "old.sqlite")
	db, err := sql.Open("sqlite", filename)
	if err != nil {
		t.Fatal(err)
	}
	// Exact schema 1 reservation layout, then migration must preserve auth data.
	oldBytes, err := os.ReadFile("testdata/schema1.sql")
	if err != nil {
		t.Fatal(err)
	}
	old := string(oldBytes)
	if _, err = db.Exec(old + "PRAGMA user_version=1;"); err != nil {
		t.Fatal(err)
	}
	db.Exec(`INSERT INTO guests(id,name,secret,created) VALUES('kept','Driver',x'01',1)`)
	db.Close()
	store, err := OpenStore(filename)
	if err != nil {
		t.Fatal(err)
	}
	var count, version int
	store.db.QueryRow(`SELECT count(*) FROM guests WHERE id='kept'`).Scan(&count)
	store.db.QueryRow(`PRAGMA user_version`).Scan(&version)
	if count != 1 || version != DatabaseSchemaVersion {
		t.Fatal("migration lost data/version")
	}
	store.db.Exec(`PRAGMA user_version=999`)
	store.Close()
	_, err = OpenStore(filename)
	if !errors.Is(err, errFutureDatabase) {
		t.Fatal("future schema overwritten", err)
	}
	db, _ = sql.Open("sqlite", filename)
	defer db.Close()
	db.QueryRow(`SELECT count(*) FROM guests WHERE id='kept'`).Scan(&count)
	if count != 1 {
		t.Fatal("future data lost")
	}
}
func TestRulesRejectMissingUnknownOrWrongTypes(t *testing.T) {
	for _, value := range []string{`{}`, `{"track":0,"laps":2,"bot_fill":true,"difficulty":1,"contact":true,"path":"evil"}`, `{"track":0,"laps":2,"bot_fill":1,"difficulty":1,"contact":true}`, `{"track":10,"laps":2,"bot_fill":true,"difficulty":1,"contact":true}`} {
		var rules Rules
		if json.Unmarshal([]byte(value), &rules) == nil {
			t.Fatal("invalid rules accepted", value)
		}
	}
}

func TestOperatorBanRevokesAdmissionAndQueuesLiveRemoval(t *testing.T) {
	s, _ := testService(t)
	a := newAllocator(s)
	ctx := context.Background()
	guest := guestFor(t, s)
	joined := createFor(t, s, guest, false)
	allocation := a.get(joined.Worker)
	claims := claimsFor(t, s, joined)
	if err := s.store.Ban(guest.Guest, true); err != nil {
		t.Fatal(err)
	}
	_, err := s.Authorize(ctx, guest.Token)
	expectCode(t, err, "unauthorized")
	expectCode(t, s.Consume(ctx, allocation.ID, allocation.Token, guest.Guest, claims.Nonce), "admission_expired")
	reply, err := s.Heartbeat(ctx, allocation.ID, allocation.Token, heartbeatFor(allocation, "Lobby", []string{guest.Guest}))
	if err != nil || len(reply.Commands) != 1 || reply.Commands[0].Guest != guest.Guest {
		t.Fatal("live ban removal missing", reply, err)
	}
	if err = s.store.Ban(guest.Guest, false); err != nil {
		t.Fatal(err)
	}
	if _, err = s.Authorize(ctx, guest.Token); err != nil {
		t.Fatal("unban did not restore authorization", err)
	}
}

func TestRejoinWaitsForLeaveAcknowledgement(t *testing.T) {
	s, _ := testService(t)
	a := newAllocator(s)
	host, guest := guestFor(t, s), guestFor(t, s)
	created := createFor(t, s, host, false)
	allocation := a.get(created.Worker)
	ctx := context.Background()
	joined, err := s.JoinRoom(ctx, guest, created.Room, 3, s.config.Content)
	if err != nil {
		t.Fatal(err)
	}
	old := claimsFor(t, s, joined)
	if err = s.Consume(ctx, allocation.ID, allocation.Token, guest.Guest, old.Nonce); err != nil {
		t.Fatal(err)
	}
	if err = s.LeaveRoom(ctx, guest, created.Room); err != nil {
		t.Fatal(err)
	}
	heartbeat := heartbeatFor(allocation, "Lobby", []string{host.Guest, guest.Guest})
	reply, err := s.Heartbeat(ctx, allocation.ID, allocation.Token, heartbeat)
	if err != nil || len(reply.Commands) != 1 {
		t.Fatal("leave delivery", err)
	}
	_, err = s.JoinRoom(ctx, guest, created.Room, 3, s.config.Content)
	expectCode(t, err, "room_unavailable")
	heartbeat.Guests = []string{host.Guest}
	heartbeat.Acknowledged = []string{reply.Commands[0].ID}
	if _, err = s.Heartbeat(ctx, allocation.ID, allocation.Token, heartbeat); err != nil {
		t.Fatal(err)
	}
	joined, err = s.JoinRoom(ctx, guest, created.Room, 3, s.config.Content)
	if err != nil {
		t.Fatal("acknowledged rejoin", err)
	}
	fresh := claimsFor(t, s, joined)
	if fresh.Nonce == old.Nonce {
		t.Fatal("ticket nonce reused")
	}
	expectCode(t, s.Consume(ctx, allocation.ID, allocation.Token, guest.Guest, old.Nonce), "admission_expired")
	if err = s.Consume(ctx, allocation.ID, allocation.Token, guest.Guest, fresh.Nonce); err != nil {
		t.Fatal("fresh consume", err)
	}
}

func TestBonusTrackRuleBounds(t *testing.T) {
	for _, track := range []int{0, 5, 6, 7, 8, 9} {
		if !(Rules{Track: track, Laps: 2, BotFill: true, Difficulty: 1, Contact: true}).valid() {
			t.Fatalf("valid track %d rejected", track)
		}
	}
	for _, track := range []int{-1, 10, 99} {
		if (Rules{Track: track, Laps: 2, Difficulty: 1}).valid() {
			t.Fatalf("invalid track %d accepted", track)
		}
	}
}
