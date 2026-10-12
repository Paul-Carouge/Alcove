// Package config reads and validates the ALCOVE_* environment variables.
package config

import (
	"errors"
	"fmt"
	"net/url"
	"os"
	"slices"
	"strings"
)

// EnvPrefix is the prefix of every environment variable the server reads.
const EnvPrefix = "ALCOVE_"

type Storage string

const (
	StorageLocal Storage = "local"
	StorageS3    Storage = "s3"
)

// KnownModules lists every module name accepted in ALCOVE_MODULES.
var KnownModules = []string{"drive", "photos", "documents", "ocr", "faces", "notes", "calendar", "contacts"}

type S3 struct {
	Endpoint       string
	Region         string
	Bucket         string
	AccessKey      string
	Secret         string
	ForcePathStyle bool
}

type Config struct {
	// PublicURL is the externally visible base URL (https://<domain>), or "" if unknown.
	PublicURL string
	Storage   Storage
	S3        S3
	// Modules are the optional modules requested by the admin (validated names).
	Modules []string
	// SetupToken presets the first-run wizard token (automated deployments).
	SetupToken string
	// SecretKey encrypts sensitive fields at rest (TOTP secrets). Empty: a key
	// is generated in the data directory.
	SecretKey string
	// TrustedProxyHeaders are client-IP headers set by the reverse proxy
	// (e.g. X-Forwarded-For). Only set when the server is not reachable directly.
	TrustedProxyHeaders []string
}

// FromEnv loads the configuration using lookup (os.LookupEnv in production).
func FromEnv(lookup func(string) (string, bool)) (Config, error) {
	get := func(key string) string {
		v, _ := lookup(EnvPrefix + key)
		return strings.TrimSpace(v)
	}
	var errs []error
	cfg := Config{Storage: StorageLocal}

	if domain := get("DOMAIN"); domain != "" {
		if strings.ContainsAny(domain, "/: ") {
			errs = append(errs, fmt.Errorf("%sDOMAIN must be a bare hostname, got %q", EnvPrefix, domain))
		} else {
			cfg.PublicURL = "https://" + domain
		}
	}

	switch s := Storage(strings.ToLower(get("STORAGE"))); s {
	case "", StorageLocal:
	case StorageS3:
		cfg.Storage = StorageS3
		cfg.S3 = S3{
			Endpoint:       get("S3_ENDPOINT"),
			Region:         get("S3_REGION"),
			Bucket:         get("S3_BUCKET"),
			AccessKey:      get("S3_ACCESS_KEY"),
			Secret:         get("S3_SECRET"),
			ForcePathStyle: get("S3_FORCE_PATH_STYLE") == "true",
		}
		if u, err := url.Parse(cfg.S3.Endpoint); err != nil || u.Scheme == "" || u.Host == "" {
			errs = append(errs, fmt.Errorf("%sS3_ENDPOINT must be an absolute URL", EnvPrefix))
		}
		for k, v := range map[string]string{"S3_BUCKET": cfg.S3.Bucket, "S3_ACCESS_KEY": cfg.S3.AccessKey, "S3_SECRET": cfg.S3.Secret} {
			if v == "" {
				errs = append(errs, fmt.Errorf("%s%s is required when %sSTORAGE=s3", EnvPrefix, k, EnvPrefix))
			}
		}
	default:
		errs = append(errs, fmt.Errorf("%sSTORAGE must be %q or %q, got %q", EnvPrefix, StorageLocal, StorageS3, s))
	}

	for m := range strings.SplitSeq(get("MODULES"), ",") {
		m = strings.ToLower(strings.TrimSpace(m))
		if m == "" {
			continue
		}
		if !slices.Contains(KnownModules, m) {
			errs = append(errs, fmt.Errorf("unknown module %q in %sMODULES", m, EnvPrefix))
			continue
		}
		if !slices.Contains(cfg.Modules, m) {
			cfg.Modules = append(cfg.Modules, m)
		}
	}

	if t := get("SETUP_TOKEN"); t != "" {
		if len(t) < 16 {
			errs = append(errs, fmt.Errorf("%sSETUP_TOKEN must be at least 16 characters", EnvPrefix))
		} else {
			cfg.SetupToken = t
		}
	}

	if k := get("SECRET_KEY"); k != "" {
		if len(k) < 32 {
			errs = append(errs, fmt.Errorf("%sSECRET_KEY must be at least 32 characters", EnvPrefix))
		} else {
			cfg.SecretKey = k
		}
	}

	if h := get("TRUSTED_PROXY_HEADER"); h != "" {
		cfg.TrustedProxyHeaders = []string{h}
	}

	return cfg, errors.Join(errs...)
}

// MustFromOSEnv is FromEnv(os.LookupEnv); it exits on invalid configuration.
func MustFromOSEnv() Config {
	cfg, err := FromEnv(os.LookupEnv)
	if err != nil {
		fmt.Fprintln(os.Stderr, "invalid configuration:\n"+err.Error())
		os.Exit(2)
	}
	return cfg
}
