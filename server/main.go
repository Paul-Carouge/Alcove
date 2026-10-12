package main

import (
	"log"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/osutils"

	alcove "github.com/Paul-Carouge/Alcove/server/internal/app"
	"github.com/Paul-Carouge/Alcove/server/internal/backup"
	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/cli"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/envfile"
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

	// install, update, rollback, status, uninstall: no PocketBase bootstrap.
	if cli.Handles(os.Args) {
		os.Exit(cli.Run(os.Args))
	}

	// Services pass their configuration file with --env-file.
	if path, rest := envfile.Take(os.Args); path != "" {
		if err := envfile.Load(path); err != nil {
			log.Fatalf("load %s: %v", path, err) // #nosec G706 -- path given by the administrator on the command line
		}
		os.Args = rest
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

	app.RootCmd.AddCommand(backup.Command(app))
	app.RootCmd.AddCommand(cli.HelpStubs()...)
	alcove.Wire(app, cfg)

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
