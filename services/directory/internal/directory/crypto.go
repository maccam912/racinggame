package directory

import (
	"crypto"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/subtle"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"strings"
	"time"
)

var raw64 = base64.RawURLEncoding.Strict()
var errCredential = errors.New("invalid_credential")

func randomBytes(size int) []byte {
	value := make([]byte, size)
	if _, err := rand.Read(value); err != nil {
		panic("cryptographic random source unavailable")
	}
	return value
}
func randomToken() string        { return raw64.EncodeToString(randomBytes(32)) }
func digest(value string) []byte { sum := sha256.Sum256([]byte(value)); return sum[:] }
func UUID() string {
	bytes := randomBytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	text := hex.EncodeToString(bytes)
	return text[:8] + "-" + text[8:12] + "-" + text[12:16] + "-" + text[16:20] + "-" + text[20:]
}
func validUUID(value string) bool {
	if len(value) != 36 || value[8] != '-' || value[13] != '-' || value[18] != '-' || value[23] != '-' {
		return false
	}
	bytes, err := hex.DecodeString(strings.ReplaceAll(value, "-", ""))
	return err == nil && len(bytes) == 16 && bytes[6]>>4 == 4 && bytes[8]>>6 == 2 && strings.ToLower(value) == value
}
func decodeSecret(value string) ([]byte, error) {
	bytes, err := raw64.DecodeString(value)
	if err != nil || len(bytes) != 32 {
		return nil, errCredential
	}
	return bytes, nil
}
func encryptSecret(key, secret []byte, guest string) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := randomBytes(aead.NonceSize())
	return aead.Seal(nonce, nonce, secret, []byte(guest)), nil
}
func decryptSecret(key, ciphertext []byte, guest string) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil || len(ciphertext) < aead.NonceSize() {
		return nil, errCredential
	}
	return aead.Open(nil, ciphertext[:aead.NonceSize()], ciphertext[aead.NonceSize():], []byte(guest))
}
func AuthProof(secret []byte, guest, nonce, name string) string {
	mac := hmac.New(sha256.New, secret)
	fmt.Fprintf(mac, "pacific-rush-auth-v1\n%s\n%s\n%s", guest, nonce, name)
	return raw64.EncodeToString(mac.Sum(nil))
}
func equalString(a, b string) bool { return subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1 }

// Compact claims keep the complete admission hello below the UDP payload budget.
type TicketClaims struct {
	Version  int    `json:"v"`
	Guest    string `json:"g"`
	Name     string `json:"n"`
	Room     string `json:"r"`
	Worker   string `json:"w"`
	Protocol int    `json:"p"`
	Content  string `json:"c"`
	Issued   int64  `json:"i"`
	Expires  int64  `json:"e"`
	Nonce    string `json:"x"`
}

func SignTicket(key *rsa.PrivateKey, claims TicketClaims) (string, error) {
	if key == nil || key.N.BitLen() != 2048 {
		return "", errors.New("ticket key must be RSA-2048")
	}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(payload)
	signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, sum[:])
	if err != nil {
		return "", err
	}
	ticket := raw64.EncodeToString(payload) + "." + raw64.EncodeToString(signature)
	if len(ticket) > 1100 {
		return "", errors.New("ticket exceeds admission budget")
	}
	return ticket, nil
}
func VerifyTicket(key *rsa.PublicKey, ticket string, now time.Time, room, worker string, protocol int, content string) (TicketClaims, error) {
	var claims TicketClaims
	parts := strings.Split(ticket, ".")
	if len(parts) != 2 || len(ticket) > 1100 || key == nil || key.N.BitLen() != 2048 {
		return claims, errCredential
	}
	payload, err := raw64.DecodeString(parts[0])
	if err != nil {
		return claims, errCredential
	}
	signature, err := raw64.DecodeString(parts[1])
	if err != nil {
		return claims, errCredential
	}
	sum := sha256.Sum256(payload)
	if rsa.VerifyPKCS1v15(key, crypto.SHA256, sum[:], signature) != nil || json.Unmarshal(payload, &claims) != nil {
		return claims, errCredential
	}
	if claims.Version != 1 || !validUUID(claims.Guest) || claims.Room != room || claims.Worker != worker || claims.Protocol != protocol || claims.Content != content || claims.Issued > now.Unix() || claims.Expires <= now.Unix() || claims.Expires <= claims.Issued || claims.Expires-claims.Issued > 60 || len(claims.Nonce) != 32 {
		return TicketClaims{}, errCredential
	}
	return claims, nil
}
func PublicPEM(key *rsa.PublicKey) ([]byte, error) {
	data, err := x509.MarshalPKIXPublicKey(key)
	if err != nil {
		return nil, err
	}
	return pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: data}), nil
}
