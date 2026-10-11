// Package healthcheck adds `alcove healthcheck`, used by the container
// HEALTHCHECK (the distroless image has no curl/wget).
package healthcheck

import (
	"fmt"
	"net/http"
	"time"

	"github.com/spf13/cobra"

	"github.com/Paul-Carouge/Alcove/server/internal/health"
)

func Command() *cobra.Command {
	addr := "http://127.0.0.1:8090"
	cmd := &cobra.Command{
		Use:          "healthcheck",
		Short:        "Exit 0 if the local server answers GET " + health.Path,
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			client := &http.Client{Timeout: 3 * time.Second}
			res, err := client.Get(addr + health.Path)
			if err != nil {
				return err
			}
			defer func() { _ = res.Body.Close() }()
			if res.StatusCode != http.StatusOK {
				return fmt.Errorf("unhealthy: HTTP %d", res.StatusCode)
			}
			return nil
		},
	}
	cmd.Flags().StringVar(&addr, "addr", addr, "base URL of the server")
	return cmd
}
