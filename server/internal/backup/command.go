package backup

import (
	"fmt"

	"github.com/pocketbase/pocketbase/core"
	"github.com/spf13/cobra"
)

// Command is "alcove backup": an online copy of the database (use --dir to
// point at the data directory of an installed server).
func Command(app core.App) *cobra.Command {
	var label string
	cmd := &cobra.Command{
		Use:   "backup",
		Short: "Back up the database (consistent online copy, keeps the last 5)",
		RunE: func(*cobra.Command, []string) error {
			path, err := Database(app, label)
			if err != nil {
				return err
			}
			fmt.Println(path)
			return nil
		},
	}
	cmd.Flags().StringVar(&label, "label", "manual", "label added to the file name")
	return cmd
}
