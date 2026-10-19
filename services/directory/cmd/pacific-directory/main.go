package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/maccam912/racinggame/services/directory/internal/directory"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "PACIFIC_DIRECTORY_ERROR", err)
		os.Exit(1)
	}
}
func run() error {
	if len(os.Args) < 2 {
		return errors.New("use keygen, serve, drain, ban or unban")
	}
	switch os.Args[1] {
	case "keygen":
		flags := flag.NewFlagSet("keygen", flag.ContinueOnError)
		folder := flags.String("keys", "var/keys", "operator key directory")
		if err := flags.Parse(os.Args[2:]); err != nil {
			return err
		}
		return directory.GenerateKeys(*folder)
	case "ban", "unban":
		flags := flag.NewFlagSet("ban", flag.ContinueOnError)
		database := flags.String("db", "var/directory.sqlite", "SQLite file")
		guest := flags.String("guest", "", "guest UUID")
		if err := flags.Parse(os.Args[2:]); err != nil {
			return err
		}
		store, err := directory.OpenStore(*database)
		if err != nil {
			return err
		}
		defer store.Close()
		return store.Ban(*guest, os.Args[1] == "ban")
	case "serve":
		return serve(os.Args[2:])
	case "drain":
		flags := flag.NewFlagSet("drain", flag.ContinueOnError)
		database := flags.String("db", "var/directory.sqlite", "SQLite file")
		workerID := flags.String("worker", "", "one worker UUID")
		all := flags.Bool("all", false, "drain all currently registered workers")
		if err := flags.Parse(os.Args[2:]); err != nil {
			return err
		}
		if (*workerID == "") == !*all {
			return errors.New("select one worker or --all")
		}
		store, err := directory.OpenStore(*database)
		if err != nil {
			return err
		}
		defer store.Close()
		ids := []string{*workerID}
		if *all {
			ids, err = store.WorkerIDs(context.Background(), "", true)
			if err != nil {
				return err
			}
		}
		count, err := store.DrainWorkers(context.Background(), ids, time.Now().Unix())
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(map[string]any{"draining": count})
	default:
		return errors.New("unknown command")
	}
}
func serve(args []string) error {
	flags := flag.NewFlagSet("serve", flag.ContinueOnError)
	database := flags.String("db", "var/directory.sqlite", "SQLite file")
	keys := flags.String("keys", "var/keys", "operator key directory")
	logs := flags.String("logs", "var/logs", "seven-day structured logs")
	listen := flags.String("listen", "127.0.0.1:8080", "public HTTP listener behind HTTPS proxy")
	privateListen := flags.String("private-listen", "127.0.0.1:8081", "separate loopback worker listener")
	publicURL := flags.String("public-url", "", "advertised HTTPS URL")
	region := flags.String("region", "test", "region ID")
	regionName := flags.String("region-name", "Test Region", "region name")
	workerHost := flags.String("worker-host", "127.0.0.1", "advertised worker DNS/IP")
	worker := flags.String("worker", "", "absolute Godot/server executable path")
	project := flags.String("worker-project", "", "source project for development only")
	ports := flags.Int("first-port", 27020, "first UDP pool port")
	maximum := flags.Int("workers", 8, "maximum workers")
	hostMaximum := flags.Int("host-workers", 0, "shared database worker cap across rollout pools; defaults to --workers")
	protocol := flags.Int("protocol", 0, "exact protocol version")
	content := flags.String("content-hash", "", "exact content SHA-256")
	insecure := flags.Bool("allow-insecure-loopback", false, "explicit development HTTP exception")
	proxies := flags.String("trusted-proxies", "127.0.0.1/32,::1/128", "trusted HTTPS proxy CIDRs")
	apiLimit := flags.Int("ip-api-limit", 120, "API requests per IP/minute")
	registerLimit := flags.Int("ip-register-limit", 20, "registrations per IP/hour")
	if err := flags.Parse(args); err != nil {
		return err
	}
	host, _, err := net.SplitHostPort(*privateListen)
	if err != nil {
		return errors.New("invalid private listener")
	}
	ip, err := netip.ParseAddr(host)
	if err != nil || !ip.IsLoopback() {
		return errors.New("worker listener must use explicit loopback address")
	}
	if !*insecure && !strings.HasPrefix(*publicURL, "https://") {
		return errors.New("configure an HTTPS public URL")
	}
	encryption, signing, err := directory.LoadKeys(*keys)
	if err != nil {
		return err
	}
	store, err := directory.OpenStore(*database)
	if err != nil {
		return err
	}
	defer store.Close()
	log, err := directory.NewDailyLog(*logs)
	if err != nil {
		return err
	}
	defer log.Close()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	stopSignals := make(chan os.Signal, 2)
	signal.Notify(stopSignals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(stopSignals)
	config := directory.Config{EncryptionKey: encryption, SigningKey: signing, Protocol: *protocol, Content: *content, Region: *region, RegionName: *regionName, PublicURL: *publicURL, WorkerHost: *workerHost, AllowInsecureLoopback: *insecure, FirstPort: *ports, MaxWorkers: *maximum, HostMaxWorkers: *hostMaximum, IPRequestLimit: *apiLimit, IPRegisterLimit: *registerLimit, RequirePerformance: true, PerformanceEvents: log, WorkerPrivateURL: "http://" + *privateListen}
	for _, value := range strings.Split(*proxies, ",") {
		if value == "" {
			continue
		}
		prefix, err := netip.ParsePrefix(value)
		if err != nil {
			return errors.New("invalid proxy CIDR")
		}
		config.TrustedProxies = append(config.TrustedProxies, prefix)
	}
	workerArgs := []string{"--headless"}
	if *project != "" {
		absolute, err := filepath.Abs(*project)
		if err != nil {
			return err
		}
		workerArgs = append(workerArgs, "--path", absolute)
	}
	workerArgs = append(workerArgs, "--", "--server", "--auth-mode=ticket_required")
	publicKey, err := filepath.Abs(filepath.Join(*keys, "admission.pub"))
	if err != nil {
		return err
	}
	var service *directory.Service
	allocator, err := directory.NewProcessAllocator(directory.ProcessSpec{Root: ctx, Executable: *worker, Arguments: workerArgs, PublicKeyFile: publicKey, PrivateURL: "http://" + *privateListen, MaxWorkers: *maximum, Events: log, OnExit: func(id string) {
		if service != nil {
			cleanup, stop := context.WithTimeout(context.Background(), 5*time.Second)
			defer stop()
			_ = service.ReleaseWorker(cleanup, id)
		}
	}})
	if err != nil {
		return err
	}
	defer allocator.Close()
	config.Allocator = allocator
	service, err = directory.New(store, config)
	if err != nil {
		return err
	}
	privateServer := &http.Server{Addr: *privateListen, Handler: service.PrivateHandler(), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 8192}
	publicServer := &http.Server{Addr: *listen, Handler: service.Handler(), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 8192}
	privateSocket, err := net.Listen("tcp", *privateListen)
	if err != nil {
		return errors.New("cannot bind private listener")
	}
	defer privateSocket.Close()
	publicSocket, err := net.Listen("tcp", *listen)
	if err != nil {
		return errors.New("cannot bind public listener")
	}
	defer publicSocket.Close()
	if err = service.RecoverWorkers(ctx); err != nil {
		return err
	}
	if err = service.ReconcileWorkers(ctx, allocator); err != nil {
		return err
	}
	failures := make(chan error, 2)
	go func() { failures <- privateServer.Serve(privateSocket) }()
	go func() { failures <- publicServer.Serve(publicSocket) }()
	_ = json.NewEncoder(log).Encode(map[string]any{"at": time.Now().UTC().Format(time.RFC3339), "code": "directory_ready", "protocol": *protocol, "content_hash": *content})
	fmt.Println("PACIFIC_DIRECTORY_READY")
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	reconcile := time.NewTicker(5 * time.Second)
	defer reconcile.Stop()
	for {
		select {
		case <-stopSignals:
			ids := allocator.StopAccepting()
			if err = service.BeginDrain(ctx, ids); err != nil {
				return err
			}
			_ = json.NewEncoder(log).Encode(map[string]any{"at": time.Now().UTC().Format(time.RFC3339), "code": "directory_draining", "workers": len(ids)})
			shutdown, stop := context.WithTimeout(context.Background(), 5*time.Second)
			if publicServer.Shutdown(shutdown) != nil {
				_ = publicServer.Close()
			}
			stop()
			deadline := time.Now().Add(605 * time.Second)
			drainTick := time.NewTicker(time.Second)
			for allocator.Count() > 0 && time.Now().Before(deadline) {
				select {
				case <-stopSignals:
					deadline = time.Now()
				case <-drainTick.C:
					if err = service.ReconcileWorkers(ctx, allocator); err != nil {
						deadline = time.Now()
					}
				}
			}
			drainTick.Stop()
			cancel()
			allocator.Close()
			shutdown, stop = context.WithTimeout(context.Background(), 5*time.Second)
			_ = privateServer.Shutdown(shutdown)
			stop()
			return nil
		case err := <-failures:
			if !errors.Is(err, http.ErrServerClosed) {
				return errors.New("HTTP listener failed")
			}
			return nil
		case <-ticker.C:
			_ = store.Prune(ctx, time.Now().Unix())
		case <-reconcile.C:
			if err = service.ReconcileWorkers(ctx, allocator); err != nil {
				_ = json.NewEncoder(log).Encode(map[string]any{"at": time.Now().UTC().Format(time.RFC3339), "code": "worker_reconcile_failed"})
			}
		}
	}
}
