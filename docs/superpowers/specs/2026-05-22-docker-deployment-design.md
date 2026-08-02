# Docker Deployment Design

## Goal

Deploy all ZeaVis Edu production services from GitHub Actions to GHCR and then to a VPS behind Traefik.

The deployment will use:

- Deploy directory: `/opt/ZeaVis-Edu`
- Shared Traefik Docker network: `app-shared-net`
- Frontend domain: `zeavisedu.asepharyana.tech`
- API domain: `api.zeavisedu.asepharyana.tech`
- ML service domain: `ml.zeavisedu.asepharyana.tech`

## Architecture

The repo will deploy as three independent production containers:

1. `zeavis-web`
   - Builds the Vite React app from `apps/web`.
   - Serves static assets through Nginx.
   - Routes through Traefik at `https://zeavisedu.asepharyana.tech`.
   - Uses internal port `80`.

2. `zeavis-api`
   - Runs the Elysia API with Bun from `apps/api`.
   - Routes through Traefik at `https://api.zeavisedu.asepharyana.tech`.
   - Uses internal port `3000`.
   - Calls the ML service through `ML_SERVICE_URL=https://ml.zeavisedu.asepharyana.tech`.

3. `zeavis-ml`
   - Runs the FastAPI ML service from `apps/ml-service` with Uvicorn.
   - Routes through Traefik at `https://ml.zeavisedu.asepharyana.tech`.
   - Uses internal port `8000`.
   - Loads the TensorFlow model from the path expected by the existing service code unless implementation inspection shows a supported environment override.

All containers join the external Docker network `app-shared-net`. Host ports are not published because Traefik is the public entrypoint.

## Images

GitHub Actions will build and push three GHCR images on pushes to `main` and manual workflow dispatch:

- `ghcr.io/${{ github.repository }}/web:main`
- `ghcr.io/${{ github.repository }}/api:main`
- `ghcr.io/${{ github.repository }}/ml:main`

Each image will also receive a SHA tag for traceability.

## Compose deployment

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.

The VPS will run `docker compose` from `/opt/ZeaVis-Edu`.

The compose file will define:

- External network `app-shared-net`.
- One service per image.
- Stable container names: `zeavis-web`, `zeavis-api`, `zeavis-ml`.
- `restart: always` for all services.
- Traefik labels for each domain, using `websecure`, TLS enabled, and the `letsencrypt` cert resolver.
- `env_file: .env` for runtime configuration.

## GitHub Actions deployment flow

The workflow will:

1. Check out the repository.
2. Set up Docker Buildx.
3. Log in to GHCR with `GITHUB_TOKEN`.
4. Build and push the web, API, and ML images.
5. SSH to the VPS after successful image pushes.
6. Change directory to `/opt/ZeaVis-Edu`.
7. Pull the latest `main` branch.
8. Rewrite `.env` from GitHub repository secrets.
9. Ensure `app-shared-net` exists.
10. Run `docker compose pull`.
11. Run `docker compose up -d`.
12. Show `docker compose ps` and fail if any service is not up.

## Required secrets

The workflow requires these repository secrets:

- `VPS_HOST`
- `VPS_USER`
- `VPS_PORT`
- `VPS_SSH_KEY`
- `DATABASE_URL`

If frontend or API code requires public URL configuration at build time or runtime, implementation will add the exact required secrets after inspecting the existing environment variable names.

## Verification

After deployment, verify:

- `docker compose ps` shows all three services up.
- `docker logs --tail 100 zeavis-web` has no startup errors.
- `docker logs --tail 100 zeavis-api` has no startup errors.
- `docker logs --tail 100 zeavis-ml` has no startup errors.
- `curl -I https://zeavisedu.asepharyana.tech/` returns a non-Traefik 404 response.
- `curl -I https://api.zeavisedu.asepharyana.tech/health` returns the API health response or an expected application response.
- `curl -I https://ml.zeavisedu.asepharyana.tech/health` returns the ML health response.

## Out of scope

- Provisioning Traefik itself.
- Creating DNS records.
- Migrating or seeding production database data.
- Changing application behavior beyond what is required to run correctly in containers.
