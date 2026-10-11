# @alcove/design-tokens

`tokens.json` defines colors (light/dark), typography, spacing, radii, shadows, motion and breakpoints.
`pnpm build` writes:

- `web/src/lib/styles/tokens.css`: CSS custom properties (`--color-*`, `--space-*`, …), dark mode via
  `prefers-color-scheme` or `data-theme`, durations zeroed under `prefers-reduced-motion`.
- `mobile/lib/theme/tokens.g.dart`: `AlcoveColors` (a `ThemeExtension`), `AlcoveSpace`, `AlcoveRadius`, …

`pnpm test` checks WCAG AA contrast for every text/background pair; `pnpm check` fails if generated files are stale.
See [docs/DESIGN.md](../../docs/DESIGN.md) for how to use them.
