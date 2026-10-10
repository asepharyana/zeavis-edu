#!/usr/bin/env bash
#
# Guard for the release-cap block in a deploy script.
#
# Two bugs lived here and both are invisible in normal operation:
#
#   1. N+1 budget. Counting only the OLD releases and keeping KEEP_RELEASES of
#      them left live + N on disk, one more than the cap. KEEP_RELEASES is a
#      TOTAL, live included.
#   2. The live-release guard never fired. `readlink` emits no trailing slash
#      while `ls -1dt` emits one, so comparing the two paths never matched and
#      the live release was eligible for pruning. It only showed up on zeavis,
#      where the deploy left a single release: both 707M predecessors were
#      pruned and there was no rollback target left.
#
# The fixture deliberately points `current` at the OLDEST release, the case the
# old code got wrong — in production `current` is normally the newest, so the
# guard's failure is invisible until the day you roll back.
#
# Usage: bash scripts/tests/prune-release-cap.sh <path-to-deploy-direct.sh>

set -Eeuo pipefail

SCRIPT="${1:?usage: prune-release-cap.sh <path-to-deploy-direct.sh>}"
[ -f "$SCRIPT" ] || { echo "no such file: $SCRIPT" >&2; exit 2; }

# Extract the prune block so the test runs the REAL code, not a copy that can
# drift from it.
BLOCK="$(awk '/^# ── [0-9]+\. prune old releases/,/^log "done:/' "$SCRIPT")"
[ -n "$BLOCK" ] || {
  echo "FAIL: could not find the prune block in $SCRIPT" >&2
  exit 1
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0
check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ok   $label: $actual"
  else
    echo "  FAIL $label: got '$actual', want '$expected'"
    fail=1
  fi
}

echo "=== fixture: 4 releases, current -> the OLDEST, cap 2 (live + 1 rollback)"
mkdir -p "$WORK/releases"/{aaa_oldest,bbb_mid,ccc_new,d_newest}
ln -sfn "$WORK/releases/aaa_oldest" "$WORK/current"

# Stubs for the script's helpers and variables the block closes over. Without
# these the eval aborts on `log: command not found` under `set -e` and the test
# silently measures nothing.
log()    { printf '%s\n' "$*"; }
as_root(){ "$@"; }
RELEASE_DIR="$WORK/releases/d_newest"
KEEP_RELEASES=2

RELEASES_DIR="$WORK/releases" LIVE_LINK="$WORK/current" \
  eval "$BLOCK" >"$WORK/log" 2>&1 || true
sed 's/^/  /' "$WORK/log"

check "survivors"  "$(ls -1d "$WORK/releases"/*/ 2>/dev/null | wc -l)" 2
check "live kept"  "$([ -d "$WORK/current/" ] && echo yes || echo no)"   yes
check "rollback is newest" \
  "$(ls -1 "$WORK/releases" | tr '\n' ' ')" "aaa_oldest d_newest "

if [ "$fail" = "0" ]; then
  echo "PASS: live release survives and the cap holds"
else
  echo "FAILED"
fi
exit "$fail"
