package main

import (
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/osutils"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/health"
	"github.com/Paul-Carouge/Alcove/server/internal/security"
	"github.com/Paul-Carouge/Alcove/server/internal/setup"
	"github.com/Paul-Carouge/Alcove/server/internal/webui"
	_ "github.com/Paul-Carouge/Alcove/server/migrations"
)

func main() {
	cfg := config.MustFromOSEnv()

	app := pocketbase.New()
	app.RootCmd.Use = "alcove"
	app.RootCmd.Short = buildinfo.Name + " server"
	app.RootCmd.Version = buildinfo.Version

	// Migrations are Go files in ./migrations, compiled into the binary and
	// applied on start. In `go run` mode, schema edits made in the admin UI
	// generate new migration files automatically.
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		TemplateLang: migratecmd.TemplateLangGo,
		Automigrate:  osutils.IsProbablyGoRun(),
		Dir:          "migrations",
	})

	setup.Register(app, cfg)
	security.RegisterHeaders(app)
	// No optional module is implemented yet; requested ones are ignored.
	health.Register(app, nil)
	webui.Register(app)

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
