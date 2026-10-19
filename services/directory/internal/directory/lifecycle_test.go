package directory

import (
	"bytes"
	"context"
	"database/sql"
	"net"
	"os"
	"path/filepath"
	"testing"
)

func TestPerformanceAndHostCapAreSharedAcrossSupervisors(t *testing.T) {
	s, _ := testService(t)
	a := newAllocator(s)
	s.config.RequirePerformance = true
	first := createFor(t, s, guestFor(t, s), false)
	allocation := a.get(first.Worker)
	request := heartbeatFor(allocation, "Lobby", nil)
	p := healthyPerformance()
	request.Performance = &p
	if _, err := s.Heartbeat(context.Background(), first.Worker, allocation.Token, request); err != nil {
		t.Fatal(err)
	}
	config := s.config
	config.FirstPort += 10
	config.HostMaxWorkers = 1
	replacement, err := New(s.store, config)
	if err != nil {
		t.Fatal(err)
	}
	if len(replacement.performance) != 0 || !capacityFor(t, replacement) {
		t.Fatal("fresh authenticated SQLite measurements did not survive supervisor replacement")
	}
	guest := guestFor(t, replacement)
	_, err = replacement.CreateRoom(context.Background(), guest, CreateRequest{Name: "New Pool", Region: config.Region, Rules: allocation.Rules, Protocol: config.Protocol, Content: config.Content})
	expectCode(t, err, "capacity")
}

func TestDrainCannotReopenOrExtendAndRecoveryRespectsPrivateOwner(t *testing.T) {
	s, clock := testService(t)
	a := newAllocator(s)
	s.config.WorkerPrivateURL = "http://127.0.0.1:8081"
	first := createFor(t, s, guestFor(t, s), false)
	s.config.WorkerPrivateURL = "http://127.0.0.1:8083"
	second := createFor(t, s, guestFor(t, s), false)
	if err := s.RecoverWorkers(context.Background()); err != nil {
		t.Fatal(err)
	}
	var firstDeadline, secondDeadline int64
	s.store.db.QueryRow(`SELECT drain_deadline FROM workers WHERE id=?`, first.Worker).Scan(&firstDeadline)
	s.store.db.QueryRow(`SELECT drain_deadline FROM workers WHERE id=?`, second.Worker).Scan(&secondDeadline)
	if firstDeadline != 0 || secondDeadline != clock.Load()+600 {
		t.Fatal("recovery drained another private supervisor")
	}
	allocation := a.get(second.Worker)
	clock.Add(60)
	if _, err := s.store.DrainWorkers(context.Background(), []string{second.Worker}, clock.Load()); err != nil {
		t.Fatal(err)
	}
	reply, err := s.Heartbeat(context.Background(), second.Worker, allocation.Token, heartbeatFor(allocation, "Lobby", nil))
	if err != nil || !reply.Drain {
		t.Fatal("authenticated worker was not instructed to drain", err)
	}
	var ready bool
	var closed bool
	var actualDeadline int64
	s.store.db.QueryRow(`SELECT ready,drain_deadline FROM workers WHERE id=?`, second.Worker).Scan(&ready, &actualDeadline)
	s.store.db.QueryRow(`SELECT closed FROM rooms WHERE worker=?`, second.Worker).Scan(&closed)
	if ready || !closed || actualDeadline != secondDeadline {
		t.Fatal("heartbeat reopened or extended draining room")
	}
	if _, err = s.store.DrainWorkers(context.Background(), []string{"invalid"}, clock.Load()); err == nil {
		t.Fatal("invalid operator selector")
	}
	if err = s.BeginDrain(context.Background(), []string{first.Worker}); err != nil {
		t.Fatal(err)
	}
	_, err = s.CreateRoom(context.Background(), guestFor(t, s), CreateRequest{})
	expectCode(t, err, "capacity")
}

type testWorkerOwner struct {
	ids     map[string]bool
	stopped []string
	close   func()
}

func (o *testWorkerOwner) Owns(id string) bool { return o.ids[id] }
func (o *testWorkerOwner) Stop(id string) error {
	o.stopped = append(o.stopped, id)
	if o.close != nil {
		o.close()
		o.close = nil
	}
	return nil
}

func TestReconcileKeepsUnknownBusyPortsAndReapsOnlyKnownChildren(t *testing.T) {
	s, clock := testService(t)
	socket, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer socket.Close()
	port := socket.LocalAddr().(*net.UDPAddr).Port
	s.config.FirstPort = port
	s.config.MaxWorkers = 1
	newAllocator(s)
	created := createFor(t, s, guestFor(t, s), false)
	if udpPortFree(port) {
		t.Fatal("active IPv4 socket reported free")
	}
	if _, err = s.store.DrainWorkers(context.Background(), []string{created.Worker}, clock.Load()); err != nil {
		t.Fatal(err)
	}
	clock.Add(606)
	unknown := &testWorkerOwner{ids: map[string]bool{}}
	if err = s.ReconcileWorkers(context.Background(), unknown); err != nil {
		t.Fatal(err)
	}
	var rows int
	s.store.db.QueryRow(`SELECT count(*) FROM workers`).Scan(&rows)
	if rows != 1 || len(unknown.stopped) != 0 {
		t.Fatal("unknown busy process was signaled or its port reused")
	}
	owned := &testWorkerOwner{ids: map[string]bool{created.Worker: true}, close: func() { socket.Close() }}
	if err = s.ReconcileWorkers(context.Background(), owned); err != nil {
		t.Fatal(err)
	}
	s.store.db.QueryRow(`SELECT count(*) FROM workers`).Scan(&rows)
	if rows != 0 || len(owned.stopped) < 1 {
		t.Fatal("known overdue child not reaped")
	}
}

func TestFreshStartupReservationSurvivesFreePortProbe(t *testing.T) {
	s, clock := testService(t)
	probe, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	s.config.FirstPort = probe.LocalAddr().(*net.UDPAddr).Port
	probe.Close()
	newAllocator(s)
	created := createFor(t, s, guestFor(t, s), false)
	if err := s.ReconcileWorkers(context.Background(), nil); err != nil {
		t.Fatal(err)
	}
	var rows int
	s.store.db.QueryRow(`SELECT count(*) FROM workers`).Scan(&rows)
	if rows != 1 {
		t.Fatal("fresh not-yet-bound worker was reclaimed")
	}
	clock.Add(15)
	if err := s.ReconcileWorkers(context.Background(), nil); err != nil {
		t.Fatal(err)
	}
	s.store.db.QueryRow(`SELECT count(*) FROM workers WHERE id=?`, created.Worker).Scan(&rows)
	if rows != 0 {
		t.Fatal("stale free port was not reclaimed")
	}
}

func TestIPv6WorkerPortCannotBeReclaimed(t *testing.T) {
	socket, err := net.ListenPacket("udp6", "[::1]:0")
	if err != nil {
		t.Skip("IPv6 unavailable")
	}
	defer socket.Close()
	if udpPortFree(socket.LocalAddr().(*net.UDPAddr).Port) {
		t.Fatal("active IPv6 socket reported free")
	}
}

func TestSchemaTwoUpgradePreservesEncryptedGuestAndBearer(t *testing.T) {
	template, _ := testService(t)
	path := filepath.Join(t.TempDir(), "legacy.sqlite")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	db.SetMaxOpenConns(1)
	schema2, err := os.ReadFile("testdata/schema2.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec(string(schema2) + "PRAGMA user_version=2;"); err != nil {
		t.Fatal(err)
	}
	oldStore := &Store{db: db}
	legacy, err := New(oldStore, template.config)
	if err != nil {
		t.Fatal(err)
	}
	guest := guestFor(t, legacy)
	var before []byte
	db.QueryRow(`SELECT secret FROM guests WHERE id=?`, guest.Guest).Scan(&before)
	oldStore.Close()
	upgraded, err := OpenStore(path)
	if err != nil {
		t.Fatal(err)
	}
	defer upgraded.Close()
	service, err := New(upgraded, template.config)
	if err != nil {
		t.Fatal(err)
	}
	var after []byte
	var version int
	upgraded.db.QueryRow(`SELECT secret FROM guests WHERE id=?`, guest.Guest).Scan(&after)
	upgraded.db.QueryRow(`PRAGMA user_version`).Scan(&version)
	if !bytes.Equal(before, after) || version != 3 {
		t.Fatal("encrypted identity bytes changed")
	}
	session, err := service.Authorize(context.Background(), guest.Token)
	if err != nil || session.Guest != guest.Guest {
		t.Fatal("existing authenticated session lost", err)
	}
}
