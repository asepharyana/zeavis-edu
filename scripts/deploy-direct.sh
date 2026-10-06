#!/usr/bin/env bash
#
# Direct pnpm + systemd deploy for zeavis-edu.
#
# .github/workflows/deploy.yml scps THIS file out of the checkout of the commit
# being deployed and runs it on the VPS as:
#
#     bash /tmp/zeavis-deploy-direct.sh <service> <git-sha> [ref]
#
# The script is shipped from the checkout (never read from the payload that is
# live on the VPS) so the deploy logic always matches the commit being released.
#
# Supported services:
#   api  -> /opt/zeavis-api/current   (launcher does `cd $current` then runs
#                                      `./apps/api/node_modules/.bin/tsx`)
#   web  -> /opt/zeavis-web/html      (nginx `root` in /etc/nginx/zeavis-web)
#
# zeavis-ml-service is deliberately NOT accepted below: it is a Rust/onnx binary
# whose launcher still points at a deleted /nix/store path. It cannot be built
# from this pnpm tree — see the comment in .github/workflows/deploy.yml.
#
# Flow (per service):
#   1. clone <git-sha> into $RELEASES_DIR/<git-sha>
#   2. pnpm install --frozen-lockfile   (+ `pnpm run build` for web)
#   3. atomically switch the live path to the new release, keeping .previous
#   4. restart the systemd unit
#   5. health-check with curl --retry (no sleep loops)
#   6. on failure: switch back to the previous release, restart, re-check
#   7. prune old releases (keeps $KEEP_RELEASES newest, never the live one)
#
# Overrides (defaults are the production values; used for verification runs):
#   REPO_URL RELEASES_DIR LIVE_LINK UNIT HEALTH_URL KEEP_RELEASES SKIP_RESTART=1
set -Eeuo pipefail

REPO_URL="${DEPLOY_REPO_URL:-https://github.com/asepharyana/zeavis-edu.git}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"
SKIP_RESTART="${SKIP_RESTART:-0}"

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }

SERVICE="${1:-}"
SHA="${2:-}"
REF="${3:-main}"
[ -n "$SHA" ] || die "usage: $0 <api|web> <git-sha> [ref]"

case "$SERVICE" in
  api)
    BASE_DIR="${BASE_DIR:-/opt/zeavis-api}"
    LIVE_LINK="$BASE_DIR/current"        # must stay a path the launcher can `cd` into
    ARTIFACT=""                          # the whole checkout is the artifact
    UNIT="zeavis-api"
    HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:4006/health}"
    ;;
  web)
    BASE_DIR="${BASE_DIR:-/opt/zeavis-web}"
    LIVE_LINK="$BASE_DIR/html"           # nginx `root /opt/zeavis-web/html`
    ARTIFACT="apps/web/dist"
    UNIT="zeavis-web"
    HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:4011/}"
    ;;
  *)
    die "unsupported service '$SERVICE' (only api and web are deployable)"
    ;;
esac

RELEASES_DIR="${RELEASES_DIR:-$BASE_DIR/releases}"
PREV_PATH="${LIVE_LINK}.previous"
export RELEASES_DIR LIVE_LINK

# ── privileges ─────────────────────────────────────────────────────────────
# Writes under /opt and systemctl need root when the deploy user is not root
# itself; use passwordless sudo when available, plain commands otherwise.
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif sudo -n true 2>/dev/null; then
    sudo -n "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

# ── toolchain ──────────────────────────────────────────────────────────────
resolve_pnpm() {
  if command -v pnpm >/dev/null 2>&1; then
    command -v pnpm
  elif [ -x "${HOME:-/nonexistent}/.local/bin/pnpm" ]; then
    printf '%s\n' "${HOME}/.local/bin/pnpm"
  elif command -v corepack >/dev/null 2>&1; then
    printf 'corepack pnpm'
  else
    die "pnpm not found on PATH (expected pnpm >= 10)"
  fi
}
PNPM="$(resolve_pnpm)"

command -v node  >/dev/null 2>&1 || die "node not found on PATH"
command -v git   >/dev/null 2>&1 || die "git not found on PATH"
command -v curl  >/dev/null 2>&1 || die "curl not found on PATH"
log "node $(node -v) | $($PNPM --version 2>/dev/null || echo 'pnpm ?') | user $(id -un) | service $SERVICE"

# ── state captured before we touch anything ────────────────────────────────
PREV_TARGET=""
if [ -L "$LIVE_LINK" ]; then
  PREV_TARGET="$(readlink "$LIVE_LINK")"
elif [ -e "$LIVE_LINK" ]; then
  # First deploy under this script: the live path is still a real directory
  # (the pre-pnpm payload), so the rollback target becomes $PREV_PATH.
  PREV_TARGET="$PREV_PATH"
fi
ACTIVATED=0

rollback() {
  # Deliberately defensive: never let rollback itself abort the script.
  set +e
  trap - ERR
  log "ROLLING BACK"
  if [ -n "$PREV_TARGET" ] && [ -e "$PREV_TARGET" ]; then
    log "restoring $LIVE_LINK -> $PREV_TARGET"
    tmp="${LIVE_LINK}.rollback.$$"
    as_root ln -sfn "$PREV_TARGET" "$tmp" && as_root mv -Tf "$tmp" "$LIVE_LINK"
  else
    log "no previous release to restore (nothing to roll back to)"
  fi
  if [ "$SKIP_RESTART" != "1" ]; then
    as_root systemctl restart "$UNIT"
    health_check || log "WARNING: service still unhealthy after rollback"
  fi
}

on_error() {
  local rc="$1" line="$2"
  log "step failed at line $line (exit $rc)"
  if [ "$ACTIVATED" = "1" ]; then
    rollback
  fi
  exit "$rc"
}
trap 'on_error $LINENO' ERR

health_check() {
  log "health-check $HEALTH_URL"
  curl --fail --silent --show-error \
    --retry 15 --retry-delay 2 \
    --retry-connrefused --retry-all-errors \
    --max-time 10 \
    -o /dev/null "$HEALTH_URL"
}

# ── 1. check out the release ───────────────────────────────────────────────
RELEASE_DIR="${RELEASES_DIR}/${SHA}"
if [ -d "${RELEASE_DIR}/.git" ]; then
  log "reusing existing checkout $RELEASE_DIR"
else
  if [ ! -d "$RELEASES_DIR" ]; then
    as_root mkdir -p "$RELEASES_DIR"
  fi
  if [ ! -w "$RELEASES_DIR" ]; then
    as_root chown "$(id -u):$(id -g)" "$RELEASES_DIR"
  fi
  log "cloning $SHA from $REPO_URL"
  rm -rf "$RELEASE_DIR"
  mkdir -p "$RELEASE_DIR"
  git -C "$RELEASE_DIR" init -q
  git -C "$RELEASE_DIR" remote add origin "$REPO_URL"
  if ! git -C "$RELEASE_DIR" fetch --quiet --depth 1 origin "$SHA" 2>/dev/null; then
    # Some servers refuse direct SHA fetches; fall back to the branch and walk
    # back to the commit. The depth is generous on purpose (SHAs land on main).
    log "direct SHA fetch refused; fetching $REF instead"
    git -C "$RELEASE_DIR" fetch --quiet --depth 500 origin \
      "+refs/heads/${REF}:refs/remotes/origin/${REF}" \
      || die "could not fetch $REF from $REPO_URL"
  fi
  git -C "$RELEASE_DIR" checkout --quiet --detach "$SHA" \
    || git -C "$RELEASE_DIR" checkout --quiet --detach FETCH_HEAD \
    || die "commit $SHA not found in $REPO_URL"
fi
[ -f "$RELEASE_DIR/package.json" ] || die "$RELEASE_DIR is not a checkout of zeavis-edu"
log "checked out $(git -C "$RELEASE_DIR" rev-parse --short HEAD)"

# Carry runtime env across (not tracked by git, so a fresh checkout has none).
if [ -f "${LIVE_LINK}/.env" ] && [ ! -f "${RELEASE_DIR}/.env" ]; then
  cp "${LIVE_LINK}/.env" "${RELEASE_DIR}/.env"
  log "carried .env from the live payload"
fi

# ── 2. install (+ build for web) ───────────────────────────────────────────
# NODE_ENV must NOT be production here: pnpm would then skip devDependencies
# (typescript, tsx, vite, @moonrepo/cli) and the build/start would fail.
(
  cd "$RELEASE_DIR"
  unset NODE_ENV
  log "pnpm install --frozen-lockfile"
  $PNPM install --frozen-lockfile

  if [ "$SERVICE" = "web" ]; then
    log "pnpm run build"
    $PNPM run build
  else
    # The API imports @zeavis/shared at runtime (isDiseaseSlug, createAppStatus,
    # DiagnosisStatus, getDiseaseBySlug) and that package's `exports` point at
    # packages/shared/dist, which a fresh clone does not contain.
    log "pnpm --filter @zeavis/shared build"
    $PNPM --filter @zeavis/shared build
  fi
)

if [ -n "$ARTIFACT" ]; then
  [ -f "$RELEASE_DIR/$ARTIFACT/index.html" ] \
    || die "build produced no $ARTIFACT/index.html"
else
  [ -x "$RELEASE_DIR/apps/api/node_modules/.bin/tsx" ] \
    || die "pnpm install did not produce apps/api/node_modules/.bin/tsx"
  [ -f "$RELEASE_DIR/packages/shared/dist/index.js" ] \
    || die "pnpm did not produce packages/shared/dist/index.js"
fi

# The units run as dedicated users (zeavis-api / zeavis-web); make sure the
# freshly installed tree is readable regardless of who ran the deploy.
as_root chmod -R a+rX "$RELEASE_DIR"

# ── 3. activate ────────────────────────────────────────────────────────────
log "activating $RELEASE_DIR"
NEW_LINK="${LIVE_LINK}.new.$$"
as_root ln -sfn "$RELEASE_DIR" "$NEW_LINK"
if [ -L "$LIVE_LINK" ]; then
  as_root mv -Tf "$NEW_LINK" "$LIVE_LINK"           # atomic rename(2)
elif [ -e "$LIVE_LINK" ]; then
  # real directory (first deploy) -> symlink; drop any older backup first so
  # `mv -T` never lands *inside* a leftover directory.
  if [ -e "$PREV_PATH" ]; then
    as_root rm -rf "$PREV_PATH"
  fi
  as_root mv -T "$LIVE_LINK" "$PREV_PATH"
  if ! as_root mv -Tf "$NEW_LINK" "$LIVE_LINK"; then
    as_root mv -T "$PREV_PATH" "$LIVE_LINK"
    die "could not activate $RELEASE_DIR"
  fi
else
  as_root mv -Tf "$NEW_LINK" "$LIVE_LINK"
fi
if [ -n "$ARTIFACT" ]; then
  # web: the live path points at <release>/apps/web/dist (no package.json there)
  [ -e "$LIVE_LINK/index.html" ] || die "$LIVE_LINK does not point at a built SPA"
else
  # api: the launcher `cd`s into this path, so it must be a checkout
  [ -e "$LIVE_LINK/package.json" ] || die "$LIVE_LINK does not point at a release"
fi
ACTIVATED=1

# ── 4. restart ─────────────────────────────────────────────────────────────
if [ "$SKIP_RESTART" = "1" ]; then
  log "SKIP_RESTART=1 — not restarting $UNIT"
else
  log "restarting $UNIT"
  as_root systemctl restart "$UNIT"
fi

# ── 5. health check ────────────────────────────────────────────────────────
if health_check; then
  ACTIVATED=0
  log "healthy — deploy of ${SERVICE}@${SHA:0:7} complete"
else
  # `die` below would skip the ERR trap (plain exit), so roll back explicitly.
  rollback
  die "health check failed after deploying ${SERVICE}@${SHA:0:7}"
fi

# ── 6. prune old releases ──────────────────────────────────────────────────
live_target="$(readlink "$LIVE_LINK")"
kept=0
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  [ "$dir" = "$live_target" ] && continue
  [ "$dir" = "$RELEASE_DIR" ] && continue
  [ "$dir" = "$PREV_TARGET" ] && continue
  kept=$((kept + 1))
  if [ "$kept" -gt "$KEEP_RELEASES" ]; then
    log "pruning old release $(basename "$dir")"
    as_root rm -rf "$dir"
  fi
done < <(ls -1dt "$RELEASES_DIR"/*/ 2>/dev/null || true)

log "done: $LIVE_LINK -> $live_target"
