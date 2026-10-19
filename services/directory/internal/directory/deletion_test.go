package directory

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

func TestDeletionRequestSessionBindingStrictBodyAndIdempotence(t *testing.T) {
	s, clock := testService(t)
	a, b := guestFor(t, s), guestFor(t, s)
	server := httptest.NewTLSServer(s.Handler())
	defer server.Close()
	post := func(token, body string, want int) map[string]any {
		t.Helper()
		r, _ := http.NewRequest("POST", server.URL+"/v1/data/deletion-request", strings.NewReader(body))
		r.Header.Set("Content-Type", "application/json")
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		response, err := server.Client().Do(r)
		if err != nil {
			t.Fatal(err)
		}
		defer response.Body.Close()
		data, _ := io.ReadAll(response.Body)
		if response.StatusCode != want {
			t.Fatalf("status %d, wanted %d: %s", response.StatusCode, want, data)
		}
		var value map[string]any
		if json.Unmarshal(data, &value) != nil {
			t.Fatal("invalid response")
		}
		if bytes.Contains(data, []byte(a.Guest)) || bytes.Contains(data, []byte(a.Token)) {
			t.Fatal("public response includes identity or bearer")
		}
		return value
	}
	post("", "{}", 401)
	post(randomToken(), "{}", 401)
	post(a.Token, `{"guest_id":"`+b.Guest+`"}`, 400)
	post(a.Token, "{} {}", 400)
	post(a.Token, "null", 400)
	first := post(a.Token, "{}", 202)
	clock.Add(60)
	if other := post(a.Token, "{}", 202); first["request_id"] != other["request_id"] || first["created_at"] != other["created_at"] || other["status"] != "pending_operator" {
		t.Fatal("duplicate request changed receipt")
	}
	second := post(b.Token, "{}", 202)
	rows, err := s.store.DeletionRequests(context.Background(), "", 1)
	if err != nil || len(rows) != 1 || rows[0].Guest != a.Guest || rows[0].ID != first["request_id"] {
		t.Fatal("operator lookup not session-bound", rows, err)
	}
	more, err := s.store.DeletionRequests(context.Background(), rows[0].ID, 1)
	if err != nil || len(more) != 1 || more[0].Guest != b.Guest || more[0].ID != second["request_id"] {
		t.Fatal("operator pagination lost second request", more, err)
	}
	if _, err = s.Authorize(context.Background(), a.Token); err != nil {
		t.Fatal("request unexpectedly erased or revoked identity", err)
	}
	clock.Add(3600)
	post(a.Token, "{}", 401)
	if _, err = s.store.DeletionRequests(context.Background(), UUID(), 100); err == nil {
		t.Fatal("unknown cursor accepted")
	}
}

func TestConcurrentDeletionRequestsProduceOneDurableReceipt(t *testing.T) {
	s, _ := testService(t)
	guest := guestFor(t, s)
	var group sync.WaitGroup
	ids := make(chan string, 32)
	for range 32 {
		group.Go(func() {
			value, err := s.RequestDeletion(context.Background(), guest)
			if err != nil {
				t.Error(err)
				return
			}
			ids <- value.ID
		})
	}
	group.Wait()
	close(ids)
	var first string
	for id := range ids {
		if first == "" {
			first = id
		}
		if first != id {
			t.Fatal("concurrent requests produced different receipts")
		}
	}
	rows, err := s.store.DeletionRequests(context.Background(), "", 100)
	if err != nil || len(rows) != 1 || !validUUID(first) {
		t.Fatal("durable row missing", rows, err)
	}
}
