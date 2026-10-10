#!/usr/bin/env bash
set -euo pipefail

# Launcher for zeavis-ml-service (plain-paths, no Nix references).
# Systemd ExecStart expects this to start the service; the deploy script
# overwrites it on each ml deploy to point to the newly activated release.
#
# In payload mode the deploy script copies the CI-built binary to
# /opt/zeavis-ml-service/bin/zeavis-ml-service.bin beside this launcher, so
# the release dir does not need a 650MB cargo target/. It execs the .bin when
# that exists and falls back to the release path for releases made before the
# artifact switch, so an in-place rollback still works.

BIN_DIR="/opt/zeavis-ml-service/bin"
RELEASE_ROOT="/opt/zeavis-ml-service/current"

# Default locations (systemd unit can also set envs; we fall back to these)
MODEL_PATH="${MODEL_PATH:-$BIN_DIR/model.onnx}"
ML_SERVICE_HOST="${ML_SERVICE_HOST:-0.0.0.0}"
ML_SERVICE_PORT="${ML_SERVICE_PORT:-4012}"
MODEL_INPUT_SIZE="${MODEL_INPUT_SIZE:-224}"
RUST_LOG="${RUST_LOG:-info}"

# Payload mode: the binary copied out of the activated release. Otherwise the
# binary still lives in the release's cargo target/.
if [ -x "$BIN_DIR/zeavis-ml-service.bin" ]; then
  BIN="$BIN_DIR/zeavis-ml-service.bin"
  [ -f "$MODEL_PATH" ] || MODEL_PATH="$RELEASE_ROOT/model.onnx"
else
  BIN="$RELEASE_ROOT/apps/ml-service/target/release/zeavis-ml-service"
  [ -f "$MODEL_PATH" ] || MODEL_PATH="$RELEASE_ROOT/Machine_Learning/model/model.onnx"
fi

export MODEL_PATH ML_SERVICE_HOST ML_SERVICE_PORT MODEL_INPUT_SIZE RUST_LOG

if [ ! -x "$BIN" ]; then
  echo "binary not found: $BIN" >&2
  exit 1
fi

exec "$BIN"
