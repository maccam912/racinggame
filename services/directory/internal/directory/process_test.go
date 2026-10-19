package directory

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestWorkerHelperProcess(t *testing.T) {
	if os.Getenv("PR_GO_TEST_CHILD") != "1" {
		return
	}
	if os.Getenv("PR_DIRECTORY_TEST_SECRET") != "" {
		os.Exit(11)
	}
	var config struct {
		ID    string `json:"worker_id"`
		Token string `json:"token"`
		URL   string `json:"private_url"`
		Name  string `json:"name"`
		Rules Rules  `json:"rules"`
	}
	if json.Unmarshal([]byte(os.Getenv("PR_WORKER_CONFIG")), &config) != nil {
		os.Exit(12)
	}
	body, _ := json.Marshal(HeartbeatRequest{State: "Lobby", Ready: true, Guests: []string{}, Rules: config.Rules, Name: config.Name})
	request, _ := http.NewRequest("POST", config.URL+"/workers/"+config.ID+"/heartbeat", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer "+config.Token)
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		os.Exit(13)
	}
	response.Body.Close()
	if response.StatusCode != 200 {
		os.Exit(14)
	}
	// Parent must retain the child after the short allocation context ends.
	for {
		time.Sleep(time.Second)
	}
}
func TestProcessPoolOwnsLifetimeAndReapsWorkers(t *testing.T) {
	s, _ := testService(t)
	server := httptest.NewServer(s.PrivateHandler())
	defer server.Close()
	root, cancel := context.WithCancel(context.Background())
	defer cancel()
	t.Setenv("PR_DIRECTORY_TEST_SECRET", "must-not-reach-child")
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	exited := make(chan string, 2)
	allocator, err := NewProcessAllocator(ProcessSpec{Root: root, Executable: executable, Arguments: []string{"-test.run=^TestWorkerHelperProcess$"}, PublicKeyFile: filepath.Join(t.TempDir(), "public.pub"), PrivateURL: server.URL, MaxWorkers: 1, ExtraEnv: []string{"PR_GO_TEST_CHILD=1"}, OnExit: func(id string) { _ = s.ReleaseWorker(context.Background(), id); exited <- id }})
	if err != nil {
		t.Fatal(err)
	}
	defer allocator.Close()
	s.config.Allocator = allocator
	guest := guestFor(t, s)
	created := createFor(t, s, guest, false)
	// CreateRoom cancelled its readiness context on return. The child still lives.
	time.Sleep(30 * time.Millisecond)
	allocator.mu.Lock()
	count := len(allocator.children)
	allocator.mu.Unlock()
	if count != 1 {
		t.Fatal("request cancellation killed the room")
	}
	if err = allocator.Start(context.Background(), Allocation{ID: UUID()}); err == nil {
		t.Fatal("process cap bypassed")
	}
	if err = allocator.Stop(created.Worker); err != nil {
		t.Fatal(err)
	}
	select {
	case id := <-exited:
		if id != created.Worker {
			t.Fatal("wrong exit")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("worker not reaped")
	}
	var rows int
	s.store.db.QueryRow(`SELECT count(*) FROM workers`).Scan(&rows)
	if rows != 0 {
		t.Fatal("port not released after process exit")
	}
	createFor(t, s, guest, false)
	cancel()
	select {
	case <-exited:
	case <-time.After(5 * time.Second):
		t.Fatal("root cancellation did not reap child")
	}
}
func TestKeyGenerationRefusesReplacementAndLoads(t *testing.T) {
	folder := filepath.Join(t.TempDir(), "keys")
	if err := GenerateKeys(folder); err != nil {
		t.Fatal(err)
	}
	encryption, key, err := LoadKeys(folder)
	if err != nil || len(encryption) != 32 || key.N.BitLen() != 2048 {
		t.Fatal("load generated keys", err)
	}
	before, _ := os.ReadFile(filepath.Join(folder, "admission.key"))
	if GenerateKeys(folder) == nil {
		t.Fatal("keygen overwrote deployment keys")
	}
	after, _ := os.ReadFile(filepath.Join(folder, "admission.key"))
	if !bytes.Equal(before, after) {
		t.Fatal("key changed")
	}
}
func TestDailyLogRetentionAndCeiling(t *testing.T) {
	folder := t.TempDir()
	now := time.Date(2026, 10, 19, 12, 0, 0, 0, time.UTC)
	for _, day := range []string{"2026-10-11", "2026-10-12", "2026-10-13", "2026-10-18"} {
		if err := os.WriteFile(filepath.Join(folder, day+".jsonl"), []byte("{}\n"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	log, err := NewDailyLog(folder)
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	log.Now = func() time.Time { return now }
	if _, err = fmt.Fprintln(log, `{"code":"test"}`); err != nil {
		t.Fatal(err)
	}
	if _, err = os.Stat(filepath.Join(folder, "2026-10-12.jsonl")); !os.IsNotExist(err) {
		t.Fatal("old logs retained")
	}
	if _, err = os.Stat(filepath.Join(folder, "2026-10-13.jsonl")); err != nil {
		t.Fatal("seventh day removed")
	}
	log.size = 100 * 1024 * 1024
	before, _ := log.file.Stat()
	log.Write([]byte(strings.Repeat("x", 100)))
	after, _ := log.file.Stat()
	if before.Size() != after.Size() {
		t.Fatal("daily ceiling exceeded")
	}
	now = now.AddDate(0, 0, 1)
	var wg sync.WaitGroup
	for index := 0; index < 10; index++ {
		wg.Add(1)
		go func() { defer wg.Done(); log.Write([]byte("{}\n")) }()
	}
	wg.Wait()
	if log.day != "2026-10-20" || log.size != 30 {
		t.Fatal("new-day rotation/concurrent events")
	}
}
