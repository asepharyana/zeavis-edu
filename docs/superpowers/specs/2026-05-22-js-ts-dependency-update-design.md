# JS/TS Dependency Update Design

## Scope

Update JavaScript and TypeScript dependencies only. The affected manifests are:

- `package.json`
- `apps/api/package.json`
- `apps/web/package.json`

Do not change `Machine_Learning/requirements.txt` or the Python/ML workflow.

## Approach

Use `ncu -u` across the Bun workspace to update dependency version ranges in all JS/TS package manifests. Regenerate `bun.lock` with `bun install` so the lockfile matches the updated manifests.

## Refactor policy

After dependency installation, run workspace verification commands. If breaking changes appear, make the smallest code or config changes needed to restore compatibility. Avoid unrelated refactors and avoid adding new features.

## Verification

Run:

- `bun run typecheck`
- `bun run build`

If either command fails due to dependency updates, fix the underlying compatibility issue and rerun the relevant verification command.

## Out of scope

- Python dependency updates
- ML pipeline changes
- UI redesigns or feature additions
- Database schema changes unless a dependency update requires a generated type/config compatibility fix

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
