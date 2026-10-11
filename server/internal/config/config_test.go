package config

import (
	"strings"
	"testing"
)

func env(m map[string]string) func(string) (string, bool) {
	return func(k string) (string, bool) { v, ok := m[k]; return v, ok }
}

func TestDefaults(t *testing.T) {
	cfg, err := FromEnv(env(nil))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Storage != StorageLocal || cfg.PublicURL != "" || len(cfg.Modules) != 0 {
		t.Fatalf("unexpected defaults: %+v", cfg)
	}
}

func TestValid(t *testing.T) {
	cfg, err := FromEnv(env(map[string]string{
		"ALCOVE_DOMAIN":               "cloud.example.org",
		"ALCOVE_STORAGE":              "S3",
		"ALCOVE_S3_ENDPOINT":          "https://s3.example.org",
		"ALCOVE_S3_BUCKET":            "b",
		"ALCOVE_S3_ACCESS_KEY":        "k",
		"ALCOVE_S3_SECRET":            "s",
		"ALCOVE_MODULES":              " ocr, OCR ,faces",
		"ALCOVE_TRUSTED_PROXY_HEADER": "X-Forwarded-For",
	}))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.PublicURL != "https://cloud.example.org" {
		t.Errorf("PublicURL = %q", cfg.PublicURL)
	}
	if cfg.Storage != StorageS3 || cfg.S3.Bucket != "b" {
		t.Errorf("S3 not parsed: %+v", cfg)
	}
	if strings.Join(cfg.Modules, ",") != "ocr,faces" {
		t.Errorf("Modules = %v", cfg.Modules)
	}
}

func TestInvalid(t *testing.T) {
	cases := map[string]map[string]string{
		"domain with scheme": {"ALCOVE_DOMAIN": "https://x.org"},
		"unknown storage":    {"ALCOVE_STORAGE": "ftp"},
		"s3 incomplete":      {"ALCOVE_STORAGE": "s3", "ALCOVE_S3_ENDPOINT": "nope"},
		"unknown module":     {"ALCOVE_MODULES": "blockchain"},
	}
	for name, vars := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := FromEnv(env(vars)); err == nil {
				t.Fatal("expected an error")
			}
		})
	}
}
