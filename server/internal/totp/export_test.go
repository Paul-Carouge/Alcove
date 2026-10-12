package totp

import "time"

// SetClock fixes the time seen by the package; it returns a restore func.
func SetClock(t time.Time) func() {
	prev := clock
	clock = func() time.Time { return t }
	return func() { clock = prev }
}
