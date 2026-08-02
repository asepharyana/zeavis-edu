# Docker Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Docker, Docker Compose, and GitHub Actions deployment for the web, API, and ML services behind Traefik on the VPS.

**Architecture:** Build three independent images: Vite static web served by Nginx, Bun/Elysia API, and FastAPI/Uvicorn ML service. Push all images to GHCR, then SSH to `/opt/ZeaVis-Edu` and run Docker Compose on the external Traefik network `app-shared-net`.

**Tech Stack:** Docker, Docker Compose, GitHub Actions, GHCR, Traefik, Bun, Vite, Nginx, FastAPI, Uvicorn, TensorFlow.

---

## File structure

- Create `.dockerignore`: keep Docker build contexts small and avoid copying local/generated artifacts into images.
- Create `apps/web/Dockerfile`: build the Vite app with Bun and serve `dist` with Nginx on port `80`.
- Create `apps/web/nginx.conf`: SPA fallback and optional `/api` reverse proxy to the public API domain for same-origin paths.
- Create `apps/api/Dockerfile`: install Bun workspace dependencies and run `apps/api/src/index.ts` on port `3000`.
- Create `apps/ml-service/Dockerfile`: install Python dependencies and run Uvicorn on port `8000`.
- Create `docker-compose.yml`: define the three production services, Traefik labels, GHCR images, and `app-shared-net`.
- Create `.github/workflows/deploy.yml`: build/push the three images and deploy them to the VPS.
- Modify `.gitignore` only if needed after checking whether `.env` is already ignored.

## Task 1: Add Docker ignore rules

**Files:**
- Create: `.dockerignore`

- [ ] **Step 1: Create `.dockerignore`**

Write this exact file:

```dockerignore
.git
.github
.claude
.moon/cache
node_modules
**/node_modules
.env
.env.*
!.env.example
Dockerfile
docker-compose.yml
Machine_Learning/dataset
Machine_Learning/dataset.zip
Machine_Learning/dataset_*.zip
Machine_Learning/model
Machine_Learning/best_model/*
!Machine_Learning/best_model/best_model.keras
apps/web/dist
apps/api/dist
__pycache__
*.pyc
.pytest_cache
.venv
venv
**/.venv
**/venv
```

- [ ] **Step 2: Verify ignore file exists**

Run:

```bash
test -f .dockerignore && grep -q 'Machine_Learning/dataset' .dockerignore
```

Expected: command exits with status `0` and prints nothing.

- [ ] **Step 3: Commit**

```bash
git add .dockerignore
git commit -m "chore: add Docker ignore rules"
```

## Task 2: Add web Docker image

**Files:**
- Create: `apps/web/Dockerfile`
- Create: `apps/web/nginx.conf`

- [ ] **Step 1: Create `apps/web/nginx.conf`**

Write this exact file:

```nginx
server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;

  location /api/ {
    proxy_pass https://api.zeavisedu.asepharyana.tech/api/;
    proxy_set_header Host api.zeavisedu.asepharyana.tech;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location / {
    try_files $uri $uri/ /index.html;
  }
}
```

- [ ] **Step 2: Create `apps/web/Dockerfile`**

Write this exact file:

```dockerfile
FROM oven/bun:1 AS deps
WORKDIR /app
COPY package.json bun.lock ./
COPY apps/web/package.json apps/web/package.json
COPY packages/shared/package.json packages/shared/package.json
RUN bun install --frozen-lockfile

FROM oven/bun:1 AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/web/node_modules ./apps/web/node_modules
COPY --from=deps /app/packages/shared/node_modules ./packages/shared/node_modules
COPY package.json bun.lock ./
COPY apps/web ./apps/web
COPY packages/shared ./packages/shared
WORKDIR /app/apps/web
ENV VITE_API_BASE_URL=
RUN bun run build

FROM nginx:1.27-alpine AS runner
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/apps/web/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

- [ ] **Step 3: Build the web image locally**

Run:

```bash
docker build -f apps/web/Dockerfile -t zeavis-web:test .
```

Expected: Docker build completes successfully and includes the `bun run build` step.

- [ ] **Step 4: Commit**

```bash
git add apps/web/Dockerfile apps/web/nginx.conf
git commit -m "feat: add web Docker image"
```

## Task 3: Add API Docker image

**Files:**
- Create: `apps/api/Dockerfile`

- [ ] **Step 1: Create `apps/api/Dockerfile`**

Write this exact file:

```dockerfile
FROM oven/bun:1 AS deps
WORKDIR /app
COPY package.json bun.lock ./
COPY apps/api/package.json apps/api/package.json
COPY packages/shared/package.json packages/shared/package.json
RUN bun install --frozen-lockfile --production

FROM oven/bun:1 AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV API_PORT=3000
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=deps /app/packages/shared/node_modules ./packages/shared/node_modules
COPY package.json bun.lock ./
COPY apps/api ./apps/api
COPY packages/shared ./packages/shared
EXPOSE 3000
CMD ["bun", "--env-file=.env", "apps/api/src/index.ts"]
```

- [ ] **Step 2: Build the API image locally**

Run:

```bash
docker build -f apps/api/Dockerfile -t zeavis-api:test .
```

Expected: Docker build completes successfully.

- [ ] **Step 3: Verify the API image starts far enough to read required env**

Run:

```bash
docker run --rm -e DATABASE_URL=postgres://user:pass@example.com:5432/db -e SESSION_SECRET=abcdefghijklmnopqrstuvwxyz123456 -e WEB_APP_URL=https://zeavisedu.asepharyana.tech -e ML_SERVICE_URL=https://ml.zeavisedu.asepharyana.tech zeavis-api:test bun apps/api/src/index.ts
```

Expected: container starts and prints `ZeaVis Edu API running`. Stop it with `Ctrl+C` after seeing the log.

- [ ] **Step 4: Commit**

```bash
git add apps/api/Dockerfile
git commit -m "feat: add API Docker image"
```

## Task 4: Add ML service Docker image

**Files:**
- Create: `apps/ml-service/Dockerfile`

- [ ] **Step 1: Create `apps/ml-service/Dockerfile`**

Write this exact file:

```dockerfile
FROM python:3.11-slim AS runner

WORKDIR /app
ENV PYTHONUNBUFFERED=1
ENV MODEL_PATH=/app/model/best_model.keras
ENV MODEL_INPUT_SIZE=224

RUN apt-get update \
  && apt-get install -y --no-install-recommends libgomp1 \
  && rm -rf /var/lib/apt/lists/*

COPY apps/ml-service/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY apps/ml-service ./
COPY Machine_Learning/best_model/best_model.keras /app/model/best_model.keras

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 2: Check whether the model artifact exists locally**

Run:

```bash
test -f Machine_Learning/best_model/best_model.keras
```

Expected: status `0`. If it fails, get the model artifact before building; this Dockerfile intentionally requires the production model to be present.

- [ ] **Step 3: Build the ML image locally**

Run:

```bash
docker build -f apps/ml-service/Dockerfile -t zeavis-ml:test .
```

Expected: Docker build completes successfully.

- [ ] **Step 4: Verify the ML image health endpoint**

Run:

```bash
docker run --rm -p 8000:8000 zeavis-ml:test
```

In another terminal, run:

```bash
curl -fsS http://localhost:8000/health
```

Expected: JSON response includes `"status":"ok"`. Stop the container with `Ctrl+C`.

- [ ] **Step 5: Commit**

```bash
git add apps/ml-service/Dockerfile
git commit -m "feat: add ML service Docker image"
```

## Task 5: Add production Docker Compose

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Create `docker-compose.yml`**

Write this exact file:

```yaml
networks:
  app-shared-net:
    external: true
    name: app-shared-net

services:
  web:
    image: ghcr.io/${GITHUB_REPOSITORY:-mytheclipse/zeavis-edu}/web:main
    container_name: zeavis-web
    restart: always
    networks:
      - app-shared-net
    env_file:
      - .env
    labels:
      traefik.enable: "true"
      traefik.http.routers.zeavis-web.rule: Host(`zeavisedu.asepharyana.tech`)
      traefik.http.routers.zeavis-web.entrypoints: websecure
      traefik.http.routers.zeavis-web.tls: "true"
      traefik.http.routers.zeavis-web.tls.certresolver: letsencrypt
      traefik.http.services.zeavis-web.loadbalancer.server.port: "80"

  api:
    image: ghcr.io/${GITHUB_REPOSITORY:-mytheclipse/zeavis-edu}/api:main
    container_name: zeavis-api
    restart: always
    networks:
      - app-shared-net
    env_file:
      - .env
    environment:
      NODE_ENV: production
      API_PORT: "3000"
      WEB_APP_URL: https://zeavisedu.asepharyana.tech
      ML_SERVICE_URL: https://ml.zeavisedu.asepharyana.tech
    labels:
      traefik.enable: "true"
      traefik.http.routers.zeavis-api.rule: Host(`api.zeavisedu.asepharyana.tech`)
      traefik.http.routers.zeavis-api.entrypoints: websecure
      traefik.http.routers.zeavis-api.tls: "true"
      traefik.http.routers.zeavis-api.tls.certresolver: letsencrypt
      traefik.http.services.zeavis-api.loadbalancer.server.port: "3000"

  ml:
    image: ghcr.io/${GITHUB_REPOSITORY:-mytheclipse/zeavis-edu}/ml:main
    container_name: zeavis-ml
    restart: always
    networks:
      - app-shared-net
    env_file:
      - .env
    environment:
      MODEL_PATH: /app/model/best_model.keras
      MODEL_INPUT_SIZE: "224"
    labels:
      traefik.enable: "true"
      traefik.http.routers.zeavis-ml.rule: Host(`ml.zeavisedu.asepharyana.tech`)
      traefik.http.routers.zeavis-ml.entrypoints: websecure
      traefik.http.routers.zeavis-ml.tls: "true"
      traefik.http.routers.zeavis-ml.tls.certresolver: letsencrypt
      traefik.http.services.zeavis-ml.loadbalancer.server.port: "8000"
```

- [ ] **Step 2: Validate compose syntax**

Run:

```bash
GITHUB_REPOSITORY=mytheclipse/zeavis-edu docker compose config >/tmp/zeavis-compose.yml
```

Expected: command exits with status `0`.

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add production Docker Compose"
```

## Task 6: Add GitHub Actions deploy workflow

**Files:**
- Create: `.github/workflows/deploy.yml`

- [ ] **Step 1: Create `.github/workflows/deploy.yml`**

Write this exact file:

```yaml
name: Build and Deploy

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_PREFIX: ghcr.io/${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    strategy:
      fail-fast: false
      matrix:
        service:
          - name: web
            dockerfile: apps/web/Dockerfile
          - name: api
            dockerfile: apps/api/Dockerfile
          - name: ml
            dockerfile: apps/ml-service/Dockerfile
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.IMAGE_PREFIX }}/${{ matrix.service.name }}
          tags: |
            type=ref,event=branch
            type=sha

      - name: Build and push image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ${{ matrix.service.dockerfile }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha,scope=${{ matrix.service.name }}
          cache-to: type=gha,mode=max,scope=${{ matrix.service.name }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    permissions:
      contents: read
      packages: read
    steps:
      - name: Deploy to VPS
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          port: ${{ secrets.VPS_PORT || 22 }}
          script: |
            set -e
            cd /opt/ZeaVis-Edu
            git pull origin main

            cat > .env << 'ENVEOF'
            GITHUB_REPOSITORY=${{ github.repository }}
            DATABASE_URL=${{ secrets.DATABASE_URL }}
            SESSION_SECRET=${{ secrets.SESSION_SECRET }}
            WEB_APP_URL=https://zeavisedu.asepharyana.tech
            ML_SERVICE_URL=https://ml.zeavisedu.asepharyana.tech
            ENVEOF

            docker login ghcr.io -u ${{ github.actor }} -p ${{ secrets.GITHUB_TOKEN }}
            docker network create app-shared-net 2>/dev/null || true
            docker compose pull
            docker compose up -d
            docker compose ps
            docker compose ps | grep -q "zeavis-web.*Up" || exit 1
            docker compose ps | grep -q "zeavis-api.*Up" || exit 1
            docker compose ps | grep -q "zeavis-ml.*Up" || exit 1
```

- [ ] **Step 2: Validate workflow YAML exists and has all services**

Run:

```bash
grep -q 'apps/web/Dockerfile' .github/workflows/deploy.yml && grep -q 'apps/api/Dockerfile' .github/workflows/deploy.yml && grep -q 'apps/ml-service/Dockerfile' .github/workflows/deploy.yml
```

Expected: command exits with status `0` and prints nothing.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/deploy.yml
git commit -m "ci: deploy Docker images to VPS"
```

## Task 7: Run final local verification

**Files:**
- Verify all files from previous tasks.

- [ ] **Step 1: Run typecheck**

Run:

```bash
bun run typecheck
```

Expected: command exits with status `0`.

- [ ] **Step 2: Build all Docker images**

Run:

```bash
docker build -f apps/web/Dockerfile -t zeavis-web:test . && docker build -f apps/api/Dockerfile -t zeavis-api:test . && docker build -f apps/ml-service/Dockerfile -t zeavis-ml:test .
```

Expected: all three Docker builds complete successfully.

- [ ] **Step 3: Validate compose config**

Run:

```bash
GITHUB_REPOSITORY=mytheclipse/zeavis-edu docker compose config >/tmp/zeavis-compose.yml
```

Expected: command exits with status `0`.

- [ ] **Step 4: Check final git status**

Run:

```bash
git status --short
```

Expected: no uncommitted changes.

## Task 8: Configure GitHub secrets and trigger deploy

**Files:**
- No repo file changes.

- [ ] **Step 1: Confirm required secrets exist**

Run:

```bash
gh secret list
```

Expected: output includes `VPS_HOST`, `VPS_USER`, `VPS_PORT`, `VPS_SSH_KEY`, `DATABASE_URL`, and `SESSION_SECRET`.

- [ ] **Step 2: Add missing secrets if needed**

Use these commands only for missing secrets:

```bash
gh secret set VPS_HOST --body "<vps-host>"
gh secret set VPS_USER --body "root"
gh secret set VPS_PORT --body "22"
gh secret set VPS_SSH_KEY < ~/.ssh/id_ed25519
gh secret set DATABASE_URL --body "<production-database-url>"
gh secret set SESSION_SECRET --body "<at-least-32-character-secret>"
```

Expected: `gh secret list` shows all required secret names. Replace angle-bracket values with the real production values before running.

- [ ] **Step 3: Push commits to main**

Run only after the user approves pushing:

```bash
git push origin main
```

Expected: push succeeds and GitHub Actions starts the `Build and Deploy` workflow.

## Task 9: Verify production deployment

**Files:**
- No repo file changes.

- [ ] **Step 1: Check workflow status**

Run:

```bash
gh run list --workflow deploy.yml --limit 1
```

Expected: latest run eventually shows `completed` and `success`.

- [ ] **Step 2: Check VPS containers**

Run:

```bash
ssh <vps-user>@<vps-host> "cd /opt/ZeaVis-Edu && docker compose ps"
```

Expected: `zeavis-web`, `zeavis-api`, and `zeavis-ml` show `Up`.

- [ ] **Step 3: Check service logs**

Run:

```bash
ssh <vps-user>@<vps-host> "docker logs --tail 100 zeavis-web && docker logs --tail 100 zeavis-api && docker logs --tail 100 zeavis-ml"
```

Expected: no startup crash loops or missing required environment errors.

- [ ] **Step 4: Check public domains**

Run:

```bash
curl -I https://zeavisedu.asepharyana.tech/
curl -I https://api.zeavisedu.asepharyana.tech/health
curl -I https://ml.zeavisedu.asepharyana.tech/health
```

Expected: frontend does not return Traefik `404 page not found`; API and ML health endpoints return an expected application response.
