# Fullstack Monorepo Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Bun + Moon fullstack TypeScript scaffold for ZeaVis Edu beside the existing `Machine_Learning/` pipeline.

**Architecture:** Add a root Bun workspace managed by Moon with three projects: `apps/web`, `apps/api`, and `packages/shared`. The frontend is a React/Vite app with landing and dashboard routes; the backend is an Elysia API with health/status endpoints and Drizzle/PostgreSQL configuration that does not require a live database for startup.

**Tech Stack:** Bun, Moon, TypeScript, React, Vite, React Router, TanStack Query, Zustand, Tailwind CSS, shadcn/ui-style components, Elysia, Drizzle ORM, PostgreSQL.

---

## File Structure

Create these root files:

- `package.json`: Bun workspaces, package manager marker, root scripts delegating to Moon.
- `bunfig.toml`: Bun install/runtime defaults.
- `tsconfig.base.json`: shared strict TypeScript compiler options.
- `.env.example`: app ports and `DATABASE_URL` documentation.
- `.gitignore`: ignore JS/TS dependency, build, env, and Moon cache outputs while preserving existing ML files.
- `.moon/workspace.yml`: Moon workspace configuration.
- `.moon/toolchain.yml`: Bun/Node toolchain configuration.

Create `packages/shared`:

- `packages/shared/package.json`: package metadata and export paths.
- `packages/shared/tsconfig.json`: TypeScript config extending root base.
- `packages/shared/src/index.ts`: shared exports.
- `packages/shared/src/app-status.ts`: shared app status response type and factory.

Create `apps/api`:

- `apps/api/package.json`: API dependencies and scripts.
- `apps/api/tsconfig.json`: API TypeScript config.
- `apps/api/drizzle.config.ts`: Drizzle Kit config using `DATABASE_URL`.
- `apps/api/src/index.ts`: Elysia server entry.
- `apps/api/src/config/env.ts`: env helpers for port and database URL.
- `apps/api/src/routes/health.ts`: `/health` route.
- `apps/api/src/routes/status.ts`: `/api/v1/status` route.
- `apps/api/src/db/schema.ts`: minimal schema placeholder.
- `apps/api/src/db/client.ts`: Drizzle client factory that is not used at server boot.

Create `apps/web`:

- `apps/web/package.json`: frontend dependencies and scripts.
- `apps/web/tsconfig.json`: app TypeScript config.
- `apps/web/tsconfig.node.json`: Vite config TypeScript config.
- `apps/web/vite.config.ts`: Vite React config.
- `apps/web/index.html`: Vite HTML entry.
- `apps/web/postcss.config.js`: PostCSS config for Tailwind.
- `apps/web/tailwind.config.ts`: Tailwind content/theme config.
- `apps/web/src/main.tsx`: React root render.
- `apps/web/src/app.tsx`: providers and router wiring.
- `apps/web/src/index.css`: Tailwind layers and theme variables.
- `apps/web/src/lib/utils.ts`: `cn` utility.
- `apps/web/src/store/ui-store.ts`: small Zustand UI store.
- `apps/web/src/components/ui/button.tsx`: shadcn-style button.
- `apps/web/src/components/ui/card.tsx`: shadcn-style card.
- `apps/web/src/pages/landing-page.tsx`: landing route.
- `apps/web/src/pages/dashboard-page.tsx`: placeholder dashboard route.

Create Moon project files:

- `apps/web/moon.yml`: web tasks.
- `apps/api/moon.yml`: api tasks.
- `packages/shared/moon.yml`: shared tasks.

---

### Task 1: Root Workspace and Moon Configuration

**Files:**
- Create: `package.json`
- Create: `bunfig.toml`
- Create: `tsconfig.base.json`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `.moon/workspace.yml`
- Create: `.moon/toolchain.yml`

- [ ] **Step 1: Create root package configuration**

Create `package.json`:

```json
{
  "name": "zeavis-edu",
  "private": true,
  "packageManager": "bun@1.1.42",
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "scripts": {
    "dev": "moon run :dev",
    "build": "moon run :build",
    "typecheck": "moon run :typecheck"
  },
  "devDependencies": {
    "@moonrepo/cli": "^1.32.4",
    "typescript": "^5.6.3"
  }
}
```

- [ ] **Step 2: Create Bun config**

Create `bunfig.toml`:

```toml
[install]
exact = true
```

- [ ] **Step 3: Create shared TypeScript base config**

Create `tsconfig.base.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "allowJs": false,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "baseUrl": ".",
    "paths": {
      "@zeavis/shared": ["packages/shared/src/index.ts"],
      "@zeavis/shared/*": ["packages/shared/src/*"]
    }
  }
}
```

- [ ] **Step 4: Create environment example**

Create `.env.example`:

```dotenv
WEB_PORT=5173
API_PORT=3000
DATABASE_URL=postgres://postgres:postgres@localhost:5432/zeavis_edu
```

- [ ] **Step 5: Create root gitignore**

Create `.gitignore`:

```gitignore
node_modules/
.bun/
.moon/cache/
.env
.env.*
!.env.example

dist/
build/
coverage/
*.tsbuildinfo

.DS_Store
```

- [ ] **Step 6: Create Moon workspace config**

Create `.moon/workspace.yml`:

```yaml
projects:
  web: apps/web
  api: apps/api
  shared: packages/shared
```

- [ ] **Step 7: Create Moon toolchain config**

Create `.moon/toolchain.yml`:

```yaml
node:
  packageManager: bun
```

- [ ] **Step 8: Verify root config files are present**

Run: `test -f package.json && test -f .moon/workspace.yml && test -f tsconfig.base.json`

Expected: command exits with status 0 and no output.

- [ ] **Step 9: Commit root workspace config**

```bash
git add package.json bunfig.toml tsconfig.base.json .env.example .gitignore .moon/workspace.yml .moon/toolchain.yml
git commit -m "Add Bun and Moon workspace configuration"
```

---

### Task 2: Shared Package

**Files:**
- Create: `packages/shared/package.json`
- Create: `packages/shared/tsconfig.json`
- Create: `packages/shared/src/index.ts`
- Create: `packages/shared/src/app-status.ts`
- Create: `packages/shared/moon.yml`

- [ ] **Step 1: Create shared package metadata**

Create `packages/shared/package.json`:

```json
{
  "name": "@zeavis/shared",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "exports": {
    ".": "./src/index.ts",
    "./app-status": "./src/app-status.ts"
  },
  "scripts": {
    "typecheck": "tsc --project tsconfig.json"
  },
  "devDependencies": {
    "typescript": "^5.6.3"
  }
}
```

- [ ] **Step 2: Create shared TypeScript config**

Create `packages/shared/tsconfig.json`:

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "lib": ["ES2022"],
    "types": []
  },
  "include": ["src"]
}
```

- [ ] **Step 3: Create shared app status type**

Create `packages/shared/src/app-status.ts`:

```ts
export type AppStatus = {
  name: 'ZeaVis Edu';
  status: 'ok';
  version: string;
};

export function createAppStatus(version = '0.1.0'): AppStatus {
  return {
    name: 'ZeaVis Edu',
    status: 'ok',
    version,
  };
}
```

- [ ] **Step 4: Create shared package export**

Create `packages/shared/src/index.ts`:

```ts
export type { AppStatus } from './app-status';
export { createAppStatus } from './app-status';
```

- [ ] **Step 5: Create shared Moon tasks**

Create `packages/shared/moon.yml`:

```yaml
type: library
language: typescript

tasks:
  typecheck:
    command: bun run typecheck
    inputs:
      - src/**/*
      - tsconfig.json
      - package.json
```

- [ ] **Step 6: Run shared package typecheck after dependencies are installed**

Run after Task 5 Step 1 has installed dependencies: `bun --cwd packages/shared run typecheck`

Expected: TypeScript exits with status 0.

- [ ] **Step 7: Commit shared package**

```bash
git add packages/shared
git commit -m "Add shared TypeScript package"
```

---

### Task 3: Elysia API Scaffold

**Files:**
- Create: `apps/api/package.json`
- Create: `apps/api/tsconfig.json`
- Create: `apps/api/drizzle.config.ts`
- Create: `apps/api/src/index.ts`
- Create: `apps/api/src/config/env.ts`
- Create: `apps/api/src/routes/health.ts`
- Create: `apps/api/src/routes/status.ts`
- Create: `apps/api/src/db/schema.ts`
- Create: `apps/api/src/db/client.ts`
- Create: `apps/api/moon.yml`

- [ ] **Step 1: Create API package metadata**

Create `apps/api/package.json`:

```json
{
  "name": "@zeavis/api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "bun --watch src/index.ts",
    "start": "bun src/index.ts",
    "typecheck": "tsc --project tsconfig.json",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate"
  },
  "dependencies": {
    "@zeavis/shared": "workspace:*",
    "drizzle-orm": "^0.36.4",
    "elysia": "^1.1.25",
    "postgres": "^3.4.5"
  },
  "devDependencies": {
    "drizzle-kit": "^0.27.1",
    "typescript": "^5.6.3"
  }
}
```

- [ ] **Step 2: Create API TypeScript config**

Create `apps/api/tsconfig.json`:

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "lib": ["ES2022"],
    "types": ["bun"],
    "noEmit": true
  },
  "include": ["src", "drizzle.config.ts"]
}
```

- [ ] **Step 3: Create API environment helper**

Create `apps/api/src/config/env.ts`:

```ts
export const env = {
  port: Number(Bun.env.API_PORT ?? 3000),
  databaseUrl: Bun.env.DATABASE_URL,
};
```

- [ ] **Step 4: Create health route**

Create `apps/api/src/routes/health.ts`:

```ts
import { Elysia } from 'elysia';

export const healthRoutes = new Elysia().get('/health', () => ({
  status: 'ok' as const,
}));
```

- [ ] **Step 5: Create status route using shared package**

Create `apps/api/src/routes/status.ts`:

```ts
import { createAppStatus } from '@zeavis/shared';
import { Elysia } from 'elysia';

export const statusRoutes = new Elysia({ prefix: '/api/v1' }).get('/status', () =>
  createAppStatus(),
);
```

- [ ] **Step 6: Create Drizzle schema placeholder**

Create `apps/api/src/db/schema.ts`:

```ts
import { pgTable, timestamp, uuid, varchar } from 'drizzle-orm/pg-core';

export const appEvents = pgTable('app_events', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: varchar('name', { length: 120 }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
```

- [ ] **Step 7: Create Drizzle client factory**

Create `apps/api/src/db/client.ts`:

```ts
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { env } from '../config/env';
import * as schema from './schema';

export function createDbClient() {
  if (!env.databaseUrl) {
    throw new Error('DATABASE_URL is required to create a database client');
  }

  const client = postgres(env.databaseUrl);
  return drizzle(client, { schema });
}
```

- [ ] **Step 8: Create Drizzle config**

Create `apps/api/drizzle.config.ts`:

```ts
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL ?? 'postgres://postgres:postgres@localhost:5432/zeavis_edu',
  },
});
```

- [ ] **Step 9: Create Elysia server entry**

Create `apps/api/src/index.ts`:

```ts
import { Elysia } from 'elysia';
import { env } from './config/env';
import { healthRoutes } from './routes/health';
import { statusRoutes } from './routes/status';

const app = new Elysia().use(healthRoutes).use(statusRoutes).listen(env.port);

console.log(`ZeaVis Edu API running at http://${app.server?.hostname}:${app.server?.port}`);

export type App = typeof app;
```

- [ ] **Step 10: Create API Moon tasks**

Create `apps/api/moon.yml`:

```yaml
type: application
language: typescript

tasks:
  dev:
    command: bun run dev
    local: true
  build:
    command: bun build src/index.ts --outdir dist --target bun
    inputs:
      - src/**/*
      - package.json
      - tsconfig.json
      - drizzle.config.ts
    outputs:
      - dist
  typecheck:
    command: bun run typecheck
    inputs:
      - src/**/*
      - package.json
      - tsconfig.json
      - drizzle.config.ts
```

- [ ] **Step 11: Commit API scaffold**

```bash
git add apps/api
git commit -m "Add Elysia API scaffold"
```

---

### Task 4: React Web Scaffold

**Files:**
- Create: `apps/web/package.json`
- Create: `apps/web/tsconfig.json`
- Create: `apps/web/tsconfig.node.json`
- Create: `apps/web/vite.config.ts`
- Create: `apps/web/index.html`
- Create: `apps/web/postcss.config.js`
- Create: `apps/web/tailwind.config.ts`
- Create: `apps/web/src/main.tsx`
- Create: `apps/web/src/app.tsx`
- Create: `apps/web/src/index.css`
- Create: `apps/web/src/lib/utils.ts`
- Create: `apps/web/src/store/ui-store.ts`
- Create: `apps/web/src/components/ui/button.tsx`
- Create: `apps/web/src/components/ui/card.tsx`
- Create: `apps/web/src/pages/landing-page.tsx`
- Create: `apps/web/src/pages/dashboard-page.tsx`
- Create: `apps/web/moon.yml`

- [ ] **Step 1: Create web package metadata**

Create `apps/web/package.json`:

```json
{
  "name": "@zeavis/web",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "tsc --project tsconfig.json && vite build",
    "preview": "vite preview --host 0.0.0.0",
    "typecheck": "tsc --project tsconfig.json"
  },
  "dependencies": {
    "@tanstack/react-query": "^5.59.16",
    "@vitejs/plugin-react": "^4.3.3",
    "@zeavis/shared": "workspace:*",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.1",
    "lucide-react": "^0.468.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.28.0",
    "tailwind-merge": "^2.5.4",
    "zustand": "^5.0.1"
  },
  "devDependencies": {
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.15",
    "typescript": "^5.6.3",
    "vite": "^6.0.1"
  }
}
```

- [ ] **Step 2: Create web TypeScript config**

Create `apps/web/tsconfig.json`:

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "types": ["vite/client"],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@zeavis/shared": ["../../packages/shared/src/index.ts"],
      "@zeavis/shared/*": ["../../packages/shared/src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

- [ ] **Step 3: Create Vite TypeScript config**

Create `apps/web/tsconfig.node.json`:

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "composite": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "types": ["node"]
  },
  "include": ["vite.config.ts", "tailwind.config.ts"]
}
```

- [ ] **Step 4: Create Vite config**

Create `apps/web/vite.config.ts`:

```ts
import react from '@vitejs/plugin-react';
import path from 'node:path';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

- [ ] **Step 5: Create Vite HTML entry**

Create `apps/web/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>ZeaVis Edu</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 6: Create PostCSS config**

Create `apps/web/postcss.config.js`:

```js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

- [ ] **Step 7: Create Tailwind config**

Create `apps/web/tailwind.config.ts`:

```ts
import type { Config } from 'tailwindcss';

export default {
  darkMode: ['class'],
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        border: 'hsl(var(--border))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        muted: {
          DEFAULT: 'hsl(var(--muted))',
          foreground: 'hsl(var(--muted-foreground))',
        },
        card: {
          DEFAULT: 'hsl(var(--card))',
          foreground: 'hsl(var(--card-foreground))',
        },
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
    },
  },
  plugins: [],
} satisfies Config;
```

- [ ] **Step 8: Create frontend CSS theme**

Create `apps/web/src/index.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 48 60% 97%;
    --foreground: 156 26% 12%;
    --card: 0 0% 100%;
    --card-foreground: 156 26% 12%;
    --primary: 142 60% 32%;
    --primary-foreground: 0 0% 100%;
    --muted: 84 35% 90%;
    --muted-foreground: 156 12% 35%;
    --border: 84 24% 82%;
    --radius: 1rem;
  }

  * {
    @apply border-border;
  }

  body {
    @apply bg-background text-foreground antialiased;
    font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }
}
```

- [ ] **Step 9: Create utility helper**

Create `apps/web/src/lib/utils.ts`:

```ts
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

- [ ] **Step 10: Create UI store**

Create `apps/web/src/store/ui-store.ts`:

```ts
import { create } from 'zustand';

type UiState = {
  dashboardCompact: boolean;
  toggleDashboardCompact: () => void;
};

export const useUiStore = create<UiState>((set) => ({
  dashboardCompact: false,
  toggleDashboardCompact: () =>
    set((state) => ({ dashboardCompact: !state.dashboardCompact })),
}));
```

- [ ] **Step 11: Create Button component**

Create `apps/web/src/components/ui/button.tsx`:

```tsx
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import type { ButtonHTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        outline: 'border border-border bg-transparent hover:bg-muted',
        ghost: 'hover:bg-muted',
      },
      size: {
        default: 'h-10 px-4 py-2',
        lg: 'h-12 rounded-lg px-6',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  },
);

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean;
  };

export function Button({ className, variant, size, asChild = false, ...props }: ButtonProps) {
  const Comp = asChild ? Slot : 'button';

  return <Comp className={cn(buttonVariants({ variant, size, className }))} {...props} />;
}
```

- [ ] **Step 12: Add missing Radix Slot dependency**

Modify `apps/web/package.json` dependencies to include `@radix-ui/react-slot`:

```json
"dependencies": {
  "@radix-ui/react-slot": "^1.1.0",
  "@tanstack/react-query": "^5.59.16",
  "@vitejs/plugin-react": "^4.3.3",
  "@zeavis/shared": "workspace:*",
  "class-variance-authority": "^0.7.0",
  "clsx": "^2.1.1",
  "lucide-react": "^0.468.0",
  "react": "^18.3.1",
  "react-dom": "^18.3.1",
  "react-router-dom": "^6.28.0",
  "tailwind-merge": "^2.5.4",
  "zustand": "^5.0.1"
}
```

- [ ] **Step 13: Create Card component**

Create `apps/web/src/components/ui/card.tsx`:

```tsx
import type { HTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('rounded-lg border bg-card text-card-foreground shadow-sm', className)} {...props} />;
}

export function CardHeader({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('flex flex-col space-y-1.5 p-6', className)} {...props} />;
}

export function CardTitle({ className, ...props }: HTMLAttributes<HTMLHeadingElement>) {
  return <h3 className={cn('text-2xl font-semibold leading-none tracking-tight', className)} {...props} />;
}

export function CardDescription({ className, ...props }: HTMLAttributes<HTMLParagraphElement>) {
  return <p className={cn('text-sm text-muted-foreground', className)} {...props} />;
}

export function CardContent({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('p-6 pt-0', className)} {...props} />;
}
```

- [ ] **Step 14: Create landing page**

Create `apps/web/src/pages/landing-page.tsx`:

```tsx
import { ArrowRight, Leaf, ShieldCheck, Sprout } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

const features = [
  {
    icon: Leaf,
    title: 'Deteksi penyakit daun jagung',
    description: 'Fondasi aplikasi siap untuk integrasi model klasifikasi ZeaVis Edu.',
  },
  {
    icon: ShieldCheck,
    title: 'Edukasi berbasis data',
    description: 'Materi dan hasil analisis dapat dikembangkan di atas dashboard awal.',
  },
  {
    icon: Sprout,
    title: 'Siap tumbuh bersama produk',
    description: 'Monorepo memisahkan frontend, backend, dan shared types dengan jelas.',
  },
];

export function LandingPage() {
  return (
    <main className="min-h-screen overflow-hidden">
      <section className="mx-auto flex min-h-screen w-full max-w-6xl flex-col px-6 py-10">
        <nav className="flex items-center justify-between">
          <div className="flex items-center gap-3 font-semibold">
            <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-primary text-primary-foreground">
              <Leaf className="h-5 w-5" />
            </div>
            ZeaVis Edu
          </div>
          <Button asChild variant="ghost">
            <Link to="/dashboard">Dashboard</Link>
          </Button>
        </nav>

        <div className="grid flex-1 items-center gap-10 py-20 lg:grid-cols-[1.1fr_0.9fr]">
          <div className="space-y-8">
            <div className="inline-flex rounded-full border bg-card px-4 py-2 text-sm text-muted-foreground">
              Platform edukasi kesehatan tanaman jagung
            </div>
            <div className="space-y-5">
              <h1 className="max-w-3xl text-5xl font-bold tracking-tight sm:text-6xl">
                Belajar mengenali penyakit daun jagung dengan alur digital yang rapi.
              </h1>
              <p className="max-w-2xl text-lg leading-8 text-muted-foreground">
                Scaffold ini menyiapkan fondasi aplikasi ZeaVis Edu untuk antarmuka edukasi,
                API, dan integrasi model machine learning berikutnya.
              </p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row">
              <Button asChild size="lg">
                <Link to="/dashboard">
                  Buka Dashboard <ArrowRight className="ml-2 h-4 w-4" />
                </Link>
              </Button>
              <Button asChild size="lg" variant="outline">
                <a href="https://elysiajs.com" target="_blank" rel="noreferrer">
                  Lihat Stack API
                </a>
              </Button>
            </div>
          </div>

          <div className="grid gap-4">
            {features.map((feature) => (
              <Card key={feature.title} className="bg-card/80 backdrop-blur">
                <CardHeader className="flex-row items-start gap-4 space-y-0">
                  <div className="rounded-2xl bg-muted p-3 text-primary">
                    <feature.icon className="h-6 w-6" />
                  </div>
                  <div>
                    <CardTitle className="text-xl">{feature.title}</CardTitle>
                    <CardDescription className="mt-2 leading-6">{feature.description}</CardDescription>
                  </div>
                </CardHeader>
              </Card>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
```

- [ ] **Step 15: Create dashboard page**

Create `apps/web/src/pages/dashboard-page.tsx`:

```tsx
import { BookOpen, History, Leaf, LayoutDashboard } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { useUiStore } from '@/store/ui-store';

const dashboardCards = [
  {
    icon: Leaf,
    title: 'Deteksi Penyakit',
    description: 'Area ini akan menjadi pintu masuk analisis gambar daun jagung.',
  },
  {
    icon: History,
    title: 'Riwayat Analisis',
    description: 'Hasil deteksi sebelumnya akan ditampilkan saat fitur data tersedia.',
  },
  {
    icon: BookOpen,
    title: 'Materi Edukasi',
    description: 'Konten edukasi penyakit jagung akan terhubung ke modul pembelajaran.',
  },
];

export function DashboardPage() {
  const { dashboardCompact, toggleDashboardCompact } = useUiStore();

  return (
    <main className="min-h-screen px-6 py-8">
      <div className="mx-auto max-w-6xl space-y-8">
        <header className="flex flex-col gap-4 rounded-3xl border bg-card p-6 shadow-sm md:flex-row md:items-center md:justify-between">
          <div className="space-y-2">
            <div className="flex items-center gap-2 text-sm font-medium text-primary">
              <LayoutDashboard className="h-4 w-4" /> Dashboard
            </div>
            <h1 className="text-3xl font-bold tracking-tight">ZeaVis Edu Workspace</h1>
            <p className="text-muted-foreground">
              Placeholder awal untuk fitur deteksi, riwayat analisis, dan edukasi.
            </p>
          </div>
          <div className="flex gap-3">
            <Button variant="outline" onClick={toggleDashboardCompact}>
              {dashboardCompact ? 'Mode Nyaman' : 'Mode Ringkas'}
            </Button>
            <Button asChild>
              <Link to="/">Kembali</Link>
            </Button>
          </div>
        </header>

        <section className={dashboardCompact ? 'grid gap-4 md:grid-cols-3' : 'grid gap-6 md:grid-cols-3'}>
          {dashboardCards.map((item) => (
            <Card key={item.title}>
              <CardHeader>
                <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-muted text-primary">
                  <item.icon className="h-6 w-6" />
                </div>
                <CardTitle className="text-xl">{item.title}</CardTitle>
                <CardDescription className="leading-6">{item.description}</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="rounded-2xl border border-dashed p-4 text-sm text-muted-foreground">
                  Belum ada data. Fitur akan dihubungkan pada iterasi berikutnya.
                </div>
              </CardContent>
            </Card>
          ))}
        </section>
      </div>
    </main>
  );
}
```

- [ ] **Step 16: Create app router and providers**

Create `apps/web/src/app.tsx`:

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createBrowserRouter, RouterProvider } from 'react-router-dom';
import { DashboardPage } from '@/pages/dashboard-page';
import { LandingPage } from '@/pages/landing-page';

const queryClient = new QueryClient();

const router = createBrowserRouter([
  {
    path: '/',
    element: <LandingPage />,
  },
  {
    path: '/dashboard',
    element: <DashboardPage />,
  },
]);

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  );
}
```

- [ ] **Step 17: Create React root entry**

Create `apps/web/src/main.tsx`:

```tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './app';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
```

- [ ] **Step 18: Create web Moon tasks**

Create `apps/web/moon.yml`:

```yaml
type: application
language: typescript

tasks:
  dev:
    command: bun run dev
    local: true
  build:
    command: bun run build
    inputs:
      - src/**/*
      - index.html
      - package.json
      - tsconfig.json
      - tsconfig.node.json
      - vite.config.ts
      - tailwind.config.ts
      - postcss.config.js
    outputs:
      - dist
  typecheck:
    command: bun run typecheck
    inputs:
      - src/**/*
      - package.json
      - tsconfig.json
      - tsconfig.node.json
      - vite.config.ts
      - tailwind.config.ts
```

- [ ] **Step 19: Commit web scaffold**

```bash
git add apps/web
git commit -m "Add React web scaffold"
```

---

### Task 5: Install Dependencies and Verify Builds

**Files:**
- Create: `bun.lockb` or `bun.lock`
- Modify: dependency lockfile generated by Bun

- [ ] **Step 1: Install dependencies**

Run: `bun install`

Expected: Bun installs dependencies and creates a lockfile.

- [ ] **Step 2: Run shared typecheck**

Run: `bun --cwd packages/shared run typecheck`

Expected: command exits with status 0.

- [ ] **Step 3: Run API typecheck**

Run: `bun --cwd apps/api run typecheck`

Expected: command exits with status 0.

- [ ] **Step 4: Run API build**

Run: `bun --cwd apps/api build src/index.ts --outdir dist --target bun`

Expected: Bun writes compiled output to `apps/api/dist` and exits with status 0.

- [ ] **Step 5: Run web typecheck**

Run: `bun --cwd apps/web run typecheck`

Expected: command exits with status 0.

- [ ] **Step 6: Run web build**

Run: `bun --cwd apps/web run build`

Expected: Vite writes production output to `apps/web/dist` and exits with status 0.

- [ ] **Step 7: Verify API health endpoint manually**

Run server in one terminal:

```bash
API_PORT=3000 bun --cwd apps/api run start
```

In another terminal, run:

```bash
curl -s http://localhost:3000/health
```

Expected response:

```json
{"status":"ok"}
```

Stop the API server after verifying.

- [ ] **Step 8: Verify API status endpoint manually**

Run while the API server is still running:

```bash
curl -s http://localhost:3000/api/v1/status
```

Expected response:

```json
{"name":"ZeaVis Edu","status":"ok","version":"0.1.0"}
```

- [ ] **Step 9: Commit dependency lockfile and build fixes**

```bash
git add bun.lockb bun.lock package.json apps packages .moon .env.example .gitignore tsconfig.base.json
git commit -m "Verify fullstack scaffold builds"
```

If the repository uses `bun.lock` instead of `bun.lockb`, only add the generated lockfile that exists.

---

### Task 6: Final Project Documentation Update

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read existing `CLAUDE.md`**

Run: `sed -n '1,220p' CLAUDE.md`

Expected: output shows the existing ML-focused project guidance.

- [ ] **Step 2: Add fullstack command section to `CLAUDE.md`**

Append this section after the existing common commands section:

```markdown
## Fullstack app commands

The TypeScript application scaffold lives at the repository root and uses Bun workspaces with Moon tasks.

Install dependencies:

```bash
bun install
```

Run all development tasks through Moon:

```bash
bun run dev
```

Run type checks:

```bash
bun run typecheck
```

Run production builds:

```bash
bun run build
```

Run the API directly:

```bash
API_PORT=3000 bun --cwd apps/api run start
```

Run the web app directly:

```bash
bun --cwd apps/web run dev
```
```

- [ ] **Step 3: Add fullstack architecture note to `CLAUDE.md`**

Append this section after the high-level architecture section:

```markdown
## Fullstack application architecture

The root TypeScript workspace is a Bun + Moon monorepo:

- `apps/web/` contains the React + Vite + TypeScript frontend with React Router, TanStack Query, Zustand, Tailwind, and shadcn/ui-style components.
- `apps/api/` contains the Elysia backend with health/status routes and Drizzle/PostgreSQL configuration.
- `packages/shared/` contains shared TypeScript types and utilities consumed by both apps.

The backend reads `DATABASE_URL` for Drizzle/PostgreSQL, but the initial health/status endpoints do not require a live database connection.
```

- [ ] **Step 4: Run final verification commands**

Run:

```bash
bun run typecheck
bun run build
```

Expected: both commands exit with status 0.

- [ ] **Step 5: Commit documentation update**

```bash
git add CLAUDE.md
git commit -m "Document fullstack app commands"
```

---

## Self-Review

- Spec coverage: the plan covers Bun workspaces, Moon config, `apps/web`, `apps/api`, `packages/shared`, `.env.example`, Drizzle config without mandatory DB startup, landing/dashboard UI, health/status endpoints, and verification.
- Placeholder scan: no TBD/TODO placeholders are present; deferred features are explicitly listed in the design and not implemented.
- Type consistency: `AppStatus`, `createAppStatus`, route paths, package names, and project paths are consistent across tasks.
- Known execution note: Task 4 requires adding `@radix-ui/react-slot` because the shadcn-style `Button` uses `Slot` for `asChild` support.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
