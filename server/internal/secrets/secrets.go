// Package secrets provides the server key used to encrypt sensitive fields
// at rest (e.g. TOTP secrets).
package secrets

import (
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/security"
)

// KeyFile holds the generated key when ALCOVE_SECRET_KEY is not set.
const KeyFile = "secret.key"

// MinEnvKeyLen is the minimum length accepted for ALCOVE_SECRET_KEY.
const MinEnvKeyLen = 32

// Keyring returns the 32-byte AES key (as PocketBase's Encrypt expects).
type Keyring struct {
	once sync.Once
	key  string
	err  error
	app  core.App
	env  string
}

// New uses envKey if set (from ALCOVE_SECRET_KEY), otherwise a random key
// generated once in <data dir>/secret.key with 0600 permissions.
func New(app core.App, envKey string) *Keyring {
	return &Keyring{app: app, env: envKey}
}

func (k *Keyring) Key() (string, error) {
	k.once.Do(func() {
		if k.env != "" {
			k.key = derive(k.env)
			return
		}
		k.key, k.err = loadOrCreate(filepath.Join(k.app.DataDir(), KeyFile))
	})
	return k.key, k.err
}

// derive maps any passphrase to 32 printable bytes.
func derive(s string) string {
	sum := sha256.Sum256([]byte(s))
	return base64.RawURLEncoding.EncodeToString(sum[:])[:32]
}

func loadOrCreate(path string) (string, error) {
	b, err := os.ReadFile(path) // #nosec G304 -- fixed name inside the data dir
	if err == nil {
		key := strings.TrimSpace(string(b))
		if len(key) != 32 {
			return "", fmt.Errorf("%s is corrupted (expected 32 characters)", path)
		}
		return key, nil
	}
	if !errors.Is(err, os.ErrNotExist) {
		return "", err
	}
	key := security.RandomString(32)
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600) // #nosec G304 -- fixed name inside the data dir
	if err != nil {
		return "", err
	}
	defer func() { _ = f.Close() }()
	if _, err := f.WriteString(key + "\n"); err != nil {
		return "", err
	}
	return key, nil
}

// Encrypt and Decrypt wrap PocketBase's AES-GCM helpers with the keyring key.
func (k *Keyring) Encrypt(plain string) (string, error) {
	key, err := k.Key()
	if err != nil {
		return "", err
	}
	return security.Encrypt([]byte(plain), key)
}

func (k *Keyring) Decrypt(cipher string) (string, error) {
	key, err := k.Key()
	if err != nil {
		return "", err
	}
	b, err := security.Decrypt(cipher, key)
	return string(b), err
}
