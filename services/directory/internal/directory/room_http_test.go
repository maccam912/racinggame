package directory

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestTLSRoomAPIAndPrivateListenerIsolation(t *testing.T) {
	s, _ := testService(t)
	a := newAllocator(s)
	session := guestFor(t, s)
	public := httptest.NewTLSServer(s.Handler())
	defer public.Close()
	private := httptest.NewServer(s.PrivateHandler())
	defer private.Close()
	request := func(client *http.Client, base, method, path, token string, value any, status int) []byte {
		t.Helper()
		data, _ := json.Marshal(value)
		req, _ := http.NewRequest(method, base+path, bytes.NewReader(data))
		req.Header.Set("Content-Type", "application/json; charset=utf-8")
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		response, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer response.Body.Close()
		body, _ := io.ReadAll(response.Body)
		if response.StatusCode != status {
			t.Fatalf("%s %s: got %d want %d: %s", method, path, response.StatusCode, status, body)
		}
		return body
	}
	create := CreateRequest{Name: "API Room", Region: s.config.Region, Rules: Rules{Track: 2, Laps: 1, BotFill: true, Difficulty: 2, Contact: true}, Protocol: 3, Content: s.config.Content}
	request(public.Client(), public.URL, "POST", "/v1/rooms", "", create, 401)
	var joined JoinReply
	body := request(public.Client(), public.URL, "POST", "/v1/rooms", session.Token, create, 201)
	if json.Unmarshal(body, &joined) != nil {
		t.Fatal("bad join response")
	}
	request(public.Client(), public.URL, "GET", "/v1/rooms?protocol=3&content_hash="+s.config.Content, "", nil, 200)
	request(public.Client(), public.URL, "GET", "/v1/rooms?protocol=3&content_hash="+s.config.Content+"&show_in_race=maybe", "", nil, 400)
	// There is no route from the public listener to worker status or admission.
	allocation := a.get(joined.Worker)
	heartbeat := heartbeatFor(allocation, "Lobby", nil)
	path := "/workers/" + allocation.ID + "/heartbeat"
	request(public.Client(), public.URL, "POST", path, allocation.Token, heartbeat, 404)
	request(http.DefaultClient, private.URL, "POST", path, randomToken(), heartbeat, 401)
	request(http.DefaultClient, private.URL, "POST", path, allocation.Token, heartbeat, 200)
	claim := claimsFor(t, s, joined)
	request(http.DefaultClient, private.URL, "POST", "/workers/"+allocation.ID+"/consume", allocation.Token, map[string]string{"guest_id": session.Guest, "nonce": claim.Nonce}, 200)
	request(public.Client(), public.URL, "POST", "/v1/rooms/"+joined.Room+"/leave", session.Token, map[string]any{}, 204)
	// A leave must be acknowledged before this guest can receive a new ticket.
	request(public.Client(), public.URL, "POST", "/v1/rooms/"+joined.Room+"/join", session.Token, map[string]any{"protocol": 3, "content_hash": s.config.Content}, 409)
	reply, err := s.Heartbeat(context.Background(), allocation.ID, allocation.Token, heartbeat)
	if err != nil || len(reply.Commands) != 1 {
		t.Fatal("leave delivery", reply, err)
	}
	heartbeat.Acknowledged = []string{reply.Commands[0].ID}
	reply, err = s.Heartbeat(context.Background(), allocation.ID, allocation.Token, heartbeat)
	if err != nil || len(reply.Commands) != 0 {
		t.Fatal("leave acknowledgement", reply, err)
	}
	request(public.Client(), public.URL, "POST", "/v1/rooms/"+joined.Room+"/join", session.Token, map[string]any{"protocol": 3, "content_hash": s.config.Content}, 200)
	// Forwarded headers never grant access to the separate private interface.
	req := httptest.NewRequest("POST", path, bytes.NewReader([]byte(`{}`)))
	req.RemoteAddr = "192.0.2.5:4000"
	req.Header.Set("X-Forwarded-For", "127.0.0.1")
	req.Header.Set("Authorization", "Bearer "+allocation.Token)
	rec := httptest.NewRecorder()
	s.PrivateHandler().ServeHTTP(rec, req)
	if rec.Code != 403 {
		t.Fatal("spoofed private address accepted")
	}
}
