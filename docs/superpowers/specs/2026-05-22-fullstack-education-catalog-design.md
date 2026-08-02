# Fullstack Education Catalog Design

## Goal

Build the root fullstack application into a usable ZeaVis Edu education product for corn leaf disease learning and manual classification tracking. The implementation should cover the web experience, API, database schema, seed data, and shared types for the four current classifier labels.

## Scope

This work includes:

- A production-ready education catalog for `Bercak Daun`, `Hawar Daun`, `Karat Daun`, and `Daun Sehat`.
- Dashboard, catalog, disease detail, search/filter, manual classification submission, classification history, and summary statistics.
- PostgreSQL-backed persistence through Drizzle schema and migrations.
- Shared domain types and label utilities consumed by both frontend and backend.
- Build and typecheck verification through the existing Bun and Moon commands.

This work does not include automatic image upload or ML model inference. The data model should allow that integration later without changing disease labels or historical classification concepts.

## Architecture

`packages/shared` owns the domain contract: disease labels, slugs, risk levels, disease catalog records, manual classification records, dashboard statistics, and API response shapes. Both apps import these types so labels and payloads stay consistent.

`apps/api` owns persistence and HTTP access. Drizzle defines `disease_catalog` and `manual_classifications`. The API exposes read endpoints for the catalog and detail pages, write/read endpoints for manual classification history, and a statistics endpoint for dashboard cards.

`apps/web` owns the user experience. React Router provides pages for landing, dashboard, catalog, and disease detail. TanStack Query loads API data. The UI should gracefully show empty, loading, and error states because the backend depends on `DATABASE_URL`.

## Backend design

Database tables:

- `disease_catalog`: slug, label, common name, summary, description, symptoms, recommendations, risk level, accent color, display order, timestamps.
- `manual_classifications`: id, disease slug, confidence note or observation text, location note, created timestamp.

API routes under `/api/v1`:

- `GET /diseases`: returns all disease catalog entries ordered for display.
- `GET /diseases/:slug`: returns one disease entry or a typed not-found response.
- `POST /classifications/manual`: validates disease slug and stores a manual classification entry.
- `GET /classifications/manual`: returns recent manual classifications with disease metadata.
- `GET /dashboard/summary`: returns disease count, classification count, latest classification, and risk distribution.

Seed data should populate the four ZeaVis Edu labels with practical Indonesian educational copy.

## Frontend design

Pages:

- Landing page: clear product positioning, call-to-action to dashboard/catalog, and explanation of manual education workflow.
- Dashboard page: summary cards, risk distribution, recent manual classifications, and quick access to catalog/manual form.
- Catalog page: searchable/filterable disease cards with risk badges and primary symptoms.
- Detail page: full disease explanation, symptoms, recommendations, and manual classification action.

Manual classification flow:

- User selects a disease label from the catalog-backed list.
- User may add observation/location notes.
- On submit, the app stores the entry through the API and refreshes dashboard/history data.

## Error handling

API validates incoming slugs and request bodies at the HTTP boundary. Database connection or query failures should return consistent JSON errors. The web app should display inline fallback states and avoid crashing when the API is unavailable.

## Testing and verification

The implementation should pass:

- `bun run typecheck`
- `bun run build`

Because this includes frontend behavior, the app should also be launched locally and the main pages/manual flow should be checked in a browser if the environment allows it.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
