package directory

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"strings"
	"testing"
)

func TestTLSGuestAPIAndStrictBodies(t *testing.T) {
	service, _ := testService(t)
	server := httptest.NewTLSServer(service.Handler())
	defer server.Close()
	client := server.Client()
	request := func(path string, value any, status int) []byte {
		t.Helper()
		data, _ := json.Marshal(value)
		response, err := client.Post(server.URL+path, "application/json", bytes.NewReader(data))
		if err != nil {
			t.Fatal(err)
		}
		defer response.Body.Close()
		body, _ := io.ReadAll(response.Body)
		if response.StatusCode != status {
			t.Fatalf("%s status %d wanted %d", path, response.StatusCode, status)
		}
		return body
	}
	guest := UUID()
	secret := randomBytes(32)
	body := request("/v1/guests", map[string]string{"guest_id": guest, "secret": raw64.EncodeToString(secret), "display_name": "Driver API"}, 201)
	var session Session
	if json.Unmarshal(body, &session) != nil || session.Token == "" {
		t.Fatal("registration session missing")
	}
	body = request("/v1/auth/challenge", map[string]string{"guest_id": guest}, 200)
	var challenge struct {
		Nonce string `json:"nonce"`
	}
	json.Unmarshal(body, &challenge)
	auth := map[string]string{"guest_id": guest, "nonce": challenge.Nonce, "proof": AuthProof(secret, guest, challenge.Nonce, "Driver API"), "display_name": "Driver API"}
	request("/v1/auth/session", auth, 200)
	request("/v1/auth/session", auth, 401)
	request("/v1/guests", map[string]string{"guest_id": UUID(), "secret": randomToken(), "display_name": "Driver New", "server_path": "/arbitrary"}, 400)
	response, err := client.Post(server.URL+"/v1/guests", "application/json", strings.NewReader(strings.Repeat(" ", 8193)))
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 400 {
		t.Fatal("oversized request accepted")
	}
}
func TestTransportAndProxyBoundaries(t *testing.T) {
	service, _ := testService(t)
	request := httptest.NewRequest("GET", "http://example.com/healthz", nil)
	request.RemoteAddr = "192.0.2.10:3000"
	request.Header.Set("X-Forwarded-Proto", "https")
	request.Header.Set("X-Forwarded-For", "198.51.100.2")
	recorder := httptest.NewRecorder()
	service.Handler().ServeHTTP(recorder, request)
	if recorder.Code != 400 {
		t.Fatal("untrusted proxy header bypassed TLS")
	}
	service.config.AllowInsecureLoopback = true
	recorder = httptest.NewRecorder()
	service.Handler().ServeHTTP(recorder, request)
	if recorder.Code != 400 {
		t.Fatal("development exception allowed remote cleartext")
	}
	request.RemoteAddr = "127.0.0.1:3000"
	recorder = httptest.NewRecorder()
	service.Handler().ServeHTTP(recorder, request)
	if recorder.Code != 200 {
		t.Fatal("explicit loopback exception failed")
	}
	service.config.AllowInsecureLoopback = false
	service.config.TrustedProxies = []netip.Prefix{netip.MustParsePrefix("127.0.0.1/32")}
	if service.clientIP(request).String() != "198.51.100.2" || !service.secureRequest(request) {
		t.Fatal("configured TLS proxy not recognized")
	}
	request.Header.Set("X-Forwarded-For", "203.0.113.99, 198.51.100.2")
	if service.clientIP(request).String() != "198.51.100.2" {
		t.Fatal("trusted leftmost forged address")
	}
}
func TestAPIRateLimitHasRetryAfter(t *testing.T) {
	service, _ := testService(t)
	service.config.AllowInsecureLoopback = true
	service.config.IPRequestLimit = 2
	for index := 0; index < 3; index++ {
		request := httptest.NewRequest(http.MethodGet, "http://localhost/healthz", nil)
		request.RemoteAddr = "127.0.0.1:3000"
		recorder := httptest.NewRecorder()
		service.Handler().ServeHTTP(recorder, request)
		if index < 2 && recorder.Code != 200 {
			t.Fatal("request rejected before limit")
		}
		if index == 2 && (recorder.Code != 429 || recorder.Header().Get("Retry-After") == "") {
			t.Fatal("missing 429/Retry-After")
		}
	}
}
