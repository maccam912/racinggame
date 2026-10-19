package directory

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/json"
	"os"
	"time"
)

// WriteTicketFixture creates ephemeral test material. Only its public key and
// test tickets are written. It never reads deployment keys or guest storage.
func WriteTicketFixture(filename, content string, protocol int) error {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return err
	}
	public, err := PublicPEM(&key.PublicKey)
	if err != nil {
		return err
	}
	claims := TicketClaims{Version: 1, Guest: UUID(), Name: "Café Driver", Room: UUID(), Worker: UUID(), Protocol: protocol, Content: content, Issued: 1800000000, Expires: 1800000060, Nonce: "0123456789abcdef0123456789abcdef"}
	ticket, err := SignTicket(key, claims)
	if err != nil {
		return err
	}
	variants := map[string]string{}
	for name, modify := range map[string]func(*TicketClaims){"long_lifetime": func(c *TicketClaims) { c.Expires++ }, "future": func(c *TicketClaims) { c.Issued += 10; c.Expires += 10 }, "bad_nonce": func(c *TicketClaims) { c.Nonce = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz" }, "bad_name": func(c *TicketClaims) { c.Name = "<markup>" }, "protocol": func(c *TicketClaims) { c.Protocol++ }, "content": func(c *TicketClaims) { c.Content = "bad" }, "room": func(c *TicketClaims) { c.Room = UUID() }} {
		copy := claims
		modify(&copy)
		variants[name], err = SignTicket(key, copy)
		if err != nil {
			return err
		}
	}
	data, err := json.MarshalIndent(map[string]any{"public_pem": string(public), "ticket": ticket, "claims": claims, "variants": variants, "now": time.Unix(claims.Issued, 0).Unix()}, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filename, append(data, '\n'), 0600)
}
