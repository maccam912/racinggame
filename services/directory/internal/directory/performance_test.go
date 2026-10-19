package directory

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"
)

func healthyPerformance() WorkerPerformance {
	return WorkerPerformance{Version: 1, Samples: 1800, WindowUS: 30_000_000, FullWindow: true, P95US: 4000, P99US: 7000, MaxUS: 18000, DeadlineMisses: 18, RSSBytes: 100_000_000, Cars: 8}
}
func capacityFor(t *testing.T, s *Service) bool {
	t.Helper()
	tx, err := s.store.db.BeginTx(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback()
	allowed, err := s.capacityAvailable(context.Background(), tx)
	if err != nil {
		t.Fatal(err)
	}
	return allowed
}
func TestPerformanceAdmissionIsFreshAuthenticatedAndConservative(t *testing.T) {
	s, clock := testService(t)
	a := newAllocator(s)
	s.config.RequirePerformance = true
	first := createFor(t, s, guestFor(t, s), false)
	allocation := a.get(first.Worker)
	if capacityFor(t, s) {
		t.Fatal("missing metrics must block another allocation")
	}
	p := healthyPerformance()
	hb := heartbeatFor(allocation, "Lobby", nil)
	hb.Performance = &p
	if _, err := s.Heartbeat(context.Background(), first.Worker, randomToken(), hb); err == nil {
		t.Fatal("unauthorized heartbeat")
	}
	if capacityFor(t, s) {
		t.Fatal("unauthorized measurements changed admission")
	}
	if _, err := s.Heartbeat(context.Background(), first.Worker, allocation.Token, hb); err != nil {
		t.Fatal(err)
	}
	if !capacityFor(t, s) {
		t.Fatal("healthy worker should reserve enough headroom")
	}
	for _, scenario := range []struct {
		name   string
		change func(*WorkerPerformance)
	}{
		{"p95_at_8ms", func(p *WorkerPerformance) { p.P95US = 8000; p.P99US = 9000 }},
		{"deadline_alert", func(p *WorkerPerformance) { p.DeadlineMisses = 90 }},
		{"no_rss", func(p *WorkerPerformance) { p.RSSBytes = 0 }},
		{"256MB", func(p *WorkerPerformance) { p.RSSBytes = 256_000_000 }},
		{"startup", func(p *WorkerPerformance) { p.Samples = 59; p.DeadlineMisses = 0 }},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			p = healthyPerformance()
			scenario.change(&p)
			if _, err := s.Heartbeat(context.Background(), first.Worker, allocation.Token, hb); err != nil {
				t.Fatal(err)
			}
			if capacityFor(t, s) {
				t.Fatal("headroom gate bypassed")
			}
			guest := guestFor(t, s)
			_, err := s.CreateRoom(context.Background(), guest, CreateRequest{Name: "Capacity Probe", Region: s.config.Region, Rules: allocation.Rules, Protocol: s.config.Protocol, Content: s.config.Content})
			if api, ok := err.(*APIError); !ok || api.Code != "capacity" {
				t.Fatal("creation did not return capacity", err)
			}
			var count int
			s.store.db.QueryRow(`SELECT count(*) FROM workers`).Scan(&count)
			if count != 1 {
				t.Fatal("refusal leaked worker/port")
			}
			if _, err := s.JoinRoom(context.Background(), guest, first.Room, s.config.Protocol, s.config.Content); err != nil {
				t.Fatal("capacity refusal must preserve existing-room joins", err)
			}
		})
	}
	p = healthyPerformance()
	if _, err := s.Heartbeat(context.Background(), first.Worker, allocation.Token, hb); err != nil {
		t.Fatal(err)
	}
	clock.Add(15)
	if capacityFor(t, s) {
		t.Fatal("stale metrics admitted new work")
	}
	// Existing membership is independent of the create-only gate.
	if _, err := s.Heartbeat(context.Background(), first.Worker, allocation.Token, hb); err != nil {
		t.Fatal(err)
	}
	second := createFor(t, s, guestFor(t, s), false)
	if second.Worker == first.Worker {
		t.Fatal("worker identity reused")
	}
	if err := s.ReleaseWorker(context.Background(), second.Worker); err != nil {
		t.Fatal(err)
	}
	if !capacityFor(t, s) {
		t.Fatal("released worker retained a capacity block")
	}
	if err := s.ReleaseWorker(context.Background(), first.Worker); err != nil {
		t.Fatal(err)
	}
	s.performanceMu.Lock()
	remaining := len(s.performance)
	s.performanceMu.Unlock()
	if remaining != 0 {
		t.Fatal("released worker retained metrics")
	}
}
func TestPerformanceDeadlineAlertEdgesAndNoPersonalData(t *testing.T) {
	s, _ := testService(t)
	var log bytes.Buffer
	s.config.PerformanceEvents = &log
	id := UUID()
	p := healthyPerformance()
	p.DeadlineMisses = 90
	p.FullWindow = false
	p.WindowUS = 29_999_999
	s.observePerformance(id, &p)
	if strings.Contains(log.String(), "worker_tick_deadline_alert") {
		t.Fatal("early alert")
	}
	p.FullWindow = true
	p.WindowUS = 30_000_000
	s.observePerformance(id, &p)
	s.observePerformance(id, &p)
	if strings.Count(log.String(), "worker_tick_deadline_alert") != 1 {
		t.Fatal("threshold/repeated alert")
	}
	p.DeadlineMisses = 89
	s.observePerformance(id, &p)
	if strings.Count(log.String(), "worker_tick_deadline_recovered") != 1 {
		t.Fatal("recovery edge")
	}
	p.DeadlineMisses = 90
	s.observePerformance(id, &p)
	if strings.Count(log.String(), "worker_tick_deadline_alert") != 2 {
		t.Fatal("new overload edge")
	}
	for _, line := range strings.Split(strings.TrimSpace(log.String()), "\n") {
		var event map[string]any
		if json.Unmarshal([]byte(line), &event) != nil {
			t.Fatal("unstructured event")
		}
		for key := range event {
			if strings.Contains(key, "name") || strings.Contains(key, "token") || strings.Contains(key, "guest") {
				t.Fatal("personal field", key)
			}
		}
	}
	s.observePerformance(id, nil)
	if len(s.performance) != 0 {
		t.Fatal("legacy/missing heartbeat retained old healthy metrics")
	}
	for i := 0; i < 500; i++ {
		s.observePerformance(UUID(), &p)
	}
	if len(s.performance) != 128 {
		t.Fatal("unbounded cache", len(s.performance))
	}
}
func TestPerformanceSchemaRejectsInconsistentOrUnboundedValues(t *testing.T) {
	good := healthyPerformance()
	if !good.valid() {
		t.Fatal("healthy fixture")
	}
	for _, change := range []func(*WorkerPerformance){
		func(p *WorkerPerformance) { p.Version = 2 }, func(p *WorkerPerformance) { p.Samples = 3601 },
		func(p *WorkerPerformance) { p.WindowUS = 30_000_001 }, func(p *WorkerPerformance) { p.FullWindow = false },
		func(p *WorkerPerformance) { p.P95US = -1 }, func(p *WorkerPerformance) { p.P99US = 1 },
		func(p *WorkerPerformance) { p.MaxUS = 60_000_001 }, func(p *WorkerPerformance) { p.DeadlineMisses = 1801 },
		func(p *WorkerPerformance) { p.RSSBytes = -1 }, func(p *WorkerPerformance) { p.RSSBytes = 17 * 1024 * 1024 * 1024 },
		func(p *WorkerPerformance) { p.Cars = 9 }, func(p *WorkerPerformance) { p.Samples = 0; p.DeadlineMisses = 0 },
	} {
		p := good
		change(&p)
		if p.valid() {
			t.Fatal("invalid performance accepted", p)
		}
	}
}
