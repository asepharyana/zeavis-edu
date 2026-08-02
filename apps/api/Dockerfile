FROM oven/bun:1.3.14 AS deps
WORKDIR /app

COPY package.json bun.lock bunfig.toml tsconfig.base.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/web/package.json apps/web/package.json
COPY apps/tauri/package.json apps/tauri/package.json
COPY packages/shared/package.json packages/shared/package.json
RUN bun install --production

FROM oven/bun:1.3.14 AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV API_PORT=4006

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/api/node_modules apps/api/node_modules
COPY --from=deps /app/bun.lock ./bun.lock
COPY package.json bunfig.toml tsconfig.base.json ./
COPY apps/api apps/api
COPY packages/shared packages/shared

EXPOSE 4006
CMD ["bun", "apps/api/src/index.ts"]
