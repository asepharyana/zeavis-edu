# syntax=docker/dockerfile:1

# Production image for the ZeaVis Edu API.
#
# Ported from Bun to pnpm + Node. The previous version was
# `FROM oven/bun:1.3.14` and `COPY … bun.lock`, and the repo no longer has a
# bun.lock — the workspace moved to pnpm with pnpm-lock.yaml. A Dockerfile naming
# a file the checkout does not contain fails at the first COPY with
# "failed to calculate checksum of ref …: \"/bun.lock\": not found", which names
# the path but never says the repo moved off Bun.
#
# The API runs TypeScript directly through tsx (apps/api/package.json start), so
# there is no compile step for this service and no dist/ to copy.

ARG NODE_IMAGE=node:22-slim

# ── deps: install the whole workspace so @zeavis/* resolves ───────────────
FROM ${NODE_IMAGE} AS deps
# pnpm is pinned by "packageManager": "pnpm@10.33.2" in the root package.json.
# COREPACK_ENABLE_DOWNLOAD_PROMPT=0 keeps `corepack enable` non-interactive on a
# runner with no TTY.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    COREPACK_ENABLE_STRICT=1 \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH
WORKDIR /app
RUN corepack enable

# Only manifests are copied first, so the install layer is cached until a
# dependency actually changes rather than on every source edit.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/web/package.json apps/web/package.json
COPY apps/tauri/package.json apps/tauri/package.json
COPY packages/shared/package.json packages/shared/package.json
# esbuild and sharp run install scripts; pnpm blocks them unless the workspace
# opts in via onlyBuiltDependencies, and tsx needs the esbuild binary at runtime.
RUN pnpm install --frozen-lockfile

# ── builder: compile the shared package the api imports ───────────────────
FROM deps AS builder
COPY packages/shared packages/shared
RUN pnpm --filter @zeavis/shared build

# ── prod-deps: production dependency tree, in its OWN stage ──────────────
# It cannot be the runner itself. `COPY --from` reads a named stage's tree, so
# installing here and copying from `deps` instead copies a DIFFERENT install —
# one without this stage's flags. That mismatch is invisible at build time and
# produces a tree of dangling symlinks, which only fail at the first import:
#   /app/node_modules/tsx -> ../../../node_modules/.pnpm/tsx@4.23.15/node_modules/tsx
#   ERR_MODULE_NOT_FOUND: Cannot find package 'tsx'
FROM ${NODE_IMAGE} AS prod-deps
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    NODE_ENV=production
WORKDIR /app
RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json      apps/api/package.json
COPY apps/web/package.json      apps/web/package.json
COPY apps/tauri/package.json    apps/tauri/package.json
COPY packages/shared/package.json packages/shared/package.json

# Prod-only: keeps typescript, vitest and the vite toolchain out of the runtime
# image. tsx is a runtime dependency of this service, so it survives this.
#
# `--config.node-linker=hoisted` is REQUIRED and not a preference: pnpm's
# default linker fills node_modules with symlinks into
# <root>/node_modules/.pnpm. Copying the package directory without the store
# leaves every link dangling, and the resulting error names a package that is
# demonstrably present in the manifest and visibly present in the image.
RUN pnpm install --frozen-lockfile --prod --config.node-linker=hoisted \
    --filter @zeavis/api...

# ── runner ────────────────────────────────────────────────────────────────
FROM ${NODE_IMAGE} AS runner
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    NODE_ENV=production
WORKDIR /app

# BOTH trees are required, and which one holds what is not obvious.
#
# `--config.node-linker=hoisted` hoists third-party packages to the WORKSPACE
# ROOT (/app/node_modules — 125 entries, tsx among them). But workspace members
# such as @zeavis/shared stay LINKED into the package's own directory
# (/app/apps/api/node_modules holds exactly one entry: @zeavis). Copying only the
# root drops that link and the app fails on its first route import:
#   Error [ERR_MODULE_NOT_FOUND]: Cannot find package '@zeavis/shared'
#   imported from /app/apps/api/src/routes/status.ts
#
# packages/shared itself is copied separately from the builder stage, so the link
# has a real directory to point at — copying the link alone would just dangle.
COPY --from=prod-deps /app/node_modules          ./node_modules
COPY --from=prod-deps /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=prod-deps /app/pnpm-lock.yaml          ./pnpm-lock.yaml
COPY --from=builder   /app/packages/shared         ./packages/shared
COPY package.json pnpm-workspace.yaml tsconfig.base.json ./
COPY apps/api     apps/api

# Drop privileges: nothing here needs to write to the image.
RUN useradd --system --uid 10001 --create-home --shell /usr/sbin/nologin zeavis
USER 10001

ENV API_PORT=4006
EXPOSE 4006

# Fixed port, not ${API_PORT}: exec form passes the string through verbatim and
# no shell expands it. This is also the port EXPOSE advertises and the one
# HEALTHCHECK probes, so all three agree by construction.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:4006/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Run tsx DIRECTLY, not `pnpm --filter @zeavis/api start`.
#
# That script is `tsx --env-file=../../.env src/index.ts`, and the mandatory
# --env-file makes the process exit 9 with `node: ../../.env: not found` when
# the file is absent. That is correct for a systemd unit with an EnvironmentFile
# and wrong for a container, where the variables arrive as real environment
# variables instead. Passing them at `docker run` is the container-native
# equivalent, so the script's file-based loading is bypassed deliberately.
CMD ["node", "--import", "tsx", "apps/api/src/index.ts"]