package directory

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"strconv"
)

const workerDrainSeconds int64 = 600
const workerResultDeliverySeconds int64 = 5

// DrainWorkers is a host/operator operation, never a public HTTP endpoint.
// Only this explicit ownership list is changed during supervisor shutdown.
func (s *Store) DrainWorkers(ctx context.Context, ids []string, now int64) (int64, error) {
	for _, id := range ids {
		if !validUUID(id) {
			return 0, errors.New("invalid worker ID")
		}
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()
	var count int64
	for _, id := range ids {
		result, err := tx.ExecContext(ctx, `UPDATE workers SET drain_deadline=CASE WHEN drain_deadline=0 THEN ? ELSE min(drain_deadline,?) END,ready=0 WHERE id=?`, now+workerDrainSeconds, now+workerDrainSeconds, id)
		if err != nil {
			return 0, err
		}
		n, _ := result.RowsAffected()
		count += n
		if _, err = tx.ExecContext(ctx, `UPDATE rooms SET closed=1 WHERE worker=?`, id); err != nil {
			return 0, err
		}
	}
	return count, tx.Commit()
}

func (s *Store) WorkerIDs(ctx context.Context, ownerPrivate string, all bool) ([]string, error) {
	query := `SELECT id FROM workers WHERE owner_private=? OR owner_private=''`
	args := []any{ownerPrivate}
	if all {
		query = `SELECT id FROM workers`
		args = nil
	}
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err = rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (s *Service) BeginDrain(ctx context.Context, ids []string) error {
	s.draining.Store(true)
	_, err := s.store.DrainWorkers(ctx, ids, s.config.Now().Unix())
	return err
}

// Call only after exclusively binding this private listener. Surviving workers
// authenticate with their existing credential and receive Drain on heartbeat.
func (s *Service) RecoverWorkers(ctx context.Context) error {
	if s.config.WorkerPrivateURL == "" {
		return errors.New("private worker URL required for recovery")
	}
	ids, err := s.store.WorkerIDs(ctx, s.config.WorkerPrivateURL, false)
	if err != nil {
		return err
	}
	_, err = s.store.DrainWorkers(ctx, ids, s.config.Now().Unix())
	return err
}

type WorkerOwner interface {
	Owns(string) bool
	Stop(string) error
}
type workerObservation struct {
	id, state                    string
	port                         int
	heartbeat, created, deadline int64
}

// Only an allocator's own child can be signaled. Unknown survivors keep their
// port reservation until exclusive IPv4/IPv6 bind probes show the port free.
func (s *Service) ReconcileWorkers(ctx context.Context, owner WorkerOwner) error {
	rows, err := s.store.db.QueryContext(ctx, `SELECT w.id,w.state,w.port,w.heartbeat,r.created,w.drain_deadline FROM workers w JOIN rooms r ON r.worker=w.id`)
	if err != nil {
		return err
	}
	var workers []workerObservation
	for rows.Next() {
		var w workerObservation
		if err = rows.Scan(&w.id, &w.state, &w.port, &w.heartbeat, &w.created, &w.deadline); err != nil {
			rows.Close()
			return err
		}
		workers = append(workers, w)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	now := s.config.Now().Unix()
	for _, worker := range workers {
		if err = ctx.Err(); err != nil {
			return err
		}
		stale := now-max(worker.heartbeat, worker.created) >= 15
		if !stale && worker.deadline == 0 && worker.state != "Closed" {
			continue
		}
		owned := owner != nil && owner.Owns(worker.id)
		if worker.deadline > 0 && now >= worker.deadline+workerResultDeliverySeconds && owned {
			if err = owner.Stop(worker.id); err != nil {
				return err
			}
			owned = false
		}
		if udpPortFree(worker.port) {
			if owned {
				if err = owner.Stop(worker.id); err != nil {
					return err
				}
			}
			if err = s.ReleaseWorker(ctx, worker.id); err != nil {
				return err
			}
		} else if worker.deadline == 0 {
			if _, err = s.store.DrainWorkers(ctx, []string{worker.id}, now); err != nil {
				return err
			}
		} else if now >= worker.deadline+workerResultDeliverySeconds && !owned {
			s.reportUnownedBusy(worker.id, now)
		}
	}
	return nil
}

func (s *Service) reportUnownedBusy(id string, now int64) {
	s.lifecycleMu.Lock()
	previous, known := s.unownedAlerts[id]
	if known && now-previous < 60 {
		s.lifecycleMu.Unlock()
		return
	}
	if !known && len(s.unownedAlerts) >= 128 {
		oldest := ""
		var oldestAt int64
		for key, at := range s.unownedAlerts {
			if oldest == "" || at < oldestAt {
				oldest, oldestAt = key, at
			}
		}
		delete(s.unownedAlerts, oldest)
	}
	s.unownedAlerts[id] = now
	s.lifecycleMu.Unlock()
	if s.config.PerformanceEvents != nil {
		s.performanceLogMu.Lock()
		defer s.performanceLogMu.Unlock()
		_ = json.NewEncoder(s.config.PerformanceEvents).Encode(map[string]any{"code": "worker_unowned_port_busy", "worker": id, "at_unix": now})
	}
}

func udpPortFree(port int) bool {
	address := ":" + strconv.Itoa(port)
	v4, err := net.ListenPacket("udp4", "0.0.0.0"+address)
	if err != nil {
		return false
	}
	defer v4.Close()
	v6, err := net.ListenPacket("udp6", "[::]"+address)
	if err == nil {
		v6.Close()
		return true
	}
	// A host with IPv6 disabled cannot have a live IPv6 worker listener.
	probe, probeErr := net.ListenPacket("udp6", "[::]:0")
	if probeErr != nil {
		return true
	}
	probe.Close()
	return false
}
