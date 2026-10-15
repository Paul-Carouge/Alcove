# Alcove monorepo tasks. `make help` lists targets.
SHELL := /bin/bash
.DEFAULT_GOAL := help

# From the latest tag (v0.5.0 -> 0.5.0, or 0.5.0-3-gabc123 between releases).
VERSION ?= $(shell v=$$(git describe --tags --dirty 2>/dev/null) && echo $$v | sed 's/^v//' || echo 0.0.0-dev)
LDFLAGS := -s -w -X github.com/Paul-Carouge/Alcove/server/internal/buildinfo.Version=$(VERSION)
WEBUI_DIST := server/internal/webui/dist

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

## --- Setup -------------------------------------------------------------
.PHONY: setup
setup: ## Install all dependencies and git hooks
	pnpm install
	cd server && go mod download
	cd mobile && flutter pub get && flutter gen-l10n
	pre-commit install --install-hooks -t pre-commit -t commit-msg

## --- Dev ---------------------------------------------------------------
.PHONY: dev dev-server dev-web
dev: ## Run server (:8090) and web dev server (:5173) together
	@$(MAKE) -j2 dev-server dev-web

# DEV_HOST=0.0.0.0 makes the dev server reachable from a phone on the same network.
DEV_HOST ?= 127.0.0.1

dev-server: ## Run the Go server with auto-migrations (go run); DEV_HOST=0.0.0.0 for phones on the LAN
	cd server && go run -ldflags "-X github.com/Paul-Carouge/Alcove/server/internal/buildinfo.Version=$(VERSION)" . serve --http=$(DEV_HOST):8090

dev-web: ## Run the SvelteKit dev server (proxies API to :8090)
	pnpm --filter @alcove/web dev

## --- Codegen -----------------------------------------------------------
.PHONY: gen check-gen
gen: ## Regenerate API clients and design tokens
	pnpm --filter @alcove/api-spec gen
	pnpm --filter @alcove/design-tokens build

check-gen: ## Fail if generated files are out of date
	pnpm --filter @alcove/design-tokens check
	pnpm --filter @alcove/api-spec gen
	git diff --exit-code -- packages/api-spec/clients || \
	  (echo "Generated API clients are stale: run 'make gen' and commit." && exit 1)

## --- Lint --------------------------------------------------------------
.PHONY: lint lint-server lint-web lint-packages lint-mobile
lint: lint-server lint-web lint-packages lint-mobile ## Lint everything

lint-server:
	cd server && test -z "$$(gofmt -l .)" && go vet ./... && golangci-lint run ./...

lint-web:
	pnpm --filter @alcove/web check
	pnpm --filter @alcove/web lint

lint-packages:
	pnpm --filter @alcove/api-spec lint
	pnpm --filter @alcove/design-tokens check

lint-mobile:
	cd mobile && flutter gen-l10n && dart format --output=none --set-exit-if-changed lib test && flutter analyze
	cd packages/api-spec/clients/dart && dart pub get >/dev/null && dart analyze --no-fatal-warnings lib

## --- Test --------------------------------------------------------------
.PHONY: test test-server test-web test-packages test-mobile test-e2e
test: test-server test-web test-packages test-mobile ## Run all tests

test-server:
	cd server && go test -race ./...

test-web:
	pnpm --filter @alcove/web test

test-packages:
	pnpm --filter @alcove/design-tokens test

test-mobile:
	cd mobile && flutter gen-l10n && flutter test
	# Calendar dates must not depend on the device's time zone.
	cd mobile && for tz in Pacific/Honolulu Asia/Tokyo Europe/Paris America/New_York; do TZ=$$tz flutter test test/calendar_test.dart || exit 1; done

test-e2e: build ## Browser tests against the built binary (Playwright)
	pnpm --filter @alcove/web exec playwright install chromium
	pnpm --filter @alcove/web test:e2e

## --- Build -------------------------------------------------------------
.PHONY: build build-web build-server build-apk docker docker-up dist
build: build-server ## Build the server binary with the web UI embedded (server/bin/alcove)

build-web:
	pnpm --filter @alcove/web build
	find $(WEBUI_DIST) -mindepth 1 ! -name .gitkeep -delete
	cp -R web/build/. $(WEBUI_DIST)/

build-server: build-web
	cd server && CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/alcove .
	@echo "built server/bin/alcove ($(VERSION))"

dist: ## Release archives for all platforms + SHA256SUMS (signed if ALCOVE_SIGNING_KEY is set; ANDROID_APKS=1 adds the APKs)
	scripts/dist.sh $(VERSION)

build-apk: ## Release Android APKs, universal + per ABI (mobile/build/dist)
	scripts/android-dist.sh mobile/build/dist

docker: ## Build the Docker image
	docker build -f deploy/Dockerfile --build-arg VERSION=$(VERSION) -t ghcr.io/paul-carouge/alcove:dev .

docker-up: ## Start the compose stack (needs deploy/.env)
	cd deploy && docker compose up -d --build

## --- Release -----------------------------------------------------------
.PHONY: release
release: ## Cut a release: make release V=0.6.0 (needs CHANGELOG section + devlog)
	@scripts/release.sh "$(V)"

## --- Housekeeping ------------------------------------------------------
.PHONY: clean
clean: ## Remove build outputs
	rm -rf server/bin web/build mobile/build dist
	find $(WEBUI_DIST) -mindepth 1 ! -name .gitkeep -delete
