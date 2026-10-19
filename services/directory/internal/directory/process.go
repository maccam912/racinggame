package directory

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

// ProcessSpec is operator configuration. No HTTP request can supply these paths,
// arguments or environment values. The child's lifetime belongs to Root, not to
// the ten-second allocation request.
type ProcessSpec struct {
	Root          context.Context
	Executable    string
	Arguments     []string
	Directory     string
	PublicKeyFile string
	PrivateURL    string
	MaxWorkers    int
	OnExit        func(string)
	Events        io.Writer
	ExtraEnv      []string
}
type workerProcess struct {
	command *exec.Cmd
	done    chan struct{}
}
type ProcessAllocator struct {
	spec      ProcessSpec
	mu        sync.Mutex
	children  map[string]*workerProcess
	logMu     sync.Mutex
	stopping  bool
	finishing int
}

func NewProcessAllocator(spec ProcessSpec) (*ProcessAllocator, error) {
	if spec.Root == nil || !filepath.IsAbs(spec.Executable) || !filepath.IsAbs(spec.PublicKeyFile) || spec.PrivateURL == "" || spec.MaxWorkers < 1 || spec.MaxWorkers > 128 {
		return nil, errors.New("invalid process configuration")
	}
	return &ProcessAllocator{spec: spec, children: map[string]*workerProcess{}}, nil
}
func (a *ProcessAllocator) event(id, code string) {
	if a.spec.Events == nil {
		return
	}
	a.logMu.Lock()
	defer a.logMu.Unlock()
	_ = json.NewEncoder(a.spec.Events).Encode(map[string]any{"at": time.Now().UTC().Format(time.RFC3339), "worker": id, "code": code})
}
func (a *ProcessAllocator) Start(ctx context.Context, allocation Allocation) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if err := a.spec.Root.Err(); err != nil {
		return err
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.stopping || len(a.children) >= a.spec.MaxWorkers {
		return errors.New("worker pool full")
	}
	if _, exists := a.children[allocation.ID]; exists {
		return errors.New("duplicate worker")
	}
	config, _ := json.Marshal(map[string]any{"worker_id": allocation.ID, "room_id": allocation.Room, "port": allocation.Port, "token": allocation.Token, "name": allocation.Name, "private": allocation.Private, "code": allocation.Code, "region": allocation.Region, "rules": allocation.Rules, "protocol": allocation.Protocol, "content_hash": allocation.Content, "public_key_file": a.spec.PublicKeyFile, "private_url": a.spec.PrivateURL})
	command := exec.CommandContext(a.spec.Root, a.spec.Executable, a.spec.Arguments...)
	command.Dir = a.spec.Directory
	// Never inherit the directory's keys or bearer/session environment.
	for _, key := range []string{"HOME", "PATH", "TMPDIR", "TEMP", "TMP", "SystemRoot", "WINDIR"} {
		if value, ok := os.LookupEnv(key); ok {
			command.Env = append(command.Env, key+"="+value)
		}
	}
	command.Env = append(command.Env, a.spec.ExtraEnv...)
	command.Env = append(command.Env, "PR_WORKER_CONFIG="+string(config))
	// Raw engine output may contain user names or traces. Operations receives only
	// fixed structured events; explicit source integration tests capture raw logs.
	// A writer such as io.Discard makes os/exec create a supervisor-owned pipe.
	// Its reader disappears on a supervisor crash and can kill a surviving worker
	// with SIGPIPE on its next log write. Give the child direct null handles.
	sink, err := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
	if err != nil {
		return err
	}
	command.Stdout = sink
	command.Stderr = sink
	if err := command.Start(); err != nil {
		sink.Close()
		a.event(allocation.ID, "worker_start_failed")
		return err
	}
	sink.Close()
	child := &workerProcess{command: command, done: make(chan struct{})}
	a.children[allocation.ID] = child
	a.event(allocation.ID, "worker_started")
	go func() {
		err := command.Wait()
		a.mu.Lock()
		delete(a.children, allocation.ID)
		a.finishing++
		a.mu.Unlock()
		if err != nil {
			a.event(allocation.ID, "worker_exit_failure")
		} else {
			a.event(allocation.ID, "worker_exit")
		}
		if a.spec.OnExit != nil {
			a.spec.OnExit(allocation.ID)
		}
		a.mu.Lock()
		a.finishing--
		a.mu.Unlock()
		close(child.done)
	}()
	return nil
}
func (a *ProcessAllocator) Stop(id string) error {
	a.mu.Lock()
	child := a.children[id]
	a.mu.Unlock()
	if child == nil {
		return nil
	}
	_ = child.command.Process.Kill()
	select {
	case <-child.done:
		return nil
	case <-time.After(5 * time.Second):
		return errors.New("worker stop timeout")
	}
}
func (a *ProcessAllocator) Close() {
	a.mu.Lock()
	ids := make([]string, 0, len(a.children))
	for id := range a.children {
		ids = append(ids, id)
	}
	a.mu.Unlock()
	for _, id := range ids {
		_ = a.Stop(id)
	}
}

// StopAccepting and the returned ownership snapshot are atomic with Start.
func (a *ProcessAllocator) StopAccepting() []string {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.stopping = true
	ids := make([]string, 0, len(a.children))
	for id := range a.children {
		ids = append(ids, id)
	}
	return ids
}
func (a *ProcessAllocator) Owns(id string) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.children[id] != nil
}
func (a *ProcessAllocator) Count() int {
	a.mu.Lock()
	defer a.mu.Unlock()
	return len(a.children) + a.finishing
}
