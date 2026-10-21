# 0031. Web: bits-ui for interactive primitives, styled with our tokens

- Status: Accepted (2026-10-21). Amends [0002](0002-web-sveltekit-static.md) (styling stays plain CSS).

## Context

The web client's interactive widgets (`Select`, `ActionsMenu`, `UserMenu`) were hand-written. Each one
re-implemented the WAI-ARIA keyboard model, focus management, outside-click handling, typeahead and viewport
positioning, about 250 lines for `Select` alone. Every new popup (popover, combobox, tooltip) would have
added another copy of this delicate code, and the existing ones missed edge cases (collision with the
viewport edges, focus return in every closing path, scroll and resize while open).

Tailwind and shadcn-svelte were considered. Tailwind would move the CSS into class lists rather than remove
it, and shadcn's default look contradicts the product's own art direction (`docs/DESIGN.md`), so every
component would be restyled anyway, on top of five new build dependencies.

## Decision

- Use **[bits-ui](https://bits-ui.com)** (headless Svelte 5 components, MIT) for interactive primitives
  whose accessibility is hard to get right: select, dropdown menu, popover, and later combobox and tooltip.
- bits-ui is only ever used **inside `#lib/ui/*` wrappers**. Pages keep importing `Select`, `ActionsMenu`,
  `UserMenu` with unchanged props, so the library can be replaced without touching the pages.
- Styling stays **plain scoped CSS with design tokens**. No Tailwind, no bits-ui styles (it ships none).
- `Dialog` keeps the native `<dialog>` element: the browser already provides the top layer, focus trap, Esc
  and an inert background, with no JavaScript to maintain.
- Floating content is portalled to `<body>`, or to the enclosing `<dialog>` when the trigger is inside one
  (a modal dialog is in the top layer and makes the rest of the page inert). It is positioned by Floating UI
  through inline styles, which our CSP allows (`style-src 'self' 'unsafe-inline'`).
- `Select` completes the WAI-ARIA select-only combobox pattern where bits-ui leaves gaps: the trigger keeps
  `role="combobox"` and `aria-controls`, Tab commits the highlighted option, Home/End open the closed list,
  and the list uses `strategy="fixed"` so it floats over a dialog instead of overflowing it.

## Consequences

- One runtime dependency (bits-ui 2.19, MIT) with small transitive ones (`@floating-ui/*`, `runed`,
  `svelte-toolbelt`, `tabbable`, `esm-env`, `style-to-object`) and the `@internationalized/date` peer, used
  only by date components we do not import. All of it is bundled into the static build: nothing changes
  for `alcove install`, the Docker image or `alcove update`.
- Keyboard and screen-reader behaviour follows the bits-ui implementation of the WAI-ARIA patterns; the
  Playwright tests (`pick()`, menu keyboard navigation, axe audits) guard against regressions.
- Upgrades are deliberate, through Renovate like every other dependency.
