package directory

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"os"
	"path/filepath"
)

func GenerateKeys(folder string) error {
	if err := os.MkdirAll(folder, 0700); err != nil {
		return err
	}
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return err
	}
	public, err := PublicPEM(&key.PublicKey)
	if err != nil {
		return err
	}
	values := map[string][]byte{"encryption.key": randomBytes(32), "admission.key": pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)}), "admission.pub": public}
	// Refuse replacement before writing any file.
	for name := range values {
		if _, err := os.Stat(filepath.Join(folder, name)); !os.IsNotExist(err) {
			return errors.New("key file already exists")
		}
	}
	for name, value := range values {
		file, err := os.OpenFile(filepath.Join(folder, name), os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
		if err != nil {
			return err
		}
		_, err = file.Write(value)
		if err == nil {
			err = file.Sync()
		}
		closeErr := file.Close()
		if err != nil {
			return err
		}
		if closeErr != nil {
			return closeErr
		}
	}
	return nil
}
func LoadKeys(folder string) ([]byte, *rsa.PrivateKey, error) {
	encryption, err := os.ReadFile(filepath.Join(folder, "encryption.key"))
	if err != nil || len(encryption) != 32 {
		return nil, nil, errors.New("invalid encryption key file")
	}
	data, err := os.ReadFile(filepath.Join(folder, "admission.key"))
	if err != nil {
		return nil, nil, errors.New("cannot read admission key file")
	}
	block, _ := pem.Decode(data)
	if block == nil {
		return nil, nil, errors.New("invalid admission key file")
	}
	key, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil || key.N.BitLen() != 2048 {
		return nil, nil, errors.New("invalid RSA-2048 admission key")
	}
	publicData, err := os.ReadFile(filepath.Join(folder, "admission.pub"))
	if err != nil {
		return nil, nil, errors.New("cannot read admission public key")
	}
	publicBlock, _ := pem.Decode(publicData)
	if publicBlock == nil {
		return nil, nil, errors.New("invalid admission public key")
	}
	publicValue, err := x509.ParsePKIXPublicKey(publicBlock.Bytes)
	public, ok := publicValue.(*rsa.PublicKey)
	if err != nil || !ok || public.E != key.E || public.N.Cmp(key.N) != 0 {
		return nil, nil, errors.New("admission public/private key mismatch")
	}
	return encryption, key, nil
}
