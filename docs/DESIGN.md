# Design

Alcove should feel like a quiet room: **clean, fast, calm.** Your files are the content, and the
interface stays out of the way.

The visual direction is called **Lin** (linen): warm paper background, near-black ink, a deep sage
accent, a serif for headings and a neutral sans for text, generous whitespace, soft corners and very
soft warm shadows. Think of a calm notebook or a small museum: quiet, refined, never flashy.

## Principles

1. **Content first.** Chrome is neutral and low-contrast. Color is reserved for meaning (accent = action
   and selection, danger = destructive, success = done).
2. **Fast is a feature.** Instant feedback (< 100 ms) for every interaction. Optimistic updates with
   realtime reconciliation. Skeletons instead of spinners for content.
3. **Calm.** No badges screaming for attention, no modal unless it blocks a decision, motion only to
   explain a change (where something came from or went).
4. **One system, every platform.** Web and mobile share the same tokens and component vocabulary.
   They follow platform conventions only for navigation and gestures.
5. **Accessible by default.** If it fails accessibility, it is a bug, not a nice-to-have.

## Tokens

Source of truth: [`packages/design-tokens/tokens.json`](../packages/design-tokens/tokens.json).
`pnpm tokens` generates:

| Platform | File | Usage |
|---|---|---|
| Web | `web/src/lib/styles/tokens.css` | `var(--color-text)`, `var(--space-4)`, `var(--radius-md)` … |
| Flutter | `mobile/lib/theme/tokens.g.dart` | `context.colors.text`, `AlcoveSpace.s4`, `AlcoveRadius.md` … |

Never use raw values in components. If a value is missing, add a token.

### Color (semantic roles, light / dark)

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F7F5F0` | `#161512` | App background (paper) |
| `surface` | `#FFFFFF` | `#1E1C19` | Cards, panels, inputs |
| `surfaceRaised` | `#FFFFFF` | `#26241F` | Menus, dialogs (with shadow) |
| `surfaceSunken` | `#EFEBE3` | `#11100E` | Wells, code, segmented controls |
| `border` / `borderStrong` | `#E6E1D7` / `#ADA697` | `#2F2C27` / `#5C574E` | Dividers / input outlines |
| `text` / `textMuted` | `#1F1E1B` / `#635F57` | `#EDEAE3` / `#A9A398` | Body (ink) / secondary text |
| `accent` (+`Hover`, `Subtle`, `Contrast`) | `#3F6B5A` | `#8FBFA8` | Primary actions, links, selection (deep sage) |
| `success`, `warning`, `danger` | `#2E6B45`, `#8A4A0B`, `#A9322A` | `#7FD3A0`, `#F2B35C`, `#F08A7E` | Status |
| `focus` | = accent | = accent | Focus ring |
| `overlay` | `#1F1E1B66` | `#000000A3` | Scrims behind dialogs |
| `stage*`, `onStage*` | always dark | always dark | Photo viewer |

Dark mode follows the system (`prefers-color-scheme`). The web app can force a theme with
`<html data-theme="light|dark">`. Every text/background pair is checked for WCAG AA contrast by
`pnpm --filter @alcove/design-tokens test`.

### Typography

- Families: **Fraunces** (variable, optical sizes) for headings, page titles and a few display
  details (`--font-display`), **Inter** (variable) for everything else (`--font-sans`). Self-hosted
  on web (`@fontsource-variable/fraunces`, `@fontsource-variable/inter`, imported once in the root
  layout) and bundled in the app. Never loaded from Google Fonts (the CSP forbids it). Mono:
  JetBrains Mono, falling back to system mono.
- Headings use weight 400–500 in Fraunces (it is already expressive); page titles are `3xl`
  (`2xl` on phones), dialog titles `xl`. Small uppercase labels (table headers, sidebar groups)
  stay in Inter, `xs`, tracked `0.08em`.
- Scale (px): `xs 12 · sm 14 · md 16 (body) · lg 18 · xl 22 · 2xl 28 · 3xl 36`. Web uses rem, so
  user font-size preferences apply. Flutter respects the system text scale.
- Weights: 400 regular, 500 medium (labels, buttons), 600 semibold (headings). No bold-on-bold.
- Line height: 1.5 body, 1.25 headings. Measure ≤ 70ch for reading text.

### Spacing, radius, elevation, breakpoints

- Spacing (4px grid): `0, 4, 8, 12, 16, 24, 32, 48, 64` → `space-0`…`space-8`.
- Radius: `sm 8` (small controls), `md 12` (buttons, inputs, menu items), `lg 18` (cards, lists, tiles),
  `xl 24` (dialogs, settings cards, empty states), `full` (avatars, pills, search).
- Shadows: `sm` (resting cards), `md` (popovers), `lg` (dialogs). Dark mode uses deeper, darker shadows
  plus lighter surfaces for elevation.
- Breakpoints: `sm 600`, `md 900`, `lg 1200`. Mobile-first. Drive grid columns grow with width.

### Motion

- Durations: `fast 120ms` (hover, press), `base 200ms` (enter/exit, expand), `slow 320ms` (page, large sheets).
- Easing: `standard` (0.2,0,0,1) for most, `emphasized` (0.3,0,0,1) for entering elements, `exit` (0.4,0,1,1).
- `prefers-reduced-motion`: durations become 0 (web tokens do this automatically), crossfades replace movement.
- Never animate layout in ways that move content under the pointer.

## Base components

Built once per platform with the same names, states and anatomy. States: default, hover (web),
pressed, focus-visible, disabled, loading, error.

| Component | Notes |
|---|---|
| Button | `primary` (accent fill), `secondary` (outline), `ghost`, `danger`. Min height 44px web / 48dp mobile. Loading keeps width |
| IconButton | Always has an accessible label (tooltip on web) |
| TextField | Label always visible (no placeholder-as-label), helper/error text below, error announced |
| Select / Menu | Keyboard navigable, typeahead, `Esc` closes, focus returns to trigger |
| Dialog / Sheet | Focus trap, `Esc`/back closes, title labelled. Bottom sheet (with grab handle) below 600px |
| Toast | Polite live region, auto-dismiss ≥ 5 s, pause on hover/focus, never the only place for errors |
| Card | `surface` + `border` + `shadow-sm`, radius `lg` (lists) or `xl` (settings sections) |
| Data table | `table.data-table` (base.css): a card of rows, uppercase tracked headers, row hover tint |
| ListItem / GridTile | File rows/tiles: icon or thumbnail, name, meta. Selection via checkbox, not only color |
| Breadcrumbs | Folder path, collapses the middle on narrow screens |
| EmptyState | `#lib/ui/EmptyState.svelte`: icon in a small arch (the logo's alcove), title, one sentence, at most one action |
| Skeleton | For content loading, respects reduced motion (no shimmer) |
| ProgressBar | Uploads; has text percentage for screen readers |

Icons: [Lucide](https://lucide.dev) on web (`@lucide/svelte`, always `aria-hidden` next to a text label), Material Symbols (outlined) on Flutter until a shared set is
justified. 20px default, 24px in touch toolbars.

## Layout

- **App shell (web):** 16.5rem sidebar on the paper background (logo, sections, storage, version); the
  current section is a white "sheet" lifted with `shadow-sm` and a sage icon. Sticky translucent top
  bar (global search pill, account menu) + content column capped at 80rem. Below `md` (900px) the
  sidebar becomes a drawer with a scrim.
  Upcoming sections stay visible but disabled with a "Soon" badge, so the roadmap is legible.
- **Public pages:** split layout. A brand panel (logo, serif pitch, three promises, hairline arches) on
  the left, the form in a white card on the right. Below `md` only the card remains, with the logo in
  the header.
- **Account menu:** avatar trigger → identity, theme (system/light/dark, persisted per browser), language,
  sign-out. Closes on `Esc` (focus returns to the trigger) and on outside pointer-down.

## Accessibility rules

- WCAG 2.2 level AA minimum, on both clients.
- Contrast: text ≥ 4.5:1, large text and UI components ≥ 3:1 (enforced for tokens in tests).
- Full keyboard support on web: logical tab order, visible focus (`:focus-visible` ring with the `focus`
  token, 2px), skip link, no keyboard traps, shortcuts documented and remappable later.
- Every interactive element has an accessible name. Icons are `aria-hidden` unless they are the only label.
- Dynamic results (upload done, connection status) are announced (`aria-live` / `SemanticsService`).
- Touch targets ≥ 44×44 CSS px / 48×48 dp (enforced in Flutter widget tests with `meetsGuideline`).
- Don't convey meaning with color alone. Pair it with an icon or text.
- Respect user settings: text scaling up to 200% without loss, reduced motion, dark mode, RTL-ready layout
  (logical CSS properties, `EdgeInsetsDirectional`).
- Language is set on the document (`<html lang>`) and all strings are translated (EN, FR).
