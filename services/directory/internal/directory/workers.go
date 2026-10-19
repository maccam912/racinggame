package directory

import (
	"context"
	"database/sql"
	"encoding/json"

	"github.com/maccam912/racinggame/services/directory/internal/names"
)

type HeartbeatRequest struct {
	State        string             `json:"state"`
	Ready        bool               `json:"ready"`
	Guests       []string           `json:"guests"`
	Rules        Rules              `json:"rules"`
	Name         string             `json:"name"`
	Private      bool               `json:"private"`
	Acknowledged []string           `json:"acknowledged"`
	Performance  *WorkerPerformance `json:"performance,omitempty"`
}
type WorkerCommand struct {
	ID    string `json:"id"`
	Kind  string `json:"kind"`
	Guest string `json:"guest_id"`
}
type HeartbeatReply struct {
	Commands []WorkerCommand `json:"commands"`
	Drain    bool            `json:"drain"`
}

func workerAuthorized(ctx context.Context, tx *sql.Tx, id, token string) error {
	if !validUUID(id) || len(token) != 43 {
		return apiError(401, "unauthorized")
	}
	var expected []byte
	err := tx.QueryRowContext(ctx, `SELECT token_hash FROM workers WHERE id=?`, id).Scan(&expected)
	if err == sql.ErrNoRows {
		return apiError(401, "unauthorized")
	}
	if err != nil {
		return err
	}
	if !equalString(string(expected), string(digest(token))) {
		return apiError(401, "unauthorized")
	}
	return nil
}
func (s *Service) Heartbeat(ctx context.Context, id, token string, request HeartbeatRequest) (HeartbeatReply, error) {
	validState := false
	for _, state := range []string{"Lobby", "Loading", "InRace", "Results", "Closed"} {
		if state == request.State {
			validState = true
		}
	}
	name, err := names.Validate(request.Name, 24)
	if err != nil || !validState || !request.Rules.valid() || len(request.Guests) > 8 || len(request.Acknowledged) > 16 || (request.Performance != nil && !request.Performance.valid()) {
		return HeartbeatReply{}, apiError(400, "invalid_heartbeat")
	}
	seen := map[string]bool{}
	for _, guest := range request.Guests {
		if !validUUID(guest) || seen[guest] {
			return HeartbeatReply{}, apiError(400, "invalid_heartbeat")
		}
		seen[guest] = true
	}
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return HeartbeatReply{}, err
	}
	defer tx.Rollback()
	if err = workerAuthorized(ctx, tx, id, token); err != nil {
		return HeartbeatReply{}, err
	}
	var drainDeadline int64
	if err = tx.QueryRowContext(ctx, `SELECT drain_deadline FROM workers WHERE id=?`, id).Scan(&drainDeadline); err != nil {
		return HeartbeatReply{}, err
	}
	guests, _ := json.Marshal(request.Guests)
	rules, _ := json.Marshal(request.Rules)
	performance, _ := json.Marshal(request.Performance)
	now := s.config.Now().Unix()
	if _, err = tx.ExecContext(ctx, `UPDATE workers SET heartbeat=?,ready=?,state=?,guests=?,performance=? WHERE id=?`, now, request.Ready && drainDeadline == 0, request.State, string(guests), string(performance), id); err != nil {
		return HeartbeatReply{}, err
	}
	if _, err = tx.ExecContext(ctx, `UPDATE rooms SET name=?,private=?,rules=?,closed=? WHERE worker=?`, name, request.Private, string(rules), request.State == "Closed" || drainDeadline != 0, id); err != nil {
		return HeartbeatReply{}, err
	}
	for _, command := range request.Acknowledged {
		if _, err = tx.ExecContext(ctx, `DELETE FROM worker_commands WHERE worker=? AND id=?`, id, command); err != nil {
			return HeartbeatReply{}, err
		}
	}
	rows, err := tx.QueryContext(ctx, `SELECT id,kind,guest FROM worker_commands WHERE worker=? ORDER BY created,id LIMIT 16`, id)
	if err != nil {
		return HeartbeatReply{}, err
	}
	reply := HeartbeatReply{Commands: []WorkerCommand{}, Drain: drainDeadline != 0}
	for rows.Next() {
		var command WorkerCommand
		if err = rows.Scan(&command.ID, &command.Kind, &command.Guest); err != nil {
			rows.Close()
			return reply, err
		}
		reply.Commands = append(reply.Commands, command)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return reply, err
	}
	if err = tx.Commit(); err != nil {
		return reply, err
	}
	s.observePerformance(id, request.Performance)
	return reply, nil
}
func (s *Service) Consume(ctx context.Context, worker, token, guest, nonce string) error {
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err = workerAuthorized(ctx, tx, worker, token); err != nil {
		return err
	}
	var expires int64
	var consumed bool
	var roomID string
	err = tx.QueryRowContext(ctx, `SELECT a.ticket_expires,a.consumed,r.id FROM reservations a JOIN rooms r ON r.id=a.room JOIN guests g ON g.id=a.guest WHERE r.worker=? AND a.guest=? AND a.nonce=? AND r.closed=0 AND g.banned=0`, worker, guest, nonce).Scan(&expires, &consumed, &roomID)
	now := s.config.Now().Unix()
	if err == sql.ErrNoRows {
		return apiError(409, "admission_expired")
	}
	if err != nil {
		return err
	}
	if expires <= now {
		return apiError(409, "admission_expired")
	}
	if consumed {
		return tx.Commit()
	}
	room, err := roomInTx(ctx, tx, roomID)
	if err != nil {
		return err
	}
	set, err := occupants(ctx, tx, room, now)
	if err != nil {
		return err
	}
	// A 60-second ticket does not promise a seat after the 15-second hold.
	// Recheck inside this transaction before reacquiring an expired hold.
	if room.State != "Lobby" || !room.ready || room.heartbeat <= now-15 || len(set) >= 8 && !set[guest] {
		return apiError(409, "room_unavailable")
	}
	// HTTP retries are idempotent. The worker's nonce set rejects a second spawn.
	if _, err = tx.ExecContext(ctx, `UPDATE reservations SET consumed=1,expires=? WHERE room=? AND guest=? AND nonce=?`, now+15, roomID, guest, nonce); err != nil {
		return err
	}
	return tx.Commit()
}
func (s *Service) LeaveRoom(ctx context.Context, session Session, room string) error {
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var worker string
	err = tx.QueryRowContext(ctx, `SELECT worker FROM rooms WHERE id=?`, room).Scan(&worker)
	if err == sql.ErrNoRows {
		return nil
	}
	if err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM reservations WHERE room=? AND guest=?`, room, session.Guest); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `INSERT OR IGNORE INTO worker_commands(id,worker,kind,guest,created) VALUES(?,?,'leave',?,?)`, UUID(), worker, session.Guest, s.config.Now().Unix()); err != nil {
		return err
	}
	return tx.Commit()
}
