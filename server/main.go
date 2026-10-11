package main

import (
	"log"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/osutils"

	alcove "github.com/Paul-Carouge/Alcove/server/internal/app"
	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/healthcheck"
	_ "github.com/Paul-Carouge/Alcove/server/migrations"
)

func main() {
	// Runs without bootstrapping PocketBase (no data dir access needed).
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		cmd := healthcheck.Command()
		cmd.SetArgs(os.Args[2:])
		if err := cmd.Execute(); err != nil {
			os.Exit(1)
		}
		return
	}

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

	alcove.Wire(app, cfg)

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
