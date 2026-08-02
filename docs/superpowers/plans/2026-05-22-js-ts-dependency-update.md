# JS/TS Dependency Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update all JavaScript and TypeScript dependencies in the Bun workspace with npm-check-updates, then restore typecheck/build compatibility with minimal refactors.

**Architecture:** This is a dependency maintenance change across the existing Bun + Moon monorepo. Version ranges are updated in package manifests, the Bun lockfile is regenerated, and any source/config fixes are limited to compatibility changes required by updated packages.

**Tech Stack:** Bun workspaces, Moon, TypeScript, React/Vite, Elysia, Drizzle, npm-check-updates.

---

## File Structure

- Modify: `package.json` — root workspace dev dependencies and scripts.
- Modify: `apps/api/package.json` — API runtime and dev dependencies.
- Modify: `apps/web/package.json` — web runtime and dev dependencies.
- Modify: `bun.lock` — regenerated dependency lockfile.
- Modify as needed: TypeScript source/config files that fail after dependency upgrades. Only touch files referenced by verification failures.
- Do not modify: `Machine_Learning/requirements.txt` or Python/ML files.

---

### Task 1: Update JS/TS dependency manifests and lockfile

**Files:**
- Modify: `package.json`
- Modify: `apps/api/package.json`
- Modify: `apps/web/package.json`
- Modify: `bun.lock`

- [ ] **Step 1: Confirm clean workspace before dependency changes**

Run:

```bash
git status --short
```

Expected: no output, or only known spec/plan docs from this workflow. If there are unrelated user changes, stop and ask before continuing.

- [ ] **Step 2: Run npm-check-updates for all workspace manifests**

Run:

```bash
bunx npm-check-updates -u --root --workspaces
```

Expected: `package.json`, `apps/api/package.json`, and `apps/web/package.json` dependency ranges are updated where newer versions exist.

- [ ] **Step 3: Regenerate Bun lockfile**

Run:

```bash
bun install
```

Expected: command exits successfully and updates `bun.lock` to match the new dependency ranges.

- [ ] **Step 4: Inspect dependency diff**

Run:

```bash
git diff -- package.json apps/api/package.json apps/web/package.json bun.lock
```

Expected: only JS/TS dependency range and lockfile changes appear.

---

### Task 2: Run typecheck and apply minimal compatibility fixes

**Files:**
- Modify as needed: files reported by `bun run typecheck`

- [ ] **Step 1: Run workspace typecheck**

Run:

```bash
bun run typecheck
```

Expected: PASS. If it fails, the output identifies TypeScript errors introduced or exposed by dependency updates.

- [ ] **Step 2: Fix only typecheck failures caused by updated JS/TS dependencies**

Use the error output to edit only the files named by TypeScript. Examples of allowed fixes:

```ts
// Allowed: update imports, changed API call signatures, or stricter types required by new package versions.
```

Do not add features, redesign UI, change Python files, or refactor unrelated code.

- [ ] **Step 3: Rerun typecheck after fixes**

Run:

```bash
bun run typecheck
```

Expected: PASS.

---

### Task 3: Run production build and apply minimal compatibility fixes

**Files:**
- Modify as needed: files reported by `bun run build`

- [ ] **Step 1: Run workspace production build**

Run:

```bash
bun run build
```

Expected: PASS. If it fails, the output identifies build-time errors introduced or exposed by dependency updates.

- [ ] **Step 2: Fix only build failures caused by updated JS/TS dependencies**

Use the build output to edit only the affected files. Examples of allowed fixes:

```ts
// Allowed: update Vite config, React Router APIs, Elysia APIs, Drizzle config, or TypeScript settings if required by upgraded packages.
```

Do not change application behavior beyond what is required for compatibility.

- [ ] **Step 3: Rerun production build after fixes**

Run:

```bash
bun run build
```

Expected: PASS.

---

### Task 4: Final verification and review

**Files:**
- Review: full git diff

- [ ] **Step 1: Confirm Python/ML dependencies were not touched**

Run:

```bash
git diff -- Machine_Learning/requirements.txt
```

Expected: no output.

- [ ] **Step 2: Review full diff**

Run:

```bash
git diff --stat && git diff -- package.json apps/api/package.json apps/web/package.json
```

Expected: dependency updates are present; any source/config changes are minimal and directly tied to verification failures.

- [ ] **Step 3: Run final verification commands**

Run:

```bash
bun run typecheck && bun run build
```

Expected: both commands pass.

- [ ] **Step 4: Report result**

Summarize:

```text
Updated JS/TS dependencies with ncu, regenerated bun.lock, applied any required compatibility fixes, and verified with bun run typecheck and bun run build.
```

Do not claim completion unless the final verification command passed.

---

## Self-Review

- Spec coverage: The plan updates only JS/TS manifests, regenerates `bun.lock`, allows minimal compatibility refactors, and verifies with `bun run typecheck` and `bun run build`.
- Placeholder scan: No TODO/TBD placeholders remain.
- Scope check: Python/ML dependencies are explicitly out of scope and verified unchanged.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
