// Package buildinfo holds product identity and version data.
// Name and Version are overridable at link time, e.g.
//
//	go build -ldflags "-X github.com/Paul-Carouge/Alcove/server/internal/buildinfo.Version=1.2.3"
package buildinfo

// Name is the product name shown to users. Rename the project here (and in
// the client config files listed in CLAUDE.md), not in individual handlers.
var Name = "Alcove"

// Version is the server's SemVer, injected by the build.
var Version = "0.0.0-dev"

// API version range served by this build. Raise APIMax when adding a new
// /api/v{N}; raise APIMin only when dropping an old one (see ARCHITECTURE.md).
const (
	APIMin = 1
	APIMax = 1
)

// Release channel used by the updater (ADR 0015).
const (
	// Repo hosts the releases ("owner/name" on GitHub).
	Repo = "Paul-Carouge/Alcove"
	// ReleasesAPI is the GitHub API base; ALCOVE_UPDATE_URL overrides it (mirrors, tests).
	ReleasesAPI = "https://api.github.com"
	// ReleasePublicKey verifies the Ed25519 signature of each release's SHA256SUMS.
	ReleasePublicKey = "8Zq0Y000dsFVDUjanc3Tf/pub4U3RfwuBaYeUDeaDEA="
)
