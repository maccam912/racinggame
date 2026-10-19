package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"io"
	"net"
	"net/http"
	"net/netip"
	"time"
)

// A local operator readiness check, including the trusted loopback proxy header.
// It cannot follow redirects or probe arbitrary remote endpoints.
func probe(args []string) error {
	flags := flag.NewFlagSet("probe", flag.ContinueOnError)
	listen := flags.String("listen", "127.0.0.1:8080", "loopback public HTTP listener")
	if err := flags.Parse(args); err != nil {
		return err
	}
	host, _, err := net.SplitHostPort(*listen)
	address, ipErr := netip.ParseAddr(host)
	if err != nil || ipErr != nil || !address.IsLoopback() || flags.NArg() != 0 {
		return errors.New("probe requires an explicit loopback listener")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	request, err := http.NewRequestWithContext(ctx, "GET", "http://"+*listen+"/readyz", nil)
	if err != nil {
		return errors.New("invalid probe listener")
	}
	request.Header.Set("X-Forwarded-Proto", "https")
	client := http.Client{Transport: &http.Transport{Proxy: nil}, Timeout: 3 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	defer client.CloseIdleConnections()
	response, err := client.Do(request)
	if err != nil {
		return errors.New("directory not ready")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return errors.New("directory not ready")
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, 4097))
	if err != nil || len(data) > 4096 {
		return errors.New("invalid readiness response")
	}
	var value struct {
		Status string `json:"status"`
	}
	if json.Unmarshal(data, &value) != nil || value.Status != "ready" {
		return errors.New("directory not ready")
	}
	return nil
}
