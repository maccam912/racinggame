package directory

import (
	"context"
	"database/sql"
	"net/http"
)

// DeletionRequest is a durable operator work item, not a claim of erasure.
// Public responses omit Guest; only the filesystem-authorized CLI exposes it.
type DeletionRequest struct {
	ID      string `json:"request_id"`
	Guest   string `json:"guest_id,omitempty"`
	Created int64  `json:"created_at"`
}

func (s *Service) RequestDeletion(ctx context.Context, session Session) (DeletionRequest, error) {
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return DeletionRequest{}, err
	}
	defer tx.Rollback()
	var banned int
	if err = tx.QueryRowContext(ctx, `SELECT banned FROM guests WHERE id=?`, session.Guest).Scan(&banned); err == sql.ErrNoRows || banned != 0 {
		return DeletionRequest{}, apiError(401, "unauthorized")
	} else if err != nil {
		return DeletionRequest{}, err
	}
	result := DeletionRequest{}
	err = tx.QueryRowContext(ctx, `SELECT id,created FROM deletion_requests WHERE guest=?`, session.Guest).Scan(&result.ID, &result.Created)
	if err == sql.ErrNoRows {
		result.ID, result.Created = UUID(), s.config.Now().Unix()
		_, err = tx.ExecContext(ctx, `INSERT INTO deletion_requests(id,guest,created) VALUES(?,?,?)`, result.ID, session.Guest, result.Created)
	}
	if err != nil {
		return DeletionRequest{}, err
	}
	return result, tx.Commit()
}

// DeletionRequests is filesystem-only. Cursor pagination preserves receipt
// order without returning names, secrets, sessions, IP subjects or room codes.
func (s *Store) DeletionRequests(ctx context.Context, after string, limit int) ([]DeletionRequest, error) {
	if limit < 1 || limit > 1000 || (after != "" && !validUUID(after)) {
		return nil, apiError(400, "invalid_query")
	}
	var created int64 = -1
	if after != "" {
		if err := s.db.QueryRowContext(ctx, `SELECT created FROM deletion_requests WHERE id=?`, after).Scan(&created); err == sql.ErrNoRows {
			return nil, apiError(404, "request_unavailable")
		} else if err != nil {
			return nil, err
		}
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id,guest,created FROM deletion_requests WHERE created>? OR (created=? AND id>?) ORDER BY created,id LIMIT ?`, created, created, after, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := []DeletionRequest{}
	for rows.Next() {
		var row DeletionRequest
		if err = rows.Scan(&row.ID, &row.Guest, &row.Created); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	return result, rows.Err()
}

func (s *Service) deletionHTTP(w http.ResponseWriter, r *http.Request) {
	session, ok := s.sessionFor(w, r)
	if !ok {
		return
	}
	var body *struct{}
	if err := decodeJSON(w, r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body == nil {
		writeError(w, apiError(400, "invalid_json"))
		return
	}
	request, err := s.RequestDeletion(r.Context(), session)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]any{"request_id": request.ID, "created_at": request.Created, "status": "pending_operator"})
}
