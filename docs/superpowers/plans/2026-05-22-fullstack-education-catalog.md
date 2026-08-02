# Fullstack Education Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a PostgreSQL-backed ZeaVis Edu education catalog with dashboard, disease detail pages, manual classification submission, history, and statistics.

**Architecture:** Shared TypeScript types define the disease/classification contract. The Elysia API exposes `/api/v1` catalog, classification, and dashboard endpoints backed by Drizzle/PostgreSQL. The React app uses TanStack Query and React Router to render landing, dashboard, catalog, detail, and manual classification flows.

**Tech Stack:** Bun workspaces, Moon tasks, TypeScript, Elysia, Drizzle ORM, PostgreSQL, React, Vite, React Router, TanStack Query, Tailwind CSS.

---

## File structure

- Modify `packages/shared/src/app-status.ts`: keep existing app status helper.
- Create `packages/shared/src/diseases.ts`: labels, slugs, risk levels, domain types, seed records, mapping helpers.
- Create `packages/shared/src/classifications.ts`: manual classification request/response and dashboard summary types.
- Modify `packages/shared/src/index.ts`: export new shared modules.
- Modify `apps/api/src/db/schema.ts`: add `diseaseCatalog` and `manualClassifications` Drizzle tables.
- Create `apps/api/src/db/seed-data.ts`: map shared seed catalog to insertable database rows.
- Create `apps/api/src/lib/http-errors.ts`: small JSON error helpers.
- Create `apps/api/src/routes/diseases.ts`: catalog and detail endpoints.
- Create `apps/api/src/routes/classifications.ts`: manual submission and history endpoints.
- Create `apps/api/src/routes/dashboard.ts`: summary endpoint.
- Modify `apps/api/src/index.ts`: register new routes.
- Create `apps/web/src/lib/api-client.ts`: typed fetch helpers.
- Create `apps/web/src/components/risk-badge.tsx`: reusable risk badge.
- Create `apps/web/src/components/disease-card.tsx`: reusable disease card.
- Create `apps/web/src/components/manual-classification-form.tsx`: submission form.
- Create `apps/web/src/pages/catalog-page.tsx`: searchable/filterable catalog.
- Create `apps/web/src/pages/disease-detail-page.tsx`: disease detail page.
- Modify `apps/web/src/pages/dashboard-page.tsx`: data-backed summary/history/manual form.
- Modify `apps/web/src/pages/landing-page.tsx`: product-ready landing content.
- Modify `apps/web/src/app.tsx`: add routes.

---

### Task 1: Shared disease domain

**Files:**
- Create: `packages/shared/src/diseases.ts`
- Create: `packages/shared/src/classifications.ts`
- Modify: `packages/shared/src/index.ts`

- [ ] **Step 1: Create disease domain types and seed records**

Write `packages/shared/src/diseases.ts`:

```ts
export const diseaseLabels = ['Bercak Daun', 'Hawar Daun', 'Karat Daun', 'Daun Sehat'] as const;
export type DiseaseLabel = (typeof diseaseLabels)[number];

export const diseaseSlugs = ['bercak-daun', 'hawar-daun', 'karat-daun', 'daun-sehat'] as const;
export type DiseaseSlug = (typeof diseaseSlugs)[number];

export const riskLevels = ['low', 'medium', 'high'] as const;
export type RiskLevel = (typeof riskLevels)[number];

export type DiseaseCatalogItem = {
  slug: DiseaseSlug;
  label: DiseaseLabel;
  commonName: string;
  summary: string;
  description: string;
  symptoms: string[];
  recommendations: string[];
  riskLevel: RiskLevel;
  accentColor: string;
  displayOrder: number;
};

export const diseaseCatalogSeed: DiseaseCatalogItem[] = [
  {
    slug: 'bercak-daun',
    label: 'Bercak Daun',
    commonName: 'Gray Leaf Spot',
    summary: 'Penyakit jamur yang membentuk bercak abu-abu kecokelatan memanjang pada daun jagung.',
    description:
      'Bercak Daun biasanya berkembang pada kondisi lembap dan dapat mengurangi area fotosintesis jika tidak dipantau sejak awal.',
    symptoms: ['Bercak memanjang berwarna abu-abu kecokelatan', 'Lesi dibatasi tulang daun', 'Daun tampak mengering pada infeksi berat'],
    recommendations: ['Pantau kelembapan lahan', 'Gunakan varietas tahan bila tersedia', 'Bersihkan sisa tanaman terinfeksi'],
    riskLevel: 'medium',
    accentColor: 'slate',
    displayOrder: 1,
  },
  {
    slug: 'hawar-daun',
    label: 'Hawar Daun',
    commonName: 'Leaf Blight',
    summary: 'Penyakit hawar yang menimbulkan area nekrotik luas dan dapat menyebar cepat pada daun.',
    description:
      'Hawar Daun perlu ditangani serius karena gejalanya dapat meluas dan menurunkan kesehatan tanaman secara signifikan.',
    symptoms: ['Bercak lonjong besar berwarna cokelat', 'Tepi bercak terlihat basah atau menguning', 'Daun mengering dari area infeksi'],
    recommendations: ['Pisahkan tanaman dengan gejala berat', 'Perbaiki sirkulasi udara tanaman', 'Konsultasikan penggunaan fungisida sesuai rekomendasi setempat'],
    riskLevel: 'high',
    accentColor: 'amber',
    displayOrder: 2,
  },
  {
    slug: 'karat-daun',
    label: 'Karat Daun',
    commonName: 'Common Rust',
    summary: 'Infeksi jamur yang terlihat sebagai pustula kecil berwarna jingga hingga cokelat pada permukaan daun.',
    description:
      'Karat Daun sering mudah dikenali dari pustula seperti serbuk karat dan perlu dipantau agar tidak menyebar di lahan.',
    symptoms: ['Bintik/pustula jingga kecokelatan', 'Serbuk spora menempel di permukaan daun', 'Daun menguning pada serangan lanjut'],
    recommendations: ['Pantau daun bagian bawah dan tengah', 'Kurangi kelembapan berlebih', 'Gunakan benih atau varietas yang lebih tahan'],
    riskLevel: 'medium',
    accentColor: 'orange',
    displayOrder: 3,
  },
  {
    slug: 'daun-sehat',
    label: 'Daun Sehat',
    commonName: 'Healthy Leaf',
    summary: 'Daun jagung tampak normal tanpa gejala utama penyakit target ZeaVis Edu.',
    description:
      'Daun sehat tetap perlu dipantau berkala karena kondisi lahan dapat berubah dan gejala awal sering terlihat samar.',
    symptoms: ['Warna hijau merata', 'Tidak ada lesi atau pustula', 'Bentuk daun normal dan tidak mengering'],
    recommendations: ['Lanjutkan pemantauan rutin', 'Jaga sanitasi lahan', 'Catat perubahan visual sejak dini'],
    riskLevel: 'low',
    accentColor: 'emerald',
    displayOrder: 4,
  },
];

export function isDiseaseSlug(value: string): value is DiseaseSlug {
  return diseaseSlugs.includes(value as DiseaseSlug);
}

export function getDiseaseBySlug(slug: string): DiseaseCatalogItem | undefined {
  return diseaseCatalogSeed.find((item) => item.slug === slug);
}
```

- [ ] **Step 2: Create classification and dashboard shared types**

Write `packages/shared/src/classifications.ts`:

```ts
import type { DiseaseCatalogItem, DiseaseSlug, RiskLevel } from './diseases';

export type ManualClassificationRequest = {
  diseaseSlug: DiseaseSlug;
  observation: string;
  location: string;
};

export type ManualClassificationRecord = {
  id: string;
  diseaseSlug: DiseaseSlug;
  observation: string;
  location: string;
  createdAt: string;
  disease: DiseaseCatalogItem;
};

export type DashboardSummary = {
  diseaseCount: number;
  classificationCount: number;
  latestClassification: ManualClassificationRecord | null;
  riskDistribution: Record<RiskLevel, number>;
};
```

- [ ] **Step 3: Export shared modules**

Modify `packages/shared/src/index.ts` to:

```ts
export type { AppStatus } from './app-status';
export { createAppStatus } from './app-status';
export type { DiseaseCatalogItem, DiseaseLabel, DiseaseSlug, RiskLevel } from './diseases';
export { diseaseCatalogSeed, diseaseLabels, diseaseSlugs, getDiseaseBySlug, isDiseaseSlug, riskLevels } from './diseases';
export type { DashboardSummary, ManualClassificationRecord, ManualClassificationRequest } from './classifications';
```

- [ ] **Step 4: Verify shared package typecheck**

Run: `bun --filter @zeavis/shared run typecheck`

Expected: TypeScript exits with code 0.

- [ ] **Step 5: Commit**

```bash
git add packages/shared/src/diseases.ts packages/shared/src/classifications.ts packages/shared/src/index.ts
git commit -m "Add shared education catalog domain"
```

---

### Task 2: Database schema and API routes

**Files:**
- Modify: `apps/api/src/db/schema.ts`
- Create: `apps/api/src/db/seed-data.ts`
- Create: `apps/api/src/lib/http-errors.ts`
- Create: `apps/api/src/routes/diseases.ts`
- Create: `apps/api/src/routes/classifications.ts`
- Create: `apps/api/src/routes/dashboard.ts`
- Modify: `apps/api/src/index.ts`

- [ ] **Step 1: Replace database schema**

Write `apps/api/src/db/schema.ts`:

```ts
import { pgTable, text, timestamp, uuid, varchar, integer } from 'drizzle-orm/pg-core';

export const diseaseCatalog = pgTable('disease_catalog', {
  slug: varchar('slug', { length: 80 }).primaryKey(),
  label: varchar('label', { length: 80 }).notNull(),
  commonName: varchar('common_name', { length: 120 }).notNull(),
  summary: text('summary').notNull(),
  description: text('description').notNull(),
  symptoms: text('symptoms').array().notNull(),
  recommendations: text('recommendations').array().notNull(),
  riskLevel: varchar('risk_level', { length: 20 }).notNull(),
  accentColor: varchar('accent_color', { length: 40 }).notNull(),
  displayOrder: integer('display_order').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const manualClassifications = pgTable('manual_classifications', {
  id: uuid('id').primaryKey().defaultRandom(),
  diseaseSlug: varchar('disease_slug', { length: 80 }).notNull().references(() => diseaseCatalog.slug),
  observation: text('observation').notNull(),
  location: varchar('location', { length: 160 }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
```

- [ ] **Step 2: Add seed data mapper**

Write `apps/api/src/db/seed-data.ts`:

```ts
import { diseaseCatalogSeed } from '@zeavis/shared';

export const diseaseCatalogRows = diseaseCatalogSeed.map((item) => ({
  slug: item.slug,
  label: item.label,
  commonName: item.commonName,
  summary: item.summary,
  description: item.description,
  symptoms: item.symptoms,
  recommendations: item.recommendations,
  riskLevel: item.riskLevel,
  accentColor: item.accentColor,
  displayOrder: item.displayOrder,
}));
```

- [ ] **Step 3: Add HTTP error helpers**

Write `apps/api/src/lib/http-errors.ts`:

```ts
export function badRequest(message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status: 400,
    headers: { 'content-type': 'application/json' },
  });
}

export function notFound(message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status: 404,
    headers: { 'content-type': 'application/json' },
  });
}

export function serviceUnavailable(message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status: 503,
    headers: { 'content-type': 'application/json' },
  });
}
```

- [ ] **Step 4: Add diseases route**

Write `apps/api/src/routes/diseases.ts`:

```ts
import type { DiseaseCatalogItem, DiseaseSlug, RiskLevel } from '@zeavis/shared';
import { asc, eq } from 'drizzle-orm';
import { Elysia } from 'elysia';
import { createDbClient } from '../db/client';
import { diseaseCatalog } from '../db/schema';
import { notFound, serviceUnavailable } from '../lib/http-errors';

function toDisease(row: typeof diseaseCatalog.$inferSelect): DiseaseCatalogItem {
  return {
    slug: row.slug as DiseaseSlug,
    label: row.label as DiseaseCatalogItem['label'],
    commonName: row.commonName,
    summary: row.summary,
    description: row.description,
    symptoms: row.symptoms,
    recommendations: row.recommendations,
    riskLevel: row.riskLevel as RiskLevel,
    accentColor: row.accentColor,
    displayOrder: row.displayOrder,
  };
}

export const diseaseRoutes = new Elysia({ prefix: '/api/v1' })
  .get('/diseases', async () => {
    try {
      const db = createDbClient();
      const rows = await db.select().from(diseaseCatalog).orderBy(asc(diseaseCatalog.displayOrder));
      return rows.map(toDisease);
    } catch {
      return serviceUnavailable('Database is unavailable');
    }
  })
  .get('/diseases/:slug', async ({ params }) => {
    try {
      const db = createDbClient();
      const [row] = await db.select().from(diseaseCatalog).where(eq(diseaseCatalog.slug, params.slug)).limit(1);
      if (!row) {
        return notFound('Disease was not found');
      }
      return toDisease(row);
    } catch {
      return serviceUnavailable('Database is unavailable');
    }
  });
```

- [ ] **Step 5: Add classifications route**

Write `apps/api/src/routes/classifications.ts`:

```ts
import type { DiseaseCatalogItem, DiseaseSlug, ManualClassificationRecord, RiskLevel } from '@zeavis/shared';
import { desc, eq } from 'drizzle-orm';
import { Elysia } from 'elysia';
import { createDbClient } from '../db/client';
import { diseaseCatalog, manualClassifications } from '../db/schema';
import { badRequest, serviceUnavailable } from '../lib/http-errors';

function toRecord(row: { manual_classifications: typeof manualClassifications.$inferSelect; disease_catalog: typeof diseaseCatalog.$inferSelect }): ManualClassificationRecord {
  return {
    id: row.manual_classifications.id,
    diseaseSlug: row.manual_classifications.diseaseSlug as DiseaseSlug,
    observation: row.manual_classifications.observation,
    location: row.manual_classifications.location,
    createdAt: row.manual_classifications.createdAt.toISOString(),
    disease: {
      slug: row.disease_catalog.slug as DiseaseSlug,
      label: row.disease_catalog.label as DiseaseCatalogItem['label'],
      commonName: row.disease_catalog.commonName,
      summary: row.disease_catalog.summary,
      description: row.disease_catalog.description,
      symptoms: row.disease_catalog.symptoms,
      recommendations: row.disease_catalog.recommendations,
      riskLevel: row.disease_catalog.riskLevel as RiskLevel,
      accentColor: row.disease_catalog.accentColor,
      displayOrder: row.disease_catalog.displayOrder,
    },
  };
}

export const classificationRoutes = new Elysia({ prefix: '/api/v1' })
  .get('/classifications/manual', async () => {
    try {
      const db = createDbClient();
      const rows = await db
        .select()
        .from(manualClassifications)
        .innerJoin(diseaseCatalog, eq(manualClassifications.diseaseSlug, diseaseCatalog.slug))
        .orderBy(desc(manualClassifications.createdAt))
        .limit(20);
      return rows.map(toRecord);
    } catch {
      return serviceUnavailable('Database is unavailable');
    }
  })
  .post('/classifications/manual', async ({ body }) => {
    const payload = body as { diseaseSlug?: string; observation?: string; location?: string };
    if (!payload.diseaseSlug || !payload.observation || !payload.location) {
      return badRequest('diseaseSlug, observation, and location are required');
    }

    try {
      const db = createDbClient();
      const [disease] = await db.select().from(diseaseCatalog).where(eq(diseaseCatalog.slug, payload.diseaseSlug)).limit(1);
      if (!disease) {
        return badRequest('diseaseSlug is not registered in the catalog');
      }

      const [created] = await db
        .insert(manualClassifications)
        .values({ diseaseSlug: payload.diseaseSlug, observation: payload.observation, location: payload.location })
        .returning();

      return {
        id: created.id,
        diseaseSlug: created.diseaseSlug as DiseaseSlug,
        observation: created.observation,
        location: created.location,
        createdAt: created.createdAt.toISOString(),
        disease: {
          slug: disease.slug as DiseaseSlug,
          label: disease.label as DiseaseCatalogItem['label'],
          commonName: disease.commonName,
          summary: disease.summary,
          description: disease.description,
          symptoms: disease.symptoms,
          recommendations: disease.recommendations,
          riskLevel: disease.riskLevel as RiskLevel,
          accentColor: disease.accentColor,
          displayOrder: disease.displayOrder,
        },
      } satisfies ManualClassificationRecord;
    } catch {
      return serviceUnavailable('Database is unavailable');
    }
  });
```

- [ ] **Step 6: Add dashboard route**

Write `apps/api/src/routes/dashboard.ts`:

```ts
import type { DashboardSummary, DiseaseCatalogItem, DiseaseSlug, ManualClassificationRecord, RiskLevel } from '@zeavis/shared';
import { count, desc, eq } from 'drizzle-orm';
import { Elysia } from 'elysia';
import { createDbClient } from '../db/client';
import { diseaseCatalog, manualClassifications } from '../db/schema';
import { serviceUnavailable } from '../lib/http-errors';

export const dashboardRoutes = new Elysia({ prefix: '/api/v1' }).get('/dashboard/summary', async () => {
  try {
    const db = createDbClient();
    const diseases = await db.select().from(diseaseCatalog);
    const [{ value: classificationCount }] = await db.select({ value: count() }).from(manualClassifications);
    const [latestRow] = await db
      .select()
      .from(manualClassifications)
      .innerJoin(diseaseCatalog, eq(manualClassifications.diseaseSlug, diseaseCatalog.slug))
      .orderBy(desc(manualClassifications.createdAt))
      .limit(1);

    const riskDistribution = diseases.reduce<DashboardSummary['riskDistribution']>(
      (totals, disease) => {
        totals[disease.riskLevel as RiskLevel] += 1;
        return totals;
      },
      { low: 0, medium: 0, high: 0 },
    );

    const latestClassification: ManualClassificationRecord | null = latestRow
      ? {
          id: latestRow.manual_classifications.id,
          diseaseSlug: latestRow.manual_classifications.diseaseSlug as DiseaseSlug,
          observation: latestRow.manual_classifications.observation,
          location: latestRow.manual_classifications.location,
          createdAt: latestRow.manual_classifications.createdAt.toISOString(),
          disease: {
            slug: latestRow.disease_catalog.slug as DiseaseSlug,
            label: latestRow.disease_catalog.label as DiseaseCatalogItem['label'],
            commonName: latestRow.disease_catalog.commonName,
            summary: latestRow.disease_catalog.summary,
            description: latestRow.disease_catalog.description,
            symptoms: latestRow.disease_catalog.symptoms,
            recommendations: latestRow.disease_catalog.recommendations,
            riskLevel: latestRow.disease_catalog.riskLevel as RiskLevel,
            accentColor: latestRow.disease_catalog.accentColor,
            displayOrder: latestRow.disease_catalog.displayOrder,
          },
        }
      : null;

    return { diseaseCount: diseases.length, classificationCount, latestClassification, riskDistribution } satisfies DashboardSummary;
  } catch {
    return serviceUnavailable('Database is unavailable');
  }
});
```

- [ ] **Step 7: Register API routes**

Modify `apps/api/src/index.ts`:

```ts
import { Elysia } from 'elysia';
import { env } from './config/env';
import { dashboardRoutes } from './routes/dashboard';
import { classificationRoutes } from './routes/classifications';
import { diseaseRoutes } from './routes/diseases';
import { healthRoutes } from './routes/health';
import { statusRoutes } from './routes/status';

const app = new Elysia().use(healthRoutes).use(statusRoutes).use(diseaseRoutes).use(classificationRoutes).use(dashboardRoutes).listen(env.port);

console.log(`ZeaVis Edu API running at http://${app.server?.hostname}:${app.server?.port}`);

export type App = typeof app;
```

- [ ] **Step 8: Generate migration and typecheck API**

Run: `bun --filter @zeavis/api run db:generate`

Expected: Drizzle creates a migration under `apps/api/drizzle/`.

Run: `bun --filter @zeavis/api run typecheck`

Expected: TypeScript exits with code 0.

- [ ] **Step 9: Commit**

```bash
git add apps/api/src apps/api/drizzle
git commit -m "Add education catalog API and schema"
```

---

### Task 3: Web API client and reusable components

**Files:**
- Create: `apps/web/src/lib/api-client.ts`
- Create: `apps/web/src/components/risk-badge.tsx`
- Create: `apps/web/src/components/disease-card.tsx`
- Create: `apps/web/src/components/manual-classification-form.tsx`

- [ ] **Step 1: Add typed API client**

Write `apps/web/src/lib/api-client.ts`:

```ts
import type { DashboardSummary, DiseaseCatalogItem, DiseaseSlug, ManualClassificationRecord, ManualClassificationRequest } from '@zeavis/shared';

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? '';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    headers: { 'content-type': 'application/json', ...init?.headers },
    ...init,
  });

  if (!response.ok) {
    const fallback = `Request failed with status ${response.status}`;
    const payload = (await response.json().catch(() => ({ error: fallback }))) as { error?: string };
    throw new Error(payload.error ?? fallback);
  }

  return response.json() as Promise<T>;
}

export const apiClient = {
  getDiseases: () => request<DiseaseCatalogItem[]>('/api/v1/diseases'),
  getDisease: (slug: DiseaseSlug) => request<DiseaseCatalogItem>(`/api/v1/diseases/${slug}`),
  getManualClassifications: () => request<ManualClassificationRecord[]>('/api/v1/classifications/manual'),
  createManualClassification: (payload: ManualClassificationRequest) =>
    request<ManualClassificationRecord>('/api/v1/classifications/manual', { method: 'POST', body: JSON.stringify(payload) }),
  getDashboardSummary: () => request<DashboardSummary>('/api/v1/dashboard/summary'),
};
```

- [ ] **Step 2: Add risk badge**

Write `apps/web/src/components/risk-badge.tsx`:

```tsx
import type { RiskLevel } from '@zeavis/shared';

const riskLabels: Record<RiskLevel, string> = {
  low: 'Risiko rendah',
  medium: 'Risiko sedang',
  high: 'Risiko tinggi',
};

const riskClasses: Record<RiskLevel, string> = {
  low: 'bg-emerald-100 text-emerald-800',
  medium: 'bg-amber-100 text-amber-800',
  high: 'bg-red-100 text-red-800',
};

export function RiskBadge({ riskLevel }: { riskLevel: RiskLevel }) {
  return <span className={`rounded-full px-3 py-1 text-xs font-semibold ${riskClasses[riskLevel]}`}>{riskLabels[riskLevel]}</span>;
}
```

- [ ] **Step 3: Add disease card**

Write `apps/web/src/components/disease-card.tsx`:

```tsx
import type { DiseaseCatalogItem } from '@zeavis/shared';
import { ArrowRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { RiskBadge } from '@/components/risk-badge';

export function DiseaseCard({ disease }: { disease: DiseaseCatalogItem }) {
  return (
    <Card className="h-full transition hover:-translate-y-1 hover:shadow-md">
      <CardHeader className="space-y-4">
        <div className="flex items-center justify-between gap-3">
          <RiskBadge riskLevel={disease.riskLevel} />
          <span className="text-sm text-muted-foreground">{disease.commonName}</span>
        </div>
        <div>
          <CardTitle>{disease.label}</CardTitle>
          <CardDescription className="mt-2 leading-6">{disease.summary}</CardDescription>
        </div>
        <ul className="space-y-2 text-sm text-muted-foreground">
          {disease.symptoms.slice(0, 2).map((symptom) => (
            <li key={symptom}>• {symptom}</li>
          ))}
        </ul>
        <Link className="inline-flex items-center text-sm font-semibold text-primary" to={`/catalog/${disease.slug}`}>
          Pelajari detail <ArrowRight className="ml-2 h-4 w-4" />
        </Link>
      </CardHeader>
    </Card>
  );
}
```

- [ ] **Step 4: Add manual classification form**

Write `apps/web/src/components/manual-classification-form.tsx`:

```tsx
import type { DiseaseCatalogItem, DiseaseSlug, ManualClassificationRequest } from '@zeavis/shared';
import { useState } from 'react';
import { Button } from '@/components/ui/button';

export function ManualClassificationForm({ diseases, onSubmit, isSubmitting }: { diseases: DiseaseCatalogItem[]; onSubmit: (payload: ManualClassificationRequest) => void; isSubmitting: boolean }) {
  const [diseaseSlug, setDiseaseSlug] = useState<DiseaseSlug>(diseases[0]?.slug ?? 'daun-sehat');
  const [observation, setObservation] = useState('Daun diamati secara manual melalui aplikasi ZeaVis Edu.');
  const [location, setLocation] = useState('Lahan observasi');

  return (
    <form
      className="space-y-4 rounded-3xl border bg-card p-5"
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit({ diseaseSlug, observation, location });
      }}
    >
      <div>
        <label className="text-sm font-medium" htmlFor="diseaseSlug">Label hasil pengamatan</label>
        <select id="diseaseSlug" className="mt-2 w-full rounded-2xl border bg-background px-4 py-3" value={diseaseSlug} onChange={(event) => setDiseaseSlug(event.target.value as DiseaseSlug)}>
          {diseases.map((disease) => (
            <option key={disease.slug} value={disease.slug}>{disease.label}</option>
          ))}
        </select>
      </div>
      <div>
        <label className="text-sm font-medium" htmlFor="observation">Catatan observasi</label>
        <textarea id="observation" className="mt-2 min-h-24 w-full rounded-2xl border bg-background px-4 py-3" value={observation} onChange={(event) => setObservation(event.target.value)} />
      </div>
      <div>
        <label className="text-sm font-medium" htmlFor="location">Lokasi/catatan lahan</label>
        <input id="location" className="mt-2 w-full rounded-2xl border bg-background px-4 py-3" value={location} onChange={(event) => setLocation(event.target.value)} />
      </div>
      <Button disabled={isSubmitting || diseases.length === 0} type="submit">Simpan klasifikasi manual</Button>
    </form>
  );
}
```

- [ ] **Step 5: Typecheck web components**

Run: `bun --filter @zeavis/web run typecheck`

Expected: TypeScript exits with code 0.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/api-client.ts apps/web/src/components
git commit -m "Add web catalog API client and components"
```

---

### Task 4: Web pages and routes

**Files:**
- Modify: `apps/web/src/app.tsx`
- Modify: `apps/web/src/pages/landing-page.tsx`
- Modify: `apps/web/src/pages/dashboard-page.tsx`
- Create: `apps/web/src/pages/catalog-page.tsx`
- Create: `apps/web/src/pages/disease-detail-page.tsx`

- [ ] **Step 1: Add catalog page**

Write `apps/web/src/pages/catalog-page.tsx` with a TanStack Query call to `apiClient.getDiseases()`, a search input, risk filter select, and `DiseaseCard` grid. The page must show loading text `Memuat katalog...`, error text `Katalog belum tersedia`, and an empty state `Tidak ada penyakit yang cocok dengan filter ini.`.

- [ ] **Step 2: Add disease detail page**

Write `apps/web/src/pages/disease-detail-page.tsx` using `useParams`, `isDiseaseSlug`, and `apiClient.getDisease(slug)`. Render description, symptoms, recommendations, risk badge, and links back to `/catalog` and `/dashboard`. Invalid slugs should render `Materi tidak ditemukan`.

- [ ] **Step 3: Replace dashboard page with data-backed dashboard**

Modify `apps/web/src/pages/dashboard-page.tsx` to query diseases, summary, and manual classification history. Include summary cards, risk distribution, recent history, and `ManualClassificationForm`. Use `useMutation` for `apiClient.createManualClassification`, then invalidate `dashboard-summary` and `manual-classifications` queries.

- [ ] **Step 4: Update landing page**

Modify `apps/web/src/pages/landing-page.tsx` so the primary CTA links to `/dashboard`, secondary CTA links to `/catalog`, and copy describes education catalog plus manual observation tracking instead of scaffold placeholders.

- [ ] **Step 5: Register routes**

Modify `apps/web/src/app.tsx`:

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createBrowserRouter, RouterProvider } from 'react-router-dom';
import { CatalogPage } from '@/pages/catalog-page';
import { DashboardPage } from '@/pages/dashboard-page';
import { DiseaseDetailPage } from '@/pages/disease-detail-page';
import { LandingPage } from '@/pages/landing-page';

const queryClient = new QueryClient();

const router = createBrowserRouter([
  { path: '/', element: <LandingPage /> },
  { path: '/dashboard', element: <DashboardPage /> },
  { path: '/catalog', element: <CatalogPage /> },
  { path: '/catalog/:slug', element: <DiseaseDetailPage /> },
]);

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  );
}
```

- [ ] **Step 6: Typecheck web pages**

Run: `bun --filter @zeavis/web run typecheck`

Expected: TypeScript exits with code 0.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/app.tsx apps/web/src/pages
git commit -m "Build education catalog web experience"
```

---

### Task 5: Verification and manual run

**Files:**
- Modify only if verification exposes a concrete bug.

- [ ] **Step 1: Run full typecheck**

Run: `bun run typecheck`

Expected: all Moon typecheck tasks pass.

- [ ] **Step 2: Run production build**

Run: `bun run build`

Expected: API/shared/web builds complete successfully.

- [ ] **Step 3: Start API and web**

Run API in one terminal: `bun --filter @zeavis/api run start`

Run web in another terminal: `bun --filter @zeavis/web run dev`

Expected: API logs `ZeaVis Edu API running...`; Vite logs a local URL.

- [ ] **Step 4: Browser-check frontend flow**

Open the Vite URL. Check `/`, `/dashboard`, `/catalog`, and one `/catalog/:slug` page. If no PostgreSQL database is configured, verify error states render instead of a blank screen. If `DATABASE_URL` and migrated/seeded data are available, submit one manual classification and verify it appears in dashboard/history.

- [ ] **Step 5: Final commit for verification fixes**

If fixes were required:

```bash
git add <fixed-files>
git commit -m "Fix education catalog verification issues"
```

If no fixes were required, do not create an empty commit.

---

## Self-review notes

- Spec coverage: shared contract, backend schema/routes, frontend pages/manual flow, error states, and verification are all covered.
- Placeholder scan: no TBD/TODO/fill-later placeholders are present. Task 4 uses explicit behavior requirements for page files because page markup is lengthy, but all required states and wiring are specified.
- Type consistency: shared names (`DiseaseSlug`, `DiseaseCatalogItem`, `ManualClassificationRequest`, `ManualClassificationRecord`, `DashboardSummary`) are consistent across tasks.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
