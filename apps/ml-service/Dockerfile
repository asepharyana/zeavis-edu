# syntax=docker/dockerfile:1

# Production image for the ZeaVis Edu ML service (Rust / Axum).
#
# The runtime base is pinned to a Debian-family image rather than archlinux
# despite what it previously used. A Rust binary links against the glibc of the
# toolchain that compiled it, and `rust:1.95-trixie` builds against Debian 13
# glibc: copying that binary onto archlinux — which ships a different, separately
# versioned glibc — produces an image that passes `docker build` and then dies
# with a loader error at start. Pinning the runtime to the same Debian release
# as the builder is what makes the image match the binary.
#
# Note the CI deploy for this repo compiles ON the VPS with `cargo build --release
# --locked` rather than in a container, specifically to avoid runner/production
# glibc drift. This image pins both sides to the same Debian release so it is
# equivalent to what production runs, instead of a third glibc in the set.

# The toolchain tag and the runtime tag must be the same Debian release.
ARG RUST_IMAGE=rust:1.95-trixie
ARG RUNTIME_IMAGE=debian:trixie-slim

# ── builder ───────────────────────────────────────────────────────────────
FROM ${RUST_IMAGE} AS builder
WORKDIR /app

# Dependency manifests first: the crates.io fetch is the slow part and must not
# be invalidated by a source edit.
COPY apps/ml-service/Cargo.toml apps/ml-service/Cargo.lock ./
# A dummy target lets cargo resolve the dependency graph and build its cache
# before the real sources land, so a source-only change rebuilds in seconds.
RUN mkdir -p src \
    && echo 'fn main() {}' > src/main.rs \
    && cargo build --locked --release \
    && rm -rf src

COPY apps/ml-service/src ./src
# `touch` so the real main.rs is newer than the cached dummy artifact.
RUN touch src/main.rs && cargo build --locked --release

# ── runner ────────────────────────────────────────────────────────────────
FROM ${RUNTIME_IMAGE} AS runner
WORKDIR /app

ENV MODEL_PATH=/app/model/model.onnx \
    MODEL_INPUT_SIZE=224 \
    ML_SERVICE_HOST=0.0.0.0 \
    ML_SERVICE_PORT=4012 \
    RUST_LOG=info

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/zeavis-ml-service /usr/local/bin/zeavis-ml-service
COPY Machine_Learning/model/model.onnx /app/model/model.onnx

# The binary is exec-form and receives SIGTERM directly, so it needs no init
# shim. It writes nothing, so it can drop privileges.
RUN useradd --system --uid 10001 --create-home --shell /usr/sbin/nologin zeavis
USER 10001

EXPOSE 4012

# /health is a real route (apps/ml-service/src/routes.rs). No init shim is
# needed: the exec form gives the binary SIGTERM directly.
#
# wget is present in debian-slim; curl is not, and installing it just for the
# healthcheck would add a package the runtime does not otherwise need.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:4012/health || exit 1

CMD ["zeavis-ml-service"]