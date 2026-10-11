# syntax=docker/dockerfile:1
# Build from the repository root:  docker build -f deploy/Dockerfile .

# --- 1. Web UI (static SvelteKit build) ---
FROM node:24-alpine AS web
WORKDIR /src
RUN corepack enable
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/api-spec/package.json packages/api-spec/
COPY packages/design-tokens/package.json packages/design-tokens/
COPY web/package.json web/
RUN pnpm install --frozen-lockfile --filter @alcove/web...
COPY packages/api-spec packages/api-spec
COPY web web
RUN pnpm --filter @alcove/web build

# --- 2. Server binary with the web UI embedded ---
FROM golang:1.27-alpine AS server
ARG VERSION=0.0.0-dev
WORKDIR /src/server
COPY server/go.mod server/go.sum ./
RUN go mod download
COPY server ./
COPY --from=web /src/web/build ./internal/webui/dist
RUN CGO_ENABLED=0 go build -trimpath \
      -ldflags "-s -w -X github.com/Paul-Carouge/Alcove/server/internal/buildinfo.Version=${VERSION}" \
      -o /out/alcove . \
 && mkdir -p /out/data

# --- 3. Minimal runtime: no shell, non-root ---
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=server /out/alcove /alcove
COPY --from=server --chown=nonroot:nonroot /out/data /data
USER nonroot
EXPOSE 8090
VOLUME /data
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD ["/alcove", "healthcheck"]
ENTRYPOINT ["/alcove"]
CMD ["serve", "--http=0.0.0.0:8090", "--dir=/data/pb_data"]
