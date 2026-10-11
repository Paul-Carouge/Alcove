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
