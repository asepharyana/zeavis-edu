# Task Plan — ZeaVis ML Service: from Nix payload to pnpm+systemd style deploy

PLAN_ID: nix-to-pnpm-deploy (continuation — ml-service phase)

## Context
- zeavis-ml-service (Rust/axum+onnx) is the **last** Nix-bound production service.
- Live: `/opt/zeavis-ml-service/bin/zeavis-ml-service` launcher points at deleted
  `/nix/store/...` paths; unit `active` only because PID 3725401 (Oct 04) survives.
- VPS: Ubuntu 26.04 (glibc 2.43), port 4012 (ML_SERVICE_URL secret -> 127.0.0.1:4012).
- Model: repo `Machine_Learning/model/model.onnx` (29 MB, tracked; live copy under
  `/opt/zeavis-ml-service/current/zeavis-ml/model.onnx`).
- THIS box (host1760805970 = 45.127.35.244) is the VPS; the built binary is portable
  (onnxruntime statically linked, only libc/libstdc++ needed).

## Validation completed (local == VPS)
- [x] rustup stable installed (rustc 1.99.0); `cargo build --locked --release` OK
      (10 pre-existing warnings, binary 30.5 MB at apps/ml-service/target/release/zeavis-ml-service)
- [x] Served on 4012 with real model: /health ok, /metadata ok
- [x] /predict (multipart PNG) -> HTTP 200, calibrated probs, status rejected conf 0.347
- [x] `cargo test --locked --release`: 25 passed, 0 failed

## Remaining work
- [ ] 1. Add `ml` service branch to scripts/deploy-direct.sh
- [ ] 2. Extend .github/workflows/deploy.yml matrix to [api, web, ml]
- [ ] 3. Update the deploy script comment (ml now accepted)
- [ ] 4. Replace the launcher with a plain-paths one
- [ ] 5. Keep the existing systemd unit (already plain, User=zeavis-ml, port 4012)
- [ ] 6. Restart unit, verify /health + /metadata + /predict on 4012
- [ ] 7. Prune old nix-era payload (keep current + previous per deploy script)
- [ ] 8. Run CI (deploy matrix now includes ml) and watch it go green
- [ ] 9. Optionally drop old /opt/zeavis-ml-service/share and stale /nix references

## Design decision: build on VPS (not GitHub runner)
- VPS release dir is a full git clone with apps/ml-service + Cargo.lock committed;
  `cargo build --locked --release` reproduces the exact binary validated here.
  Requires cargo on the VPS (rustup stable, ~1-2 GB) — this box already has it.
- Never build on GitHub runner: glibc mismatch danger; binary is 30 MB so building on
  the VPS is cheap and matches glibc exactly.
- TARGET for ml = $RELEASE_DIR/apps/ml-service/target/release

## Rollback
- Flip keeps .previous; on health failure, swap back and restart. The first flip
  converts the real dir (current/zeavis-ml/model.onnx) to a symlink into
  releases/<sha>/apps/ml-service with the model carried alongside.