# PLAN_ID: nix-to-pnpm-deploy

## Goal
Migrate `asepharyana/zeavis-edu` from a Nix-based GitHub Actions deploy to a plain
pnpm + systemd deploy (api + web), and make its CI green.

## Root cause (verified from run 37508350515, job 112423912504)
```
nix copy --to "ssh://***@$VPS_HOST" "$STORE_PATH"
error: cannot connect to '***'
##[error]Process completed with exit code 1.
```
Nix was removed from the VPS (`ls /nix` -> No such file or directory), so the
`nix copy` ssh backend cannot run `nix-store` remotely. Every
`build-and-deploy` matrix job dies at copy; `test` and `cleanup` pass.

## Phases
- [x] P1 Inspect VPS (read-only), repo, and hub house pattern
- [x] P2 Repo migration Bun -> pnpm (workspace file, packageManager, lock)
- [x] P3 Port API source off the `Bun` global (env, seed, Elysia node adapter)
- [x] P4 Replace `bun:test` with vitest, keep all 5 cases / 11 assertions
- [x] P5 moon configs: packageManager pnpm, `bun run X` -> `pnpm run X`
- [x] P6 Rewrite .github/workflows/deploy.yml (no Nix, matrix [api, web])
- [x] P7 Add scripts/deploy-direct.sh (api swap + web html flip, health, rollback)
- [x] P8 Local gates green: pnpm install --frozen-lockfile, test, typecheck
- [x] P9 Push, poll CI until green, fix failures  -> run 37521235861 success
- [x] P10 Read-only VPS verification

## Decisions
- Health checks: api `http://127.0.0.1:4006/health` (verified 200),
  web `http://127.0.0.1:4011/` (verified 200 html).
- ml-service: dropped from the deploy matrix, not wired, unit+launcher untouched.
  Rust/onnx binary cannot be built from this pnpm tree.
- `flake.nix` / `flakehub-publish-rolling.yaml` untouched (separate workflow,
  currently green); Nix removal is scoped to deploy.yml as instructed.
- CI typecheck scoped to `shared api web` — `ml-service:typecheck` is `cargo check`
  and is out of the pnpm scope of this migration.
- Test runner: vitest 5.0.3 (peer vite ^8.0.0 matches the repo's vite ^8.3.2).

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `nix copy` -> `error: cannot connect to '***'` | 1 | replaced the whole Nix deploy with pnpm + systemd |
| 7 pre-existing `error TS` under `types: ["node"]` | 1 | completed DiseaseCatalogItem from the shared seed; `toDisease()` at all sites; `new Date(String(v))`; cast for Bun-only `fetch.preconnect` |
| CI: `Process git failed: exit 128 / merge-base master HEAD` | 1 | reproduced with `CI=true` locally; set `vcs.defaultBranch: main` in `.moon/workspace.yml` |
| local dry-run: web live path -> checkout root, no index.html | 1 | flip targets `$RELEASE_DIR/apps/web/dist`; validate `$TARGET` before flipping |
| api runtime import of `@zeavis/shared` needs `packages/shared/dist` | 1 | api deploy now runs `pnpm --filter @zeavis/shared build` |
| Dependabot: `ERR_PNPM_NO_MATURE_MATCHING_VERSION` on @moonrepo/cli 2.6.0 | 1 | pinned lockfile to 2.5.6 (published 2026-09-28); re-verify on next scheduled run |
