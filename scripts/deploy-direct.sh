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
#   ml   -> /opt/zeavis-ml-service/current (systemd unit zeavis-ml-service).
#           The Rust binary is COMPILED BY CI and shipped as an artifact, so a
#           release holds the payload (binary + model.onnx) and not a 650MB
#           cargo target/. The launcher ships from scripts/ml-launcher.sh and
#           execs the binary copied into /opt/zeavis-ml-service/bin, with
#           MODEL_PATH pointing at the model's copy beside it.
#
# Flow (per service):
#   1. clone <git-sha> into $RELEASES_DIR/<git-sha>   (skipped for ml in
#      artifact mode, where CI supplies the payload)
#   2. pnpm install --frozen-lockfile   (+ `pnpm run build` for web)
#   3. atomically switch the live path to the new release, keeping .previous
#   4. restart the systemd unit
#   5. health-check with curl --retry (no sleep loops)
#   6. on failure: switch back to the previous release, restart, re-check
#   7. prune old releases (live + $KEEP_RELEASES-1 others, pruned only after a
#      successful health check)
#
# Overrides (defaults are the production values; used for verification runs):
#   REPO_URL RELEASES_DIR LIVE_LINK UNIT HEALTH_URL KEEP_RELEASES SKIP_RESTART=1
#   ARTIFACT_DIR BASE_DIR  — ARTIFACT_DIR is where CI left the built binary for
#                            ml; when it holds a payload, ml skips the checkout
#                            and the build.
set -Eeuo pipefail

REPO_URL="${DEPLOY_REPO_URL:-https://github.com/asepharyana/zeavis-edu.git}"
SKIP_RESTART="${SKIP_RESTART:-0}"

# KEEP_RELEASES is a TOTAL, live release included, so the default of 2 leaves
# the live release and exactly one to roll back to. Counting only the old ones
# kept live plus N, which is how this used to leave one extra release per deploy.
KEEP_RELEASES="${KEEP_RELEASES:-2}"

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }

SERVICE="${1:-}"
SHA="${2:-}"
REF="${3:-main}"
[ -n "$SHA" ] || die "usage: $0 <api|web|ml> <git-sha> [ref]"

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
  ml)
    BASE_DIR="${BASE_DIR:-/opt/zeavis-ml-service}"
    LIVE_LINK="$BASE_DIR/current"
    ARTIFACT=""                          # whole checkout is the payload
    UNIT="zeavis-ml-service"
    HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:4012/health}"
    # ml's payload is not a directory inside the release but two files, so
    # ARTIFACT stays empty and the release dir IS the payload root.
    ARTIFACT_DIR="${ARTIFACT_DIR:-}"
    ;;
  *)
    die "unsupported service '$SERVICE' (only api, web, and ml are deployable)"
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

# ml deploys are COMPILED BY CI and shipped as an artifact, so a release holds
# the payload — the binary and model.onnx — instead of a 650MB cargo target/.
# /opt/zeavis-ml-service carried 707M per release for a 30M binary: 647M was
# apps/ml-service/target, and 619M of THAT was deps/ (rlib/rmeta the runtime
# never loads). Only the host-build fallback below needs cargo.
#
# The runner artifact is safe on this host: the production box is Ubuntu 26.04
# (glibc 2.43) and ubuntu-latest is 24.04 (glibc 2.39), and glibc is backward
# compatible, so a binary built on 2.39 runs on 2.43. CI runs `ldd` on the
# binary so a mismatch fails there rather than as an execve error after the flip.
resolve_cargo() {
  if command -v cargo >/dev/null 2>&1; then
    command -v cargo
  elif [ -x "${HOME:-nonexistent}/.cargo/bin/cargo" ]; then
    printf '%s\n' "${HOME}/.cargo/bin/cargo"
  elif [ -x /root/.cargo/bin/cargo ]; then
    printf '%s\n' /root/.cargo/bin/cargo
  else
    printf '%s\n' ""
  fi
}
if [ "$SERVICE" = "ml" ]; then
  CARGO="$(resolve_cargo)"
  if [ -n "$ARTIFACT_DIR" ]; then
    log "ml: artifact mode (cargo: ${CARGO:-not needed})"
  elif [ -z "$CARGO" ]; then
    die "no CI artifact and no cargo — cannot build ml-service. Set ARTIFACT_DIR or install cargo."
  else
    log "cargo: $("$CARGO" --version 2>/dev/null || echo 'cargo?')"
  fi
fi

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
  # In artifact mode the launcher execs the binary copied into $BASE_DIR/bin, so
  # flipping the symlink back is not enough — the copied binary must be restored
  # too, or the service keeps running the payload that just failed. Restoring is
  # skipped when the previous release predates the artifact switch and so has no
  # binary at its root: the launcher's fallback then execs that release's own
  # cargo target/ path, which is exactly the old behaviour.
  if [ "$SERVICE" = "ml" ] && [ "$ML_PAYLOAD_ONLY" = "1" ] \
     && [ -n "$PREV_TARGET" ] && [ -x "${PREV_TARGET}/zeavis-ml-service" ]; then
    log "restoring previous ml payload from $PREV_TARGET"
    as_root mkdir -p "$BASE_DIR/bin"
    as_root cp -f "${PREV_TARGET}/zeavis-ml-service" "$BASE_DIR/bin/zeavis-ml-service.bin"
    as_root chmod 0555 "$BASE_DIR/bin/zeavis-ml-service.bin"
    [ -f "${PREV_TARGET}/model.onnx" ] \
      && as_root cp -f "${PREV_TARGET}/model.onnx" "$BASE_DIR/bin/model.onnx"
  fi
  if [ "$SERVICE" = "ml" ] && [ -f "$BASE_DIR/bin/zeavis-ml-service.pre" ]; then
    log "restoring previous launcher"
    as_root cp -af "$BASE_DIR/bin/zeavis-ml-service.pre" "$BASE_DIR/bin/zeavis-ml-service"
    as_root rm -f "$BASE_DIR/bin/zeavis-ml-service.pre"
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

# ml in artifact mode gets its release as two files (binary + model), so there
# is no checkout at all. ML_PAYLOAD_ONLY records which shape this release is so
# rollback and the assertions below agree.
ML_PAYLOAD_ONLY=0
if [ "$SERVICE" = "ml" ] && [ -n "$ARTIFACT_DIR" ] && [ -x "${ARTIFACT_DIR}/zeavis-ml-service" ]; then
  ML_PAYLOAD_ONLY=1
elif [ "$SERVICE" = "ml" ] && [ -n "$ARTIFACT_DIR" ]; then
  log "WARNING: ARTIFACT_DIR set but no binary in it — falling back to a host build"
fi

if [ "$ML_PAYLOAD_ONLY" = "1" ]; then
  log "artifact mode: using the binary CI built ($(stat -c '%s bytes' "${ARTIFACT_DIR}/zeavis-ml-service"))"
  as_root mkdir -p "$RELEASE_DIR"
  as_root cp -f "${ARTIFACT_DIR}/zeavis-ml-service" "${RELEASE_DIR}/zeavis-ml-service"
  # Read at runtime through MODEL_PATH, so it has to travel with the binary.
  [ -f "${ARTIFACT_DIR}/model.onnx" ] || die "CI artifact is missing model.onnx"
  as_root cp -f "${ARTIFACT_DIR}/model.onnx" "${RELEASE_DIR}/model.onnx"
  # The launcher is a file from the repo, but artifact mode has no checkout, so
  # CI ships it in the payload dir and it is installed from there below.
  [ -f "${ARTIFACT_DIR}/ml-launcher.sh" ] || die "CI artifact is missing ml-launcher.sh"
  ML_LAUNCHER_SRC="${ARTIFACT_DIR}/ml-launcher.sh"
elif [ -d "${RELEASE_DIR}/.git" ]; then
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
  [ -f "$RELEASE_DIR/package.json" ] || die "$RELEASE_DIR is not a checkout of zeavis-edu"
  log "checked out $(git -C "$RELEASE_DIR" rev-parse --short HEAD)"
  ML_LAUNCHER_SRC="$RELEASE_DIR/scripts/ml-launcher.sh"
fi

# Carry runtime env across (not tracked by git, so a fresh checkout has none).
# On the very first deploy the live path is still the old real directory; after
# that it is a symlink, so fall back to the previous release. A payload release
# has no .env and ml reads config from the environment, so this only applies to
# checkout mode.
ENV_SRC=""
if [ "$ML_PAYLOAD_ONLY" != "1" ]; then
  if [ -f "${LIVE_LINK}/.env" ]; then
    ENV_SRC="${LIVE_LINK}/.env"
  elif [ -n "$PREV_TARGET" ] && [ -f "$PREV_TARGET/.env" ]; then
    ENV_SRC="$PREV_TARGET/.env"
  fi
  if [ -n "$ENV_SRC" ] && [ ! -f "${RELEASE_DIR}/.env" ]; then
    cp "$ENV_SRC" "${RELEASE_DIR}/.env"
    log "carried .env from the previous payload"
  fi
fi

# ── 2. install (+ build for web) ───────────────────────────────────────────
# NODE_ENV must NOT be production here: pnpm would then skip devDependencies
# (typescript, tsx, vite, @moonrepo/cli) and the build/start would fail.
if [ "$SERVICE" = "ml" ]; then
  if [ "$ML_PAYLOAD_ONLY" = "1" ]; then
    log "ml: artifact mode — nothing to build here (CI compiled the binary)"
  else
    (
      cd "$RELEASE_DIR/apps/ml-service"
      log "cargo build --locked --release"
      "$CARGO" build --locked --release
    )
  fi
else
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
fi

# $TARGET is what the live path will point at: the built SPA for web, the whole
# checkout for api (the launcher `cd`s into it and runs apps/api/.../tsx).
if [ -n "$ARTIFACT" ]; then
  TARGET="$RELEASE_DIR/$ARTIFACT"
  [ -f "$TARGET/index.html" ] || die "build produced no $TARGET/index.html"
elif [ "$SERVICE" = "ml" ]; then
  TARGET="$RELEASE_DIR"
  if [ "$ML_PAYLOAD_ONLY" = "1" ]; then
    # Payload release: binary and model sit at the release root.
    [ -x "$TARGET/zeavis-ml-service" ] \
      || die "artifact release is missing zeavis-ml-service"
    [ -f "$TARGET/model.onnx" ] \
      || die "artifact release is missing model.onnx"
  else
    [ -x "$TARGET/apps/ml-service/target/release/zeavis-ml-service" ] \
      || die "cargo build did not produce apps/ml-service/target/release/zeavis-ml-service"
    [ -f "$TARGET/Machine_Learning/model/model.onnx" ] \
      || die "model.onnx missing from the release payload"
  fi
else
  TARGET="$RELEASE_DIR"
  [ -x "$TARGET/apps/api/node_modules/.bin/tsx" ] \
    || die "pnpm install did not produce apps/api/node_modules/.bin/tsx"
  [ -f "$TARGET/packages/shared/dist/index.js" ] \
    || die "pnpm did not produce packages/shared/dist/index.js"
fi

# The units run as dedicated users (zeavis-api / zeavis-web); make sure the
# freshly installed tree is readable regardless of who ran the deploy.
as_root chmod -R a+rX "$RELEASE_DIR"

# ── 3. activate ────────────────────────────────────────────────────────────
log "activating $TARGET"
NEW_LINK="${LIVE_LINK}.new.$$"
as_root ln -sfn "$TARGET" "$NEW_LINK"
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
elif [ "$SERVICE" = "ml" ]; then
  # ml: the live path is the release root carrying the payload. Either shape
  # satisfies this — asserting the target/ path would fail every artifact deploy.
  if [ "$ML_PAYLOAD_ONLY" = "1" ]; then
    [ -x "$LIVE_LINK/zeavis-ml-service" ] || die "$LIVE_LINK is not a payload ml release"
    [ -f "$LIVE_LINK/model.onnx" ] || die "$LIVE_LINK does not carry the ONNX model"
  else
    [ -e "$LIVE_LINK/apps/ml-service/target/release/zeavis-ml-service" ] \
      || die "$LIVE_LINK does not point at a built ml release"
    [ -e "$LIVE_LINK/Machine_Learning/model/model.onnx" ] \
      || die "$LIVE_LINK does not carry the ONNX model"
  fi
else
  # api: the launcher `cd`s into this path, so it must be a checkout
  [ -e "$LIVE_LINK/package.json" ] || die "$LIVE_LINK does not point at a release"
fi
ACTIVATED=1

# ml ships its launcher from THIS commit so ExecStart always matches the payload
# being activated. The previous launcher is kept as .pre for rollback.
if [ "$SERVICE" = "ml" ]; then
  as_root mkdir -p "$BASE_DIR/bin"
  # Backup the CURRENT launcher before anything is overwritten, so rollback can
  # put it back. In payload mode bin/zeavis-ml-service is the LAUNCHER, not the
  # binary, so this runs before the binary is copied in.
  if [ -f "$BASE_DIR/bin/zeavis-ml-service" ] && [ ! -L "$BASE_DIR/bin/zeavis-ml-service" ]; then
    as_root cp -a "$BASE_DIR/bin/zeavis-ml-service" "$BASE_DIR/bin/zeavis-ml-service.pre"
  fi
  log "installing launcher $BASE_DIR/bin/zeavis-ml-service"
  as_root cp "$ML_LAUNCHER_SRC" "$BASE_DIR/bin/zeavis-ml-service"
  as_root chmod 755 "$BASE_DIR/bin/zeavis-ml-service"
  # In payload mode the binary is copied into bin/ next to the launcher, and
  # ml-service-launcher execs it from there, so the release no longer needs a
  # cargo target/ at all. Verified safe: ldd on the binary lists only
  # libc/libstdc++/libgcc/libm (ort's onnxruntime is statically linked in) and
  # /proc/<pid>/maps for the running service shows exactly one file from the
  # release — the binary.
  if [ "$ML_PAYLOAD_ONLY" = "1" ]; then
    as_root cp -f "$TARGET/zeavis-ml-service" "$BASE_DIR/bin/zeavis-ml-service.bin"
    as_root chmod 0555 "$BASE_DIR/bin/zeavis-ml-service.bin"
    as_root cp -f "$TARGET/model.onnx" "$BASE_DIR/bin/model.onnx"
    log "installed $BASE_DIR/bin/zeavis-ml-service.bin + model.onnx"
  fi
fi

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

# In host-build mode the build left a ~650M target/ in the release. Nothing
# reads it at runtime (the launcher execs the binary copied into $BASE_DIR/bin,
# or its own fallback path), so drop it now rather than leaving it to the prune:
# a manual deploy would otherwise keep hundreds of megabytes per release.
if [ "$SERVICE" = "ml" ] && [ "$ML_PAYLOAD_ONLY" != "1" ] \
   && [ -d "${RELEASE_DIR}/apps/ml-service/target" ]; then
  log "dropping build cache ${RELEASE_DIR}/apps/ml-service/target ($(du -sh "${RELEASE_DIR}/apps/ml-service/target" 2>/dev/null | cut -f1))"
  as_root rm -rf "${RELEASE_DIR}/apps/ml-service/target"
fi

# ── 6. prune old releases ──────────────────────────────────────────────────
# Runs AFTER the health check, so a failed deploy keeps its rollback target.
# KEEP_RELEASES is a TOTAL including the live release: keep the live one, then
# the newest KEEP_RELEASES-1 of the rest. Counting only the old ones (as this
# used to) kept live plus N, one more than asked for.
live_target="$(readlink "$LIVE_LINK")"
log "pruning old releases (keeping live + $((KEEP_RELEASES - 1)) rollback)"
kept=0
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  [ "$dir" = "$live_target" ] && continue
  [ "$dir" = "$RELEASE_DIR" ] && continue
  kept=$((kept + 1))
  if [ "$kept" -le "$((KEEP_RELEASES - 1))" ]; then
    log "  keeping: $(basename "$dir")"
  else
    log "  pruning: $(basename "$dir")"
    as_root rm -rf "$dir"
  fi
done < <(ls -1dt "$RELEASES_DIR"/*/ 2>/dev/null || true)
log "  releases now: $(ls -1d "$RELEASES_DIR"/*/ 2>/dev/null | wc -l)"

log "done: $LIVE_LINK -> $live_target"
