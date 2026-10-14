# syntax=docker/dockerfile:1

# Production image for the ZeaVis Edu web app: a Vite SPA served by nginx.
#
# Ported from Bun to pnpm + Node. The previous version was
# `FROM oven/bun:1.3.14` and `COPY … bun.lock`, and the repo no longer has a
# bun.lock — the workspace moved to pnpm with pnpm-lock.yaml.
#
# Vite bakes its configuration into the bundle at BUILD time, so VITE_API_BASE_URL
# is a build arg and not a runtime env var. Changing the API URL therefore
# requires a rebuild, which is why the default points at a relative path and the
# nginx config rewrites asset requests — see apps/web/nginx.conf.

ARG NODE_IMAGE=node:22-slim

# ── deps ──────────────────────────────────────────────────────────────────
FROM ${NODE_IMAGE} AS deps
# pnpm is pinned by "packageManager": "pnpm@10.33.2" in the root package.json.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    COREPACK_ENABLE_STRICT=1 \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH
WORKDIR /app
RUN corepack enable

# Manifests only, so the install layer survives a source-only edit.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json ./
COPY packages/shared/package.json packages/shared/package.json
COPY apps/web/package.json apps/web/package.json
COPY apps/api/package.json apps/api/package.json
COPY apps/tauri/package.json apps/tauri/package.json
RUN pnpm install --frozen-lockfile

# ── builder ───────────────────────────────────────────────────────────────
FROM deps AS builder
COPY packages/shared packages/shared
COPY apps/web apps/web

# Vite reads this at build time and inlines it. No default is supplied on
# purpose: an empty value would bake "/api" into the bundle by accident rather
# than failing loudly, and the api URL is the one thing that differs per
# environment.
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN test -n "$VITE_API_BASE_URL" || { echo "VITE_API_BASE_URL is required (it is baked into the bundle at build time)"; exit 1; }

# The shared package is built first because the web app imports its compiled
# output; `tsc && vite build` then typechecks before bundling.
RUN pnpm --filter @zeavis/shared build
RUN pnpm --filter @zeavis/web build

# ── runner: nginx ─────────────────────────────────────────────────────────
# Alpine's nginx package is built --with-http-sub-filter, which the SPA config
# relies on for asset rewriting. Swapping this base for a hand-built nginx
# silently loses sub_filter and the app still serves, with broken assets.
FROM alpine:3.20 AS runner
RUN apk add --no-cache nginx

COPY apps/web/nginx.conf /etc/nginx/http.d/default.conf
COPY --from=builder /app/apps/web/dist /var/lib/nginx/html

# nginx's master process needs to bind :80, so it cannot be fully unprivileged
# without also rewriting its own listen directives and pid path. The content it
# serves is read-only.
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]