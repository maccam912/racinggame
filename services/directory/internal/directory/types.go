package directory

import (
	"crypto/rsa"
	"errors"
	"net/netip"
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
}
type Service struct {
	store  *Store
	config Config
}

func New(store *Store, config Config) (*Service, error) {
	if len(config.EncryptionKey) != 32 || config.SigningKey == nil || config.SigningKey.N.BitLen() != 2048 || config.Protocol < 1 || len(config.Content) != 64 {
		return nil, errors.New("invalid service configuration")
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
	return &Service{store: store, config: config}, nil
}

type Session struct {
	Guest   string `json:"guest_id"`
	Name    string `json:"display_name"`
	Token   string `json:"session_token"`
	Expires int64  `json:"expires_at"`
}
