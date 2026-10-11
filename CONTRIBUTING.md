# Contributing to Alcove

Thanks for your interest! Alcove is early-stage, so the most useful contributions right now are
feedback on the architecture, bug reports and small focused PRs.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Security issues: **don't open
an issue**, follow [docs/SECURITY.md](docs/SECURITY.md).

## Setup

Requirements: Go 1.27+, Node 22+ with pnpm (`corepack enable`), Flutter stable, Docker (for the Dart
client generation and the compose stack), [pre-commit](https://pre-commit.com), golangci-lint v2.

```sh
git clone https://github.com/Paul-Carouge/Alcove.git && cd Alcove
make setup     # dependencies + git hooks
make dev       # server :8090 + web :5173 → open http://localhost:5173
```

On the first `make dev`, open the setup link printed in the terminal to create the local admin account.
Mobile: `cd mobile && flutter run`. Debug builds accept `http://10.0.2.2:8090` (Android emulator).

## Workflow

1. For anything bigger than a bug fix, **open an issue first** to agree on the approach. Architecture
   changes need an ADR in `docs/adr/`.
2. Branch from `main`: `feat/drive-upload`, `fix/health-cache`.
3. Keep commits small and focused, using [Conventional Commits](https://www.conventionalcommits.org):
   `feat(server): add upload route`, `fix(mobile): trim server URL`. Allowed scopes: server, web, mobile,
   desktop, api-spec, design-tokens, deploy, docs, ci, deps, release. A commit-msg hook checks this.
4. API changes: edit `packages/api-spec/openapi.yaml` **first**, run `make gen`, then implement and test.
5. Before pushing: `make lint test`. CI runs the same checks per package.
6. Open a PR describing **what** and **why**, with screenshots for UI changes (light + dark) and notes
   on accessibility for new components.

## Standards

- Tests for new behavior (Go `ApiScenario` for routes, Vitest for web logic, `flutter_test` for widgets).
- No hard-coded colors, sizes or strings in UI code: use tokens and i18n (EN and FR).
- Accessibility (WCAG 2.2 AA) is part of "done" (see [docs/DESIGN.md](docs/DESIGN.md)).
- Don't edit generated files. Regenerate them instead.
- Database changes are new migrations with `up` and `down`.

## License

Alcove is licensed under [AGPL-3.0-only](LICENSE). By contributing, you agree that your contributions are
licensed under the same terms. Add a `Signed-off-by` line (`git commit -s`) to certify the
[Developer Certificate of Origin](https://developercertificate.org).
