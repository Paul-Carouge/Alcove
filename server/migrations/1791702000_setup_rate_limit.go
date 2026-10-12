package migrations

import (
	"slices"

	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

const setupRateLimitLabel = "/api/v1/setup"

// Limits guessing of the first-run setup token.
func init() {
	m.Register(func(app core.App) error {
		s := app.Settings()
		s.RateLimits.Rules = append([]core.RateLimitRule{
			{Label: setupRateLimitLabel, MaxRequests: 10, Duration: 60},
		}, s.RateLimits.Rules...)
		return app.Save(s)
	}, func(app core.App) error {
		s := app.Settings()
		s.RateLimits.Rules = slices.DeleteFunc(s.RateLimits.Rules, func(r core.RateLimitRule) bool {
			return r.Label == setupRateLimitLabel
		})
		return app.Save(s)
	})
}
