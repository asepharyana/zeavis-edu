# Fullstack Monorepo Scaffold Design

## Goal

Scaffold the ZeaVis Edu application foundation beside the existing `Machine_Learning/` pipeline. The scaffold should establish a Bun + Moon TypeScript monorepo with a React frontend, Elysia backend, shared package, and PostgreSQL/Drizzle configuration without implementing product features beyond a landing page, placeholder dashboard, and basic API status endpoints.

## Architecture

The repository keeps the existing `Machine_Learning/` directory unchanged and adds a JavaScript/TypeScript monorepo at the root.

- `apps/web`: React + Vite + TypeScript frontend.
- `apps/api`: Elysia + TypeScript backend.
- `packages/shared`: shared TypeScript types/utilities used by both apps.

Root configuration will include Bun workspaces, Moon workspace/project configuration, TypeScript base config, and scripts/tasks for development, build, and type checking. The scaffold should prefer local package boundaries over cross-app imports so each app can be developed independently while sharing stable types through `packages/shared`.

## Frontend

`apps/web` provides the initial ZeaVis Edu UI foundation.

Routes:

- `/`: landing page with a ZeaVis Edu introduction and CTA to the dashboard.
- `/dashboard`: placeholder dashboard with cards for disease detection, analysis history, and educational materials.

Frontend providers include React Router and TanStack Query. Zustand is included with a small UI store so state-management wiring is present without adding domain assumptions. Tailwind is configured with a shadcn/ui-style foundation, including a `cn` utility and basic `Button` and `Card` components.

## Backend

`apps/api` provides a small Elysia API.

Routes:

- `GET /health`: returns API health status.
- `GET /api/v1/status`: returns application status suitable for frontend consumption.

Backend structure:

- `src/index.ts`: server entry point.
- `src/routes/`: Elysia route modules.
- `src/db/`: Drizzle client and schema.
- `src/config/`: environment configuration.

Database configuration uses PostgreSQL through `DATABASE_URL`. The initial health and status routes must not require a live database connection so the backend can run immediately after install even when the user has not provisioned Postgres.

## Database

The scaffold includes Drizzle configuration and a minimal schema placeholder. It does not include Docker Compose. A root `.env.example` documents `DATABASE_URL` and app ports. Migrations and domain tables are deferred until the first database-backed feature.

## Shared Package

`packages/shared` exports simple shared application status types. The backend uses these types for API responses, and the frontend can use them for typed API calls later. Shared code should stay domain-neutral at scaffold time.

## Error Handling

Initial error handling is intentionally minimal. Static health/status endpoints return JSON responses. Input validation and richer error mapping are deferred until routes accept external user input or database-backed operations.

## Verification

Because the repository currently has no test suite, initial verification focuses on install and build checks:

- `bun install`
- Moon or package-level typecheck/build for `apps/web`
- Moon or package-level typecheck/build for `apps/api`
- Run the API locally and verify `GET /health` if the environment supports it

No test framework is added in this scaffold. Tests should be introduced with the first domain feature where behavior can be specified meaningfully.

## Out of Scope

- Docker Compose for PostgreSQL.
- Authentication.
- ML model inference integration.
- Real dashboard data.
- Database migrations for domain entities.
- Deployment configuration.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
