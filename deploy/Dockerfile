# syntax=docker/dockerfile:1
# Build from the repository root:  docker build -f deploy/Dockerfile .

# --- 1. Web UI (static SvelteKit build) ---
# Build stages run on the build machine's architecture and cross-compile:
# multi-arch images without emulation (pure-Go SQLite, CGO disabled).
FROM --platform=$BUILDPLATFORM node:24-alpine AS web
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
FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS server
ARG VERSION=0.0.0-dev
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src/server
COPY server/go.mod server/go.sum ./
RUN go mod download
COPY server ./
COPY --from=web /src/web/build ./internal/webui/dist
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath \
      -ldflags "-s -w -X github.com/Paul-Carouge/Alcove/server/internal/buildinfo.Version=${VERSION}" \
      -o /out/alcove . \
 && mkdir -p /out/data

# --- 3. Runtime: small Alpine with ffmpeg (ADR 0016), non-root ---
FROM alpine:3.24
RUN apk add --no-cache ffmpeg ca-certificates tzdata \
 && addgroup -S -g 65532 nonroot && adduser -S -D -H -u 65532 -G nonroot nonroot
COPY --from=server /out/alcove /alcove
COPY --from=server --chown=nonroot:nonroot /out/data /data
USER nonroot
# alcove update / the System page know this is a Docker installation.
ENV ALCOVE_INSTALL_MODE=docker
EXPOSE 8090
VOLUME /data
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD ["/alcove", "healthcheck"]
ENTRYPOINT ["/alcove"]
CMD ["serve", "--http=0.0.0.0:8090", "--dir=/data/pb_data"]
