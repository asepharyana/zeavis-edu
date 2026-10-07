#!/usr/bin/env bash
set -euo pipefail

# Launcher for zeavis-ml-service (plain-paths, no Nix references).
# Systemd ExecStart expects this to start the service; the deploy script
# overwrites it on each ml deploy to point to the newly activated release.

# Default locations (systemd unit can also set envs; we fall back to these)
MODEL_PATH="${MODEL_PATH:-/opt/zeavis-ml-service/current/Machine_Learning/model/model.onnx}"
ML_SERVICE_HOST="${ML_SERVICE_HOST:-0.0.0.0}"
ML_SERVICE_PORT="${ML_SERVICE_PORT:-4012}"
MODEL_INPUT_SIZE="${MODEL_INPUT_SIZE:-224}"
RUST_LOG="${RUST_LOG:-info}"

# The binary lives in the currently symlinked release
RELEASE_ROOT="/opt/zeavis-ml-service/current"
BIN="$RELEASE_ROOT/apps/ml-service/target/release/zeavis-ml-service"

export MODEL_PATH ML_SERVICE_HOST ML_SERVICE_PORT MODEL_INPUT_SIZE RUST_LOG

if [ ! -x "$BIN" ]; then
  echo "binary not found: $BIN" >&2
  exit 1
fi

exec "$BIN"
