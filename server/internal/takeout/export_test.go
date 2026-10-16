package takeout

import "github.com/pocketbase/pocketbase/core"

// Routes mounts the HTTP routes of r without starting it (tests).
func Routes(r *Runner, se *core.ServeEvent) { r.routes(se) }
