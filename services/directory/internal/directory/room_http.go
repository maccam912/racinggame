package directory

import (
	"net/http"
	"strconv"
	"strings"
)

func bearer(r *http.Request) string {
	value := r.Header.Get("Authorization")
	if !strings.HasPrefix(value, "Bearer ") || strings.Count(value, " ") != 1 {
		return ""
	}
	return strings.TrimPrefix(value, "Bearer ")
}
func (s *Service) sessionFor(w http.ResponseWriter, r *http.Request) (Session, bool) {
	session, err := s.Authorize(r.Context(), bearer(r))
	if err != nil {
		writeError(w, err)
		return Session{}, false
	}
	return session, true
}
func (s *Service) roomRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /v1/rooms", func(w http.ResponseWriter, r *http.Request) {
		protocol, err := strconv.Atoi(r.URL.Query().Get("protocol"))
		if err != nil {
			writeError(w, apiError(400, "invalid_query"))
			return
		}
		show := r.URL.Query().Get("show_in_race")
		if show != "" && show != "true" && show != "false" {
			writeError(w, apiError(400, "invalid_query"))
			return
		}
		rooms, err := s.Rooms(r.Context(), protocol, r.URL.Query().Get("content_hash"), show == "true")
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, 200, map[string]any{"rooms": rooms})
	})
	mux.HandleFunc("POST /v1/rooms", func(w http.ResponseWriter, r *http.Request) {
		session, ok := s.sessionFor(w, r)
		if !ok {
			return
		}
		var request CreateRequest
		if err := decodeJSON(w, r, &request); err != nil {
			writeError(w, err)
			return
		}
		reply, err := s.CreateRoom(r.Context(), session, request)
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, 201, reply)
	})
	mux.HandleFunc("POST /v1/rooms/{id}/join", func(w http.ResponseWriter, r *http.Request) {
		session, ok := s.sessionFor(w, r)
		if !ok {
			return
		}
		var request struct {
			Protocol int    `json:"protocol"`
			Content  string `json:"content_hash"`
		}
		if err := decodeJSON(w, r, &request); err != nil {
			writeError(w, err)
			return
		}
		reply, err := s.JoinRoom(r.Context(), session, r.PathValue("id"), request.Protocol, request.Content)
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, 200, reply)
	})
	mux.HandleFunc("POST /v1/rooms/code/join", func(w http.ResponseWriter, r *http.Request) {
		session, ok := s.sessionFor(w, r)
		if !ok {
			return
		}
		var request struct {
			Code     string `json:"code"`
			Protocol int    `json:"protocol"`
			Content  string `json:"content_hash"`
		}
		if err := decodeJSON(w, r, &request); err != nil {
			writeError(w, err)
			return
		}
		reply, err := s.JoinCode(r.Context(), session, request.Code, request.Protocol, request.Content)
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, 200, reply)
	})
	mux.HandleFunc("POST /v1/rooms/{id}/leave", func(w http.ResponseWriter, r *http.Request) {
		session, ok := s.sessionFor(w, r)
		if !ok {
			return
		}
		var request struct{}
		if err := decodeJSON(w, r, &request); err != nil {
			writeError(w, err)
			return
		}
		if err := s.LeaveRoom(r.Context(), session, r.PathValue("id")); err != nil {
			writeError(w, err)
			return
		}
		w.Header().Set("Cache-Control", "no-store")
		w.WriteHeader(204)
	})
}

// PrivateHandler must be bound to a separate listener. It is never registered on
// Handler and must never be reverse-proxied by the public HTTPS endpoint.
func (s *Service) PrivateHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /workers/{id}/heartbeat", func(w http.ResponseWriter, r *http.Request) {
		var request HeartbeatRequest
		if err := decodeJSON(w, r, &request); err != nil {
			writeError(w, err)
			return
		}
		reply, err := s.Heartbeat(r.Context(), r.PathValue("id"), bearer(r), request)
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, 200, reply)
	})
	mux.HandleFunc("POST /workers/{id}/consume", func(w http.ResponseWriter, r *http.Request) {
		var request struct {
			Guest string `json:"guest_id"`
			Nonce string `json:"nonce"`
		}
		if err := decodeJSON(w, r, &request); err != nil {
			writeError(w, err)
			return
		}
		if err := s.Consume(r.Context(), r.PathValue("id"), bearer(r), request.Guest, request.Nonce); err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, 200, map[string]bool{"accepted": true})
	})
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		address := socketIP(r)
		allowed := address.IsLoopback()
		for _, prefix := range s.config.WorkerNets {
			if prefix.Contains(address) {
				allowed = true
			}
		}
		if !allowed {
			writeError(w, apiError(403, "private_interface"))
			return
		}
		mux.ServeHTTP(w, r)
	})
}
