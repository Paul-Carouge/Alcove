// Command sign signs release checksums with the Ed25519 release key (CI only).
//
//	ALCOVE_SIGNING_KEY=<base64 private key> go run ./tools/sign dist/SHA256SUMS
//	go run ./tools/sign -keygen   # prints a new key pair
package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"os"
)

func main() {
	if len(os.Args) == 2 && os.Args[1] == "-keygen" {
		pub, priv, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			fail(err)
		}
		fmt.Println("public: ", base64.StdEncoding.EncodeToString(pub))
		fmt.Println("private:", base64.StdEncoding.EncodeToString(priv))
		return
	}
	if len(os.Args) != 2 {
		fail(fmt.Errorf("usage: sign <file> (key in ALCOVE_SIGNING_KEY) | sign -keygen"))
	}
	key, err := base64.StdEncoding.DecodeString(os.Getenv("ALCOVE_SIGNING_KEY"))
	if err != nil || len(key) != ed25519.PrivateKeySize {
		fail(fmt.Errorf("ALCOVE_SIGNING_KEY must be a base64 Ed25519 private key"))
	}
	data, err := os.ReadFile(os.Args[1]) // #nosec G703 -- CI tool, path given by the maintainer
	if err != nil {
		fail(err)
	}
	sig := base64.StdEncoding.EncodeToString(ed25519.Sign(key, data))
	if err := os.WriteFile(os.Args[1]+".sig", []byte(sig+"\n"), 0o644); err != nil { // #nosec G306 G703 -- public signature, maintainer-given path
		fail(err)
	}
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "sign:", err)
	os.Exit(1)
}
