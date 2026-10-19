package directory

import (
	"crypto/rsa"
	"encoding/hex"
	"errors"
	"io"
	"net/netip"
	"sync"
	"time"
)

var errFutureDatabase = errors.New("database uses a newer schema")

type APIError struct {
	Code   string
	Status int
	Retry  int
}

func (e *APIError) Error() string                { return e.Code }
func apiError(status int, code string) *APIError { return &APIError{Status: status, Code: code} }

type Config struct {
	EncryptionKey         []byte
	SigningKey            *rsa.PrivateKey
	Protocol              int
	Content               string
	Region                string
	RegionName            string
	PublicURL             string
	WorkerHost            string
	AllowInsecureLoopback bool
	TrustedProxies        []netip.Prefix
	Now                   func() time.Time
	IPRequestLimit        int
	IPRegisterLimit       int
	Allocator             Allocator
	FirstPort             int
	MaxWorkers            int
	ReadyTimeout          time.Duration
	WorkerNets            []netip.Prefix
	RequirePerformance    bool
	PerformanceEvents     io.Writer
}
type Service struct {
	store            *Store
	config           Config
	performanceMu    sync.Mutex
	performance      map[string]workerHealth
	performanceLogMu sync.Mutex
}

func New(store *Store, config Config) (*Service, error) {
	hash, hashErr := hex.DecodeString(config.Content)
	if store == nil || len(config.EncryptionKey) != 32 || config.SigningKey == nil || config.SigningKey.N.BitLen() != 2048 || config.Protocol < 1 || config.Protocol > 255 || hashErr != nil || len(hash) != 32 {
		return nil, errors.New("invalid service configuration")
	}
	if config.FirstPort == 0 {
		config.FirstPort = 27020
	}
	if config.MaxWorkers == 0 {
		config.MaxWorkers = 8
	}
	if config.ReadyTimeout == 0 {
		config.ReadyTimeout = 10 * time.Second
	}
	if config.ReadyTimeout < 0 || config.ReadyTimeout > 10*time.Second {
		return nil, errors.New("worker readiness must be bounded by ten seconds")
	}
	if config.WorkerHost == "" {
		config.WorkerHost = "127.0.0.1"
	}
	if config.Region == "" {
		config.Region = "test"
		config.RegionName = "Test Region"
	}
	if config.FirstPort < 1024 || config.MaxWorkers < 1 || config.MaxWorkers > 128 || config.FirstPort+config.MaxWorkers > 65536 {
		return nil, errors.New("invalid worker port pool")
	}
	if config.Now == nil {
		config.Now = time.Now
	}
	if config.IPRequestLimit <= 0 {
		config.IPRequestLimit = 120
	}
	if config.IPRegisterLimit <= 0 {
		config.IPRegisterLimit = 20
	}
	return &Service{store: store, config: config, performance: map[string]workerHealth{}}, nil
}

type Session struct {
	Guest   string `json:"guest_id"`
	Name    string `json:"display_name"`
	Token   string `json:"session_token"`
	Expires int64  `json:"expires_at"`
}
