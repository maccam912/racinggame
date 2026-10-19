package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestReadinessProbeIsLocalBoundedAndDoesNotFollowRedirects(t *testing.T) {
	for _, test := range []struct {
		name   string
		status int
		body   string
		ok     bool
	}{
		{"ready", 200, `{"status":"ready"}`, true},
		{"draining", 503, `{"error":{"code":"not_ready"}}`, false},
		{"wrong status", 200, `{"status":"ok"}`, false},
		{"malformed", 200, `not-json`, false},
		{"too large", 200, strings.Repeat(" ", 4097), false},
		{"redirect", 302, ``, false},
	} {
		t.Run(test.name, func(t *testing.T) {
			calls := 0
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				calls++
				if r.URL.Path != "/readyz" || r.Header.Get("X-Forwarded-Proto") != "https" {
					t.Error("probe did not use loopback proxy contract")
				}
				if test.status == 302 {
					w.Header().Set("Location", "/redirected")
				}
				w.WriteHeader(test.status)
				_, _ = w.Write([]byte(test.body))
			}))
			defer server.Close()
			err := probe([]string{"--listen", strings.TrimPrefix(server.URL, "http://")})
			if (err == nil) != test.ok || calls != 1 {
				t.Fatal("probe result or redirect count", err, calls)
			}
		})
	}
	for _, address := range []string{"0.0.0.0:8080", "192.0.2.1:8080", "localhost:8080", "example.com:8080", "bad", "[::]:8080"} {
		if err := probe([]string{"--listen", address}); err == nil {
			t.Fatal("accepted remote/implicit listener", address)
		}
	}
}
