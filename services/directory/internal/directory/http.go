package directory

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net"
	"net/http"
	"net/netip"
	"strconv"
	"strings"
	"unicode/utf8"
)

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func writeError(w http.ResponseWriter, err error) {
	var api *APIError
	if !errors.As(err, &api) {
		api = apiError(500, "service_unavailable")
	}
	if api.Retry > 0 {
		w.Header().Set("Retry-After", strconv.Itoa(api.Retry))
	}
	writeJSON(w, api.Status, map[string]any{"error": map[string]any{"code": api.Code}})
}
func decodeJSON(w http.ResponseWriter, r *http.Request, value any) error {
	mediaType, _, mediaErr := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if mediaErr != nil || mediaType != "application/json" {
		return apiError(415, "json_required")
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 8192))
	if err != nil || !utf8.Valid(body) {
		return apiError(400, "invalid_json")
	}
	decoder := json.NewDecoder(strings.NewReader(string(body)))
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(value); err != nil {
		return apiError(400, "invalid_json")
	}
	var extra any
	if decoder.Decode(&extra) != io.EOF {
		return apiError(400, "invalid_json")
	}
	return nil
}
func (s *Service) trusted(address netip.Addr) bool {
	for _, prefix := range s.config.TrustedProxies {
		if prefix.Contains(address) {
			return true
		}
	}
	return false
}
func socketIP(r *http.Request) netip.Addr {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	address, _ := netip.ParseAddr(host)
	return address.Unmap()
}
func (s *Service) clientIP(r *http.Request) netip.Addr {
	socket := socketIP(r)
	if !s.trusted(socket) {
		return socket
	}
	chain := r.Header.Get("X-Forwarded-For")
	if len(chain) > 512 {
		return socket
	}
	fields := strings.Split(chain, ",")
	if len(fields) > 8 {
		return socket
	}
	for index := len(fields) - 1; index >= 0; index-- {
		address, err := netip.ParseAddr(strings.TrimSpace(fields[index]))
		if err != nil {
			return socket
		}
		address = address.Unmap()
		if !s.trusted(address) {
			return address
		}
	}
	return socket
}
func (s *Service) secureRequest(r *http.Request) bool {
	return r.TLS != nil || s.config.AllowInsecureLoopback && socketIP(r).IsLoopback() || s.trusted(socketIP(r)) && r.Header.Get("X-Forwarded-Proto") == "https"
}
func (s *Service) ipSubject(r *http.Request) string {
	mac := hmac.New(sha256.New, s.config.EncryptionKey)
	mac.Write([]byte("pacific-rush-ip-rate-v1\n" + s.clientIP(r).String()))
	return "ip:" + hex.EncodeToString(mac.Sum(nil))
}
func (s *Service) ipRate(r *http.Request, kind string, window int64, limit int) error {
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err = checkRate(r.Context(), tx, s.ipSubject(r), kind, s.config.Now().Unix(), window, limit); err != nil {
		return err
	}
	return tx.Commit()
}
func (s *Service) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) { writeJSON(w, 200, map[string]string{"status": "ok"}) })
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if err := s.store.db.PingContext(r.Context()); err != nil || s.draining.Load() {
			writeError(w, apiError(503, "not_ready"))
			return
		}
		writeJSON(w, 200, map[string]string{"status": "ready"})
	})
	mux.HandleFunc("POST /v1/guests", s.registerHTTP)
	mux.HandleFunc("POST /v1/auth/challenge", s.challengeHTTP)
	mux.HandleFunc("POST /v1/auth/session", s.sessionHTTP)
	s.roomRoutes(mux)
	mux.HandleFunc("GET /v1/regions", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]any{"regions": []map[string]any{{"id": s.config.Region, "name": s.config.RegionName, "url": s.config.PublicURL, "available": !s.draining.Load(), "protocol": s.config.Protocol, "content_hash": s.config.Content}}})
	})
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !s.secureRequest(r) {
			writeError(w, apiError(400, "https_required"))
			return
		}
		if err := s.ipRate(r, "api", 60, s.config.IPRequestLimit); err != nil {
			writeError(w, err)
			return
		}
		mux.ServeHTTP(w, r)
	})
}
func (s *Service) registerHTTP(w http.ResponseWriter, r *http.Request) {
	if err := s.ipRate(r, "register", 3600, s.config.IPRegisterLimit); err != nil {
		writeError(w, err)
		return
	}
	var request struct {
		Guest  string `json:"guest_id"`
		Secret string `json:"secret"`
		Name   string `json:"display_name"`
	}
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.Register(r.Context(), request.Guest, request.Secret, request.Name)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, 201, result)
}
func (s *Service) challengeHTTP(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Guest string `json:"guest_id"`
	}
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, err)
		return
	}
	nonce, expires, err := s.Challenge(r.Context(), request.Guest)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, 200, map[string]any{"nonce": nonce, "expires_at": expires})
}
func (s *Service) sessionHTTP(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Guest string `json:"guest_id"`
		Nonce string `json:"nonce"`
		Proof string `json:"proof"`
		Name  string `json:"display_name"`
	}
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.Authenticate(r.Context(), request.Guest, request.Nonce, request.Proof, request.Name)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, 200, result)
}
