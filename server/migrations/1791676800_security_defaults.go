package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

// Enables rate limiting with conservative defaults. Admins can tune the
// rules later in the admin UI (Settings → Rate limits).
func init() {
	m.Register(func(app core.App) error {
		s := app.Settings()
		s.RateLimits.Enabled = true
		s.RateLimits.Rules = []core.RateLimitRule{
			{Label: "*:auth", MaxRequests: 5, Duration: 60},
			{Label: "*:requestPasswordReset", MaxRequests: 3, Duration: 300},
			{Label: "*:create", MaxRequests: 30, Duration: 10},
			{Label: "/api/batch", MaxRequests: 3, Duration: 1},
			{Label: "/health", MaxRequests: 60, Duration: 60},
			{Label: "/api/", MaxRequests: 300, Duration: 10},
		}
		s.Logs.MaxDays = 14
		return app.Save(s)
	}, func(app core.App) error {
		s := app.Settings()
		s.RateLimits.Enabled = false
		return app.Save(s)
	})
}
