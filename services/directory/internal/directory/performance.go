package directory

import (
	"context"
	"database/sql"
	"encoding/json"
	"time"
)

// WorkerPerformance contains only bounded numeric process/tick measurements.
// Missing RSS is explicit zero. It is never replaced with engine heap or peak.
type WorkerPerformance struct {
	Version        int   `json:"version"`
	Samples        int   `json:"samples"`
	WindowUS       int64 `json:"window_us"`
	FullWindow     bool  `json:"full_window"`
	P95US          int64 `json:"p95_us"`
	P99US          int64 `json:"p99_us"`
	MaxUS          int64 `json:"max_us"`
	DeadlineMisses int   `json:"deadline_misses"`
	RSSBytes       int64 `json:"rss_bytes"`
	Cars           int   `json:"cars"`
}

func (p WorkerPerformance) valid() bool {
	return p.Version == 1 && p.Samples >= 0 && p.Samples <= 3600 &&
		p.WindowUS >= 0 && p.WindowUS <= 30_000_000 &&
		p.FullWindow == (p.WindowUS == 30_000_000) &&
		p.P95US >= 0 && p.P99US >= p.P95US && p.MaxUS >= p.P99US && p.MaxUS <= 60_000_000 &&
		p.DeadlineMisses >= 0 && p.DeadlineMisses <= p.Samples &&
		p.RSSBytes >= 0 && p.RSSBytes <= 16*1024*1024*1024 && p.Cars >= 0 && p.Cars <= 8 &&
		(p.Samples != 0 || (p.P95US == 0 && p.P99US == 0 && p.MaxUS == 0))
}

type workerHealth struct {
	performance WorkerPerformance
	received    time.Time
	alerted     bool
}

func (s *Service) observePerformance(id string, p *WorkerPerformance) {
	s.performanceMu.Lock()
	previous := s.performance[id]
	if p == nil {
		delete(s.performance, id)
		s.performanceMu.Unlock()
		return
	}
	// A complete 30-second observation is required before deadline alerts.
	overloaded := p.FullWindow && p.Samples >= 60 && p.DeadlineMisses*20 >= p.Samples
	now := s.config.Now()
	// A release racing an already committed heartbeat can leave one stale
	// observation. Bound the cache independently of database cleanup.
	if _, exists := s.performance[id]; !exists && len(s.performance) >= 128 {
		oldest := ""
		var oldestTime time.Time
		for key, value := range s.performance {
			if oldest == "" || value.received.Before(oldestTime) {
				oldest, oldestTime = key, value.received
			}
		}
		delete(s.performance, oldest)
	}
	s.performance[id] = workerHealth{performance: *p, received: now, alerted: overloaded}
	s.performanceMu.Unlock()
	if s.config.PerformanceEvents == nil {
		return
	}
	s.performanceLogMu.Lock()
	defer s.performanceLogMu.Unlock()
	encoder := json.NewEncoder(s.config.PerformanceEvents)
	_ = encoder.Encode(map[string]any{"at": now.UTC().Format(time.RFC3339), "code": "worker_performance", "worker": id, "performance": *p})
	if overloaded && !previous.alerted {
		_ = encoder.Encode(map[string]any{"at": now.UTC().Format(time.RFC3339), "code": "worker_tick_deadline_alert", "worker": id, "samples": p.Samples, "deadline_misses": p.DeadlineMisses, "p95_us": p.P95US, "p99_us": p.P99US})
	} else if !overloaded && previous.alerted {
		_ = encoder.Encode(map[string]any{"at": now.UTC().Format(time.RFC3339), "code": "worker_tick_deadline_recovered", "worker": id})
	}
}

func (s *Service) capacityAvailable(ctx context.Context, tx *sql.Tx) (bool, error) {
	rows, err := tx.QueryContext(ctx, `SELECT id FROM workers WHERE state != 'Closed'`)
	if err != nil {
		return false, err
	}
	defer rows.Close()
	s.performanceMu.Lock()
	defer s.performanceMu.Unlock()
	now := s.config.Now()
	for rows.Next() {
		var id string
		if err = rows.Scan(&id); err != nil {
			return false, err
		}
		health, ok := s.performance[id]
		// Keep 20% below the 10 ms refusal boundary. Existing rooms continue.
		// Startup, stale/missing metrics or missing native RSS fail closed for
		// additional room creation; the configured process cap still applies.
		if !ok || now.Sub(health.received) >= 15*time.Second || now.Before(health.received) ||
			health.performance.Samples < 60 || health.performance.P95US >= 8000 ||
			health.alerted ||
			health.performance.RSSBytes <= 0 || health.performance.RSSBytes >= 256_000_000 {
			return false, nil
		}
	}
	return true, rows.Err()
}
