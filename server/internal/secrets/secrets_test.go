package secrets_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/secrets"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

func TestGeneratedKeyIsPersistedPrivately(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()

	enc, err := secrets.New(app, "").Encrypt("JBSWY3DPEHPK3PXP")
	if err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(filepath.Join(app.DataDir(), secrets.KeyFile))
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("key file missing or not 0600: %v %v", err, info)
	}
	// A new keyring (e.g. after restart) reads the same key.
	plain, err := secrets.New(app, "").Decrypt(enc)
	if err != nil || plain != "JBSWY3DPEHPK3PXP" {
		t.Fatalf("round trip failed: %q %v", plain, err)
	}
}

func TestEnvKeyTakesPrecedence(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	a := secrets.New(app, "a very long passphrase from the environment!!")
	enc, _ := a.Encrypt("x")
	if _, err := secrets.New(app, "another passphrase that is long enough....").Decrypt(enc); err == nil {
		t.Fatal("a different key must not decrypt")
	}
	if _, err := os.Stat(filepath.Join(app.DataDir(), secrets.KeyFile)); !os.IsNotExist(err) {
		t.Error("no key file should be written when the env key is set")
	}
}
