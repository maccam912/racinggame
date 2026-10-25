package directory

import (
	"context"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/maccam912/racinggame/services/directory/internal/names"
)

type Rules struct {
	Track      int  `json:"track"`
	Laps       int  `json:"laps"`
	BotFill    bool `json:"bot_fill"`
	Difficulty int  `json:"difficulty"`
	Contact    bool `json:"contact"`
}

func (r Rules) valid() bool {
	return r.Track >= 0 && r.Track < 10 && r.Laps >= 1 && r.Laps <= 3 && r.Difficulty >= 0 && r.Difficulty < 4
}
func (r *Rules) UnmarshalJSON(data []byte) error {
	var value struct {
		Track      *int  `json:"track"`
		Laps       *int  `json:"laps"`
		BotFill    *bool `json:"bot_fill"`
		Difficulty *int  `json:"difficulty"`
		Contact    *bool `json:"contact"`
	}
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&value) != nil || value.Track == nil || value.Laps == nil || value.BotFill == nil || value.Difficulty == nil || value.Contact == nil {
		return errors.New("invalid_rules")
	}
	*r = Rules{Track: *value.Track, Laps: *value.Laps, BotFill: *value.BotFill, Difficulty: *value.Difficulty, Contact: *value.Contact}
	if !r.valid() {
		return errors.New("invalid_rules")
	}
	return nil
}

type Allocation struct {
	ID       string
	Room     string
	Port     int
	Token    string
	Name     string
	Private  bool
	Code     string
	Region   string
	Rules    Rules
	Protocol int
	Content  string
}
type Allocator interface {
	Start(context.Context, Allocation) error
	Stop(string) error
}
type CreateRequest struct {
	Name     string `json:"name"`
	Private  bool   `json:"private"`
	Region   string `json:"region"`
	Rules    Rules  `json:"rules"`
	Protocol int    `json:"protocol"`
	Content  string `json:"content_hash"`
}
type RoomInfo struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Region   string `json:"region"`
	Rules    Rules  `json:"rules"`
	Humans   int    `json:"humans"`
	Capacity int    `json:"capacity"`
	State    string `json:"state"`
	Created  int64  `json:"created_at"`
}
type JoinReply struct {
	Room     string `json:"room_id"`
	Worker   string `json:"worker_id"`
	Host     string `json:"host"`
	Port     int    `json:"port"`
	Ticket   string `json:"ticket"`
	Expires  int64  `json:"expires_at"`
	Protocol int    `json:"protocol"`
	Content  string `json:"content_hash"`
	Region   string `json:"region"`
	Code     string `json:"code,omitempty"`
}
type storedRoom struct {
	RoomInfo
	worker, code, content, guests string
	private, closed               bool
	port, protocol                int
	heartbeat                     int64
	ready                         bool
}

func checkWindows(ctx context.Context, tx *sql.Tx, subject, kind string, now int64, windows map[int64]int) error {
	for window, limit := range windows {
		var count int
		if err := tx.QueryRowContext(ctx, `SELECT count(*) FROM rate_events WHERE subject=? AND kind=? AND at>?`, subject, kind, now-window).Scan(&count); err != nil {
			return err
		}
		if count >= limit {
			return &APIError{Code: "rate_limited", Status: 429, Retry: int(window)}
		}
	}
	_, err := tx.ExecContext(ctx, `INSERT INTO rate_events(subject,kind,at) VALUES(?,?,?)`, subject, kind, now)
	return err
}
func roomCode() string {
	const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	bytes := randomBytes(8)
	for index := range bytes {
		bytes[index] = alphabet[int(bytes[index])&31]
	}
	return string(bytes)
}
func normalizeCode(code string) string {
	code = strings.ToUpper(strings.ReplaceAll(strings.TrimSpace(code), "-", ""))
	if len(code) != 8 {
		return ""
	}
	for _, value := range code {
		if !strings.ContainsRune("23456789ABCDEFGHJKLMNPQRSTUVWXYZ", value) {
			return ""
		}
	}
	return code
}
func (s *Service) compatible(protocol int, content string) bool {
	return protocol == s.config.Protocol && content == s.config.Content
}
func (s *Service) CreateRoom(ctx context.Context, session Session, request CreateRequest) (JoinReply, error) {
	if s.draining.Load() {
		return JoinReply{}, apiError(503, "capacity")
	}
	if !s.compatible(request.Protocol, request.Content) {
		return JoinReply{}, apiError(409, "incompatible")
	}
	if request.Region != s.config.Region {
		return JoinReply{}, apiError(503, "region_unavailable")
	}
	name, err := names.Validate(request.Name, 24)
	if err != nil || !request.Rules.valid() {
		return JoinReply{}, apiError(400, "invalid_room")
	}
	if s.config.Allocator == nil {
		return JoinReply{}, apiError(503, "capacity")
	}
	now := s.config.Now().Unix()
	allocation := Allocation{ID: UUID(), Room: UUID(), Token: randomToken(), Name: name, Private: request.Private, Code: roomCode(), Region: s.config.Region, Rules: request.Rules, Protocol: s.config.Protocol, Content: s.config.Content}
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return JoinReply{}, err
	}
	defer tx.Rollback()
	var workers int
	if err = tx.QueryRowContext(ctx, `SELECT count(*) FROM workers`).Scan(&workers); err != nil {
		return JoinReply{}, err
	}
	if workers >= s.config.HostMaxWorkers {
		return JoinReply{}, apiError(503, "capacity")
	}
	if s.config.RequirePerformance {
		allowed, capacityErr := s.capacityAvailable(ctx, tx)
		if capacityErr != nil {
			return JoinReply{}, capacityErr
		}
		if !allowed {
			return JoinReply{}, apiError(503, "capacity")
		}
	}
	if err = checkWindows(ctx, tx, session.Guest, "create", now, map[int64]int{60: 3, 3600: 10}); err != nil {
		return JoinReply{}, err
	}
	for port := s.config.FirstPort; port < s.config.FirstPort+s.config.MaxWorkers; port++ {
		var count int
		if err = tx.QueryRowContext(ctx, `SELECT count(*) FROM workers WHERE port=?`, port).Scan(&count); err != nil {
			return JoinReply{}, err
		}
		if count == 0 {
			allocation.Port = port
			break
		}
	}
	if allocation.Port == 0 {
		return JoinReply{}, apiError(503, "capacity")
	}
	rules, _ := json.Marshal(request.Rules)
	if _, err = tx.ExecContext(ctx, `INSERT INTO workers(id,room,token_hash,port,heartbeat,state,owner_private) VALUES(?,?,?,?,0,'Loading',?)`, allocation.ID, allocation.Room, digest(allocation.Token), allocation.Port, s.config.WorkerPrivateURL); err != nil {
		return JoinReply{}, err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO rooms(id,worker,name,private,code,created,creator,rules,protocol,content) VALUES(?,?,?,?,?,?,?,?,?,?)`, allocation.Room, allocation.ID, name, request.Private, allocation.Code, now, session.Guest, string(rules), s.config.Protocol, s.config.Content); err != nil {
		return JoinReply{}, err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO service_events VALUES(?,'create',?,?,'allocated')`, now, allocation.Room, session.Guest); err != nil {
		return JoinReply{}, err
	}
	if err = tx.Commit(); err != nil {
		return JoinReply{}, err
	}
	readyCtx, cancel := context.WithTimeout(ctx, s.config.ReadyTimeout)
	defer cancel()
	failed := func() (JoinReply, error) {
		if s.config.Allocator.Stop(allocation.ID) == nil {
			_ = s.ReleaseWorker(context.Background(), allocation.ID)
		}
		return JoinReply{}, apiError(503, "capacity")
	}
	if err = s.config.Allocator.Start(readyCtx, allocation); err != nil {
		return failed()
	}
	ticker := time.NewTicker(25 * time.Millisecond)
	defer ticker.Stop()
	for {
		var ready bool
		err = s.store.db.QueryRowContext(readyCtx, `SELECT ready FROM workers WHERE id=?`, allocation.ID).Scan(&ready)
		if err == nil && ready {
			break
		}
		select {
		case <-readyCtx.Done():
			return failed()
		case <-ticker.C:
		}
	}
	reply, err := s.joinRoom(ctx, session, allocation.Room, s.config.Protocol, s.config.Content, request.Private)
	if err != nil {
		return failed()
	}
	if request.Private {
		reply.Code = allocation.Code
	}
	return reply, nil
}
func (s *Service) ReleaseWorker(ctx context.Context, id string) error {
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, `DELETE FROM worker_commands WHERE worker=?;DELETE FROM reservations WHERE room IN (SELECT id FROM rooms WHERE worker=?);DELETE FROM rooms WHERE worker=?;DELETE FROM workers WHERE id=?;`, id, id, id, id); err != nil {
		return err
	}
	if err = tx.Commit(); err != nil {
		return err
	}
	s.performanceMu.Lock()
	delete(s.performance, id)
	s.performanceMu.Unlock()
	s.lifecycleMu.Lock()
	delete(s.unownedAlerts, id)
	s.lifecycleMu.Unlock()
	return nil
}
func roomInTx(ctx context.Context, tx *sql.Tx, id string) (storedRoom, error) {
	var room storedRoom
	var rules string
	err := tx.QueryRowContext(ctx, `SELECT r.id,r.name,r.private,r.code,r.created,r.rules,r.protocol,r.content,r.closed,w.id,w.port,w.heartbeat,w.ready,w.state,w.guests FROM rooms r JOIN workers w ON w.id=r.worker WHERE r.id=?`, id).Scan(&room.ID, &room.Name, &room.private, &room.code, &room.Created, &rules, &room.protocol, &room.content, &room.closed, &room.worker, &room.port, &room.heartbeat, &room.ready, &room.State, &room.guests)
	if err != nil {
		return room, err
	}
	if err = json.Unmarshal([]byte(rules), &room.Rules); err != nil {
		return room, err
	}
	room.Capacity = 8
	return room, nil
}
func occupants(ctx context.Context, tx *sql.Tx, room storedRoom, now int64) (map[string]bool, error) {
	var active []string
	if json.Unmarshal([]byte(room.guests), &active) != nil {
		return nil, errors.New("invalid worker guests")
	}
	set := map[string]bool{}
	for _, guest := range active {
		set[guest] = true
	}
	rows, err := tx.QueryContext(ctx, `SELECT guest FROM reservations WHERE room=? AND expires>?`, room.ID, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var guest string
		if err = rows.Scan(&guest); err != nil {
			return nil, err
		}
		set[guest] = true
	}
	return set, rows.Err()
}
func (s *Service) joinRoom(ctx context.Context, session Session, id string, protocol int, content string, byCode bool) (JoinReply, error) {
	unavailable := apiError(409, "room_unavailable")
	if byCode {
		unavailable = apiError(404, "room_unavailable")
	}
	if !s.compatible(protocol, content) {
		if byCode {
			return JoinReply{}, unavailable
		}
		return JoinReply{}, apiError(409, "incompatible")
	}
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return JoinReply{}, err
	}
	defer tx.Rollback()
	now := s.config.Now().Unix()
	room, err := roomInTx(ctx, tx, id)
	if err != nil {
		if err == sql.ErrNoRows {
			_ = tx.Commit()
			return JoinReply{}, unavailable
		}
		return JoinReply{}, err
	}
	if room.closed || !room.ready || room.heartbeat <= now-15 || room.State != "Lobby" || (room.private && !byCode) {
		_ = tx.Commit()
		return JoinReply{}, unavailable
	}
	// A delivered-but-unacknowledged leave could otherwise evict a fresh
	// admission for the same guest. Wait until the worker confirms removal.
	var leaving int
	if err = tx.QueryRowContext(ctx, `SELECT count(*) FROM worker_commands WHERE worker=? AND kind='leave' AND guest=?`, room.worker, session.Guest).Scan(&leaving); err != nil {
		return JoinReply{}, err
	}
	if leaving != 0 {
		_ = tx.Commit()
		return JoinReply{}, unavailable
	}
	set, err := occupants(ctx, tx, room, now)
	if err != nil {
		return JoinReply{}, err
	}
	if len(set) >= 8 && !set[session.Guest] {
		_ = tx.Commit()
		return JoinReply{}, unavailable
	}
	var banned int
	if err = tx.QueryRowContext(ctx, `SELECT banned FROM guests WHERE id=?`, session.Guest).Scan(&banned); err != nil {
		return JoinReply{}, err
	}
	if banned != 0 {
		_ = tx.Commit()
		return JoinReply{}, unavailable
	}
	claims := TicketClaims{Version: 1, Guest: session.Guest, Name: session.Name, Room: room.ID, Worker: room.worker, Protocol: s.config.Protocol, Content: s.config.Content, Issued: now, Expires: now + 60, Nonce: hex.EncodeToString(randomBytes(16))}
	ticket, err := SignTicket(s.config.SigningKey, claims)
	if err != nil {
		return JoinReply{}, err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO reservations(room,guest,nonce,expires,ticket_expires) VALUES(?,?,?,?,?) ON CONFLICT(room,guest) DO UPDATE SET nonce=excluded.nonce,expires=excluded.expires,ticket_expires=excluded.ticket_expires,consumed=0`, id, session.Guest, claims.Nonce, now+15, claims.Expires); err != nil {
		return JoinReply{}, err
	}
	if err = tx.Commit(); err != nil {
		return JoinReply{}, err
	}
	return JoinReply{Room: room.ID, Worker: room.worker, Host: s.config.WorkerHost, Port: room.port, Ticket: ticket, Expires: claims.Expires, Protocol: s.config.Protocol, Content: s.config.Content, Region: s.config.Region}, nil
}
func (s *Service) JoinCode(ctx context.Context, session Session, code string, protocol int, content string) (JoinReply, error) {
	if err := s.joinAttempt(ctx, session.Guest); err != nil {
		return JoinReply{}, err
	}
	code = normalizeCode(code)
	var id string
	if code == "" {
		return JoinReply{}, apiError(404, "room_unavailable")
	}
	err := s.store.db.QueryRowContext(ctx, `SELECT id FROM rooms WHERE code=? AND private=1 AND closed=0`, code).Scan(&id)
	if err == sql.ErrNoRows {
		return JoinReply{}, apiError(404, "room_unavailable")
	}
	if err != nil {
		return JoinReply{}, err
	}
	return s.joinRoom(ctx, session, id, protocol, content, true)
}

func (s *Service) joinAttempt(ctx context.Context, guest string) error {
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err = checkRate(ctx, tx, guest, "join", s.config.Now().Unix(), 60, 20); err != nil {
		return err
	}
	return tx.Commit()
}
func (s *Service) JoinRoom(ctx context.Context, session Session, id string, protocol int, content string) (JoinReply, error) {
	if err := s.joinAttempt(ctx, session.Guest); err != nil {
		return JoinReply{}, err
	}
	return s.joinRoom(ctx, session, id, protocol, content, false)
}
func (s *Service) Rooms(ctx context.Context, protocol int, content string, showInRace bool) ([]RoomInfo, error) {
	if !s.compatible(protocol, content) {
		return nil, apiError(409, "incompatible")
	}
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	now := s.config.Now().Unix()
	rows, err := tx.QueryContext(ctx, `SELECT r.id FROM rooms r JOIN workers w ON w.id=r.worker WHERE r.private=0 AND r.closed=0 AND r.protocol=? AND r.content=? AND w.ready=1 AND w.heartbeat>? ORDER BY r.created,r.id`, protocol, content, now-15)
	if err != nil {
		return nil, err
	}
	ids := []string{}
	for rows.Next() {
		var id string
		if err = rows.Scan(&id); err != nil {
			rows.Close()
			return nil, err
		}
		ids = append(ids, id)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return nil, err
	}
	result := []RoomInfo{}
	for _, id := range ids {
		room, err := roomInTx(ctx, tx, id)
		if err != nil {
			return nil, err
		}
		set, err := occupants(ctx, tx, room, now)
		if err != nil {
			return nil, err
		}
		if !showInRace && (room.State != "Lobby" || len(set) >= 8) {
			continue
		}
		room.Humans = len(set)
		room.Region = s.config.Region
		result = append(result, room.RoomInfo)
	}
	return result, tx.Commit()
}
