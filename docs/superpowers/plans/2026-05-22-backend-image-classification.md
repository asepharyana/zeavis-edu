# Backend Image Classification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real backend image classification using the exported TensorFlow.js model and external uploader service.

**Architecture:** The web app sends an image to the Elysia API. The API uploads the original image to `https://upload.asepharyana.tech/api/upload`, runs the local TFJS graph model from `Machine_Learning/model/tfjs_model/model.json`, maps probabilities to ZeaVis Edu labels, stores the result in PostgreSQL, and returns disease education metadata. Shared types define the API contract for uploader metadata, prediction probabilities, and image classification history.

**Tech Stack:** Bun workspaces, TypeScript, Elysia, Drizzle ORM, PostgreSQL, TensorFlow.js graph model, React, TanStack Query, Tailwind CSS.

---

## File structure

- Modify `apps/api/package.json`: add runtime dependencies for TensorFlow.js/image decoding if compatible with Bun.
- Modify `packages/shared/src/classifications.ts`: add image classification, probability, and uploader metadata types.
- Modify `packages/shared/src/index.ts`: export new image classification types.
- Modify `apps/api/src/db/schema.ts`: add `imageClassifications` table.
- Create/modify Drizzle migration under `apps/api/drizzle/`: create `image_classifications` table.
- Create `apps/api/src/lib/disease-mappers.ts`: map DB disease rows to shared disease records.
- Create `apps/api/src/lib/uploader-client.ts`: upload image files to external uploader.
- Create `apps/api/src/lib/image-model.ts`: load/cached TFJS graph model and classify image buffers.
- Modify `apps/api/src/routes/classifications.ts`: add image classification POST/GET routes.
- Modify `apps/api/src/routes/dashboard.ts`: optionally include image latest/count only if shared summary is extended.
- Modify `apps/web/src/lib/api-client.ts`: add image classification API methods.
- Create `apps/web/src/components/image-classification-form.tsx`: upload form and latest result display.
- Modify `apps/web/src/pages/dashboard-page.tsx`: show image classification form and image prediction history.

---

### Task 1: Shared image classification contract

**Files:**
- Modify: `packages/shared/src/classifications.ts`
- Modify: `packages/shared/src/index.ts`

- [ ] **Step 1: Extend shared classification types**

Modify `packages/shared/src/classifications.ts` to:

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

export type PredictionProbability = {
  diseaseSlug: DiseaseSlug;
  label: DiseaseCatalogItem['label'];
  confidence: number;
};

export type UploaderMetadata = {
  public_id: string;
  file_name: string;
  mime_type: string;
  size_bytes: number;
  file_type: string;
  uploader_id?: number;
  created_at: string;
  telegram_file_id?: string;
  telegram_file_unique_id?: string;
  storage_chat_id?: number;
  storage_message_id?: number;
  download_url: string;
};

export type ImageClassificationRecord = {
  id: string;
  predictedDiseaseSlug: DiseaseSlug;
  confidence: number;
  probabilities: PredictionProbability[];
  imageUrl: string;
  originalFileName: string;
  uploaderPublicId: string;
  uploader: UploaderMetadata;
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

- [ ] **Step 2: Export new types**

Modify `packages/shared/src/index.ts` classification exports to include:

```ts
export type {
  DashboardSummary,
  ImageClassificationRecord,
  ManualClassificationRecord,
  ManualClassificationRequest,
  PredictionProbability,
  UploaderMetadata,
} from './classifications';
```

- [ ] **Step 3: Verify shared typecheck**

Run: `bun run --cwd packages/shared typecheck`

Expected: TypeScript exits with code 0.

---

### Task 2: Backend dependencies, DB schema, and migrations

**Files:**
- Modify: `apps/api/package.json`
- Modify: `apps/api/src/db/schema.ts`
- Create/modify: `apps/api/drizzle/*.sql`

- [ ] **Step 1: Add backend inference dependencies**

Run: `bun add --cwd apps/api @tensorflow/tfjs jpeg-js pngjs`

Expected: `apps/api/package.json` and `bun.lockb`/lockfile update. Use pure `@tensorflow/tfjs` first because it avoids native Node bindings and is more likely to run under Bun.

- [ ] **Step 2: Add image classification table to schema**

Modify `apps/api/src/db/schema.ts` to import `jsonb` and `real`, then add:

```ts
export const imageClassifications = pgTable('image_classifications', {
  id: uuid('id').primaryKey().defaultRandom(),
  predictedDiseaseSlug: varchar('predicted_disease_slug', { length: 80 })
    .notNull()
    .references(() => diseaseCatalog.slug),
  confidence: real('confidence').notNull(),
  probabilities: jsonb('probabilities').notNull(),
  imageUrl: text('image_url').notNull(),
  originalFileName: varchar('original_file_name', { length: 240 }).notNull(),
  uploaderPublicId: varchar('uploader_public_id', { length: 160 }).notNull(),
  uploaderPayload: jsonb('uploader_payload').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
```

- [ ] **Step 3: Generate migration**

Run: `bun run --cwd apps/api db:generate`

Expected: a new SQL migration creates `image_classifications` with FK to `disease_catalog`.

- [ ] **Step 4: Verify API typecheck**

Run: `bun run --cwd apps/api typecheck`

Expected: TypeScript exits with code 0.

---

### Task 3: Backend mapper, uploader client, and TFJS model service

**Files:**
- Create: `apps/api/src/lib/disease-mappers.ts`
- Create: `apps/api/src/lib/uploader-client.ts`
- Create: `apps/api/src/lib/image-model.ts`
- Modify: `apps/api/src/lib/http-errors.ts`

- [ ] **Step 1: Add bad gateway helper**

Modify `apps/api/src/lib/http-errors.ts` to add:

```ts
export function badGateway(message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status: 502,
    headers: { 'content-type': 'application/json' },
  });
}
```

- [ ] **Step 2: Add disease row mapper**

Write `apps/api/src/lib/disease-mappers.ts`:

```ts
import type { DiseaseCatalogItem, DiseaseLabel, DiseaseSlug, RiskLevel } from '@zeavis/shared';
import { diseaseCatalog } from '../db/schema';

export function toDisease(row: typeof diseaseCatalog.$inferSelect): DiseaseCatalogItem {
  return {
    slug: row.slug as DiseaseSlug,
    label: row.label as DiseaseLabel,
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
```

- [ ] **Step 3: Add uploader client**

Write `apps/api/src/lib/uploader-client.ts`:

```ts
import type { UploaderMetadata } from '@zeavis/shared';

const uploaderUrl = 'https://upload.asepharyana.tech/api/upload';

export async function uploadImageToStorage(file: File): Promise<UploaderMetadata> {
  const formData = new FormData();
  formData.append('file', file, file.name);
  formData.append('fileName', file.name);

  const response = await fetch(uploaderUrl, {
    method: 'POST',
    body: formData,
  });

  const payload = (await response.json().catch(() => null)) as Partial<UploaderMetadata> & { error?: string } | null;
  if (!response.ok || !payload?.download_url || !payload.public_id) {
    throw new Error(payload?.error ?? 'Upload service failed');
  }

  return payload as UploaderMetadata;
}
```

- [ ] **Step 4: Add TFJS image model service**

Write `apps/api/src/lib/image-model.ts`:

```ts
import type { DiseaseLabel, DiseaseSlug, PredictionProbability } from '@zeavis/shared';
import * as tf from '@tensorflow/tfjs';
import jpeg from 'jpeg-js';
import { PNG } from 'pngjs';

const labels: Array<{ diseaseSlug: DiseaseSlug; label: DiseaseLabel }> = [
  { diseaseSlug: 'bercak-daun', label: 'Bercak Daun' },
  { diseaseSlug: 'hawar-daun', label: 'Hawar Daun' },
  { diseaseSlug: 'karat-daun', label: 'Karat Daun' },
  { diseaseSlug: 'daun-sehat', label: 'Daun Sehat' },
];

let modelPromise: Promise<tf.GraphModel> | undefined;

function modelUrl() {
  return `file://${process.cwd()}/../../Machine_Learning/model/tfjs_model/model.json`;
}

async function loadModel() {
  modelPromise ??= tf.loadGraphModel(modelUrl());
  return modelPromise;
}

function decodeImage(buffer: ArrayBuffer, mimeType: string) {
  const bytes = new Uint8Array(buffer);
  if (mimeType === 'image/png') {
    const png = PNG.sync.read(Buffer.from(bytes));
    return { width: png.width, height: png.height, data: png.data };
  }

  const jpegImage = jpeg.decode(Buffer.from(bytes), { useTArray: true });
  return { width: jpegImage.width, height: jpegImage.height, data: jpegImage.data };
}

function imageToTensor(image: { width: number; height: number; data: Uint8Array | Buffer }) {
  const rgb = new Uint8Array(image.width * image.height * 3);
  for (let source = 0, target = 0; source < image.data.length; source += 4, target += 3) {
    rgb[target] = image.data[source];
    rgb[target + 1] = image.data[source + 1];
    rgb[target + 2] = image.data[source + 2];
  }

  return tf.tidy(() =>
    tf.tensor3d(rgb, [image.height, image.width, 3], 'int32')
      .resizeBilinear([224, 224])
      .toFloat()
      .div(255)
      .expandDims(0),
  );
}

export async function classifyImage(file: File) {
  if (!['image/jpeg', 'image/png'].includes(file.type)) {
    throw new Error('Unsupported image type');
  }

  const model = await loadModel();
  const decoded = decodeImage(await file.arrayBuffer(), file.type);
  const input = imageToTensor(decoded);

  try {
    const output = model.predict(input) as tf.Tensor;
    const scores = Array.from(await output.data());
    output.dispose();

    const probabilities: PredictionProbability[] = scores.map((confidence, index) => ({
      ...labels[index],
      confidence,
    }));
    probabilities.sort((a, b) => b.confidence - a.confidence);

    return {
      predictedDiseaseSlug: probabilities[0].diseaseSlug,
      confidence: probabilities[0].confidence,
      probabilities,
    };
  } finally {
    input.dispose();
  }
}
```

- [ ] **Step 5: Verify API typecheck**

Run: `bun run --cwd apps/api typecheck`

Expected: TypeScript exits with code 0. If imports for `jpeg-js` or `pngjs` lack types, add minimal `.d.ts` declarations in `apps/api/src/types/image-decoders.d.ts` and include them through tsconfig include.

---

### Task 4: Backend image classification routes

**Files:**
- Modify: `apps/api/src/routes/classifications.ts`

- [ ] **Step 1: Add image row conversion helpers**

In `apps/api/src/routes/classifications.ts`, import `ImageClassificationRecord`, `PredictionProbability`, `UploaderMetadata`, `imageClassifications`, `badGateway`, `toDisease`, `classifyImage`, and `uploadImageToStorage`. Add a helper:

```ts
function toImageRecord(row: {
  id: string;
  predictedDiseaseSlug: string;
  confidence: number;
  probabilities: unknown;
  imageUrl: string;
  originalFileName: string;
  uploaderPublicId: string;
  uploaderPayload: unknown;
  createdAt: Date;
  disease: typeof diseaseCatalog.$inferSelect;
}): ImageClassificationRecord {
  return {
    id: row.id,
    predictedDiseaseSlug: row.predictedDiseaseSlug as ImageClassificationRecord['predictedDiseaseSlug'],
    confidence: row.confidence,
    probabilities: row.probabilities as PredictionProbability[],
    imageUrl: row.imageUrl,
    originalFileName: row.originalFileName,
    uploaderPublicId: row.uploaderPublicId,
    uploader: row.uploaderPayload as UploaderMetadata,
    createdAt: row.createdAt.toISOString(),
    disease: toDisease(row.disease),
  };
}
```

- [ ] **Step 2: Add GET image history route**

Add to `classificationRoutes` before the manual POST route:

```ts
  .get('/classifications/image', async () => {
    try {
      const db = createDbClient();
      const rows = await db
        .select({
          id: imageClassifications.id,
          predictedDiseaseSlug: imageClassifications.predictedDiseaseSlug,
          confidence: imageClassifications.confidence,
          probabilities: imageClassifications.probabilities,
          imageUrl: imageClassifications.imageUrl,
          originalFileName: imageClassifications.originalFileName,
          uploaderPublicId: imageClassifications.uploaderPublicId,
          uploaderPayload: imageClassifications.uploaderPayload,
          createdAt: imageClassifications.createdAt,
          disease: diseaseCatalog,
        })
        .from(imageClassifications)
        .innerJoin(diseaseCatalog, eq(imageClassifications.predictedDiseaseSlug, diseaseCatalog.slug))
        .orderBy(desc(imageClassifications.createdAt))
        .limit(20);

      return rows.map(toImageRecord);
    } catch {
      return serviceUnavailable('Database unavailable');
    }
  })
```

- [ ] **Step 3: Add POST image classification route**

Add to `classificationRoutes`:

```ts
  .post('/classifications/image', async ({ body }) => {
    const payload = body as { file?: File } | undefined;
    const file = payload?.file;

    if (!(file instanceof File) || file.size === 0) {
      return badRequest('Image file is required');
    }

    if (!file.type.startsWith('image/')) {
      return badRequest('Only image files are supported');
    }

    let uploader: UploaderMetadata;
    try {
      uploader = await uploadImageToStorage(file);
    } catch {
      return badGateway('Image uploader is unavailable');
    }

    let prediction: Awaited<ReturnType<typeof classifyImage>>;
    try {
      prediction = await classifyImage(file);
    } catch {
      return serviceUnavailable('Image classification model is unavailable');
    }

    try {
      const db = createDbClient();
      const [disease] = await db
        .select()
        .from(diseaseCatalog)
        .where(eq(diseaseCatalog.slug, prediction.predictedDiseaseSlug))
        .limit(1);

      if (!disease) {
        return serviceUnavailable('Predicted disease is not available in the catalog');
      }

      const [created] = await db
        .insert(imageClassifications)
        .values({
          predictedDiseaseSlug: prediction.predictedDiseaseSlug,
          confidence: prediction.confidence,
          probabilities: prediction.probabilities,
          imageUrl: uploader.download_url,
          originalFileName: file.name || uploader.file_name,
          uploaderPublicId: uploader.public_id,
          uploaderPayload: uploader,
        })
        .returning();

      return toImageRecord({ ...created, disease });
    } catch {
      return serviceUnavailable('Database unavailable');
    }
  })
```

- [ ] **Step 4: Verify API typecheck**

Run: `bun run --cwd apps/api typecheck`

Expected: TypeScript exits with code 0.

---

### Task 5: Web client, upload form, and dashboard integration

**Files:**
- Modify: `apps/web/src/lib/api-client.ts`
- Create: `apps/web/src/components/image-classification-form.tsx`
- Modify: `apps/web/src/pages/dashboard-page.tsx`

- [ ] **Step 1: Extend API client**

Modify `apps/web/src/lib/api-client.ts` imports to include `ImageClassificationRecord`. Add methods:

```ts
  getImageClassifications: () => request<ImageClassificationRecord[]>('/api/v1/classifications/image'),
  createImageClassification: (file: File) => {
    const body = new FormData();
    body.append('file', file, file.name);
    return request<ImageClassificationRecord>('/api/v1/classifications/image', { method: 'POST', body, headers: {} });
  },
```

Adjust `request` so it only sets `content-type: application/json` when `init?.body` is not a `FormData`.

- [ ] **Step 2: Add image classification form**

Write `apps/web/src/components/image-classification-form.tsx`:

```tsx
import type { ImageClassificationRecord } from '@zeavis/shared';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { RiskBadge } from '@/components/risk-badge';

export function ImageClassificationForm({ onSubmit, isSubmitting, latestResult }: { onSubmit: (file: File) => Promise<void>; isSubmitting: boolean; latestResult: ImageClassificationRecord | null }) {
  const [file, setFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Klasifikasi Gambar</CardTitle>
        <CardDescription>Unggah foto daun jagung untuk prediksi model ZeaVis Edu.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <form
          className="space-y-4"
          onSubmit={async (event) => {
            event.preventDefault();
            setError(null);
            if (!file) {
              setError('Pilih gambar daun terlebih dahulu');
              return;
            }
            await onSubmit(file);
            setFile(null);
          }}
        >
          {error && <div className="rounded-md bg-red-50 p-3 text-sm text-red-800">{error}</div>}
          <input
            accept="image/*"
            type="file"
            onChange={(event) => setFile(event.target.files?.[0] ?? null)}
            className="block w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
          />
          <Button disabled={!file || isSubmitting} type="submit">
            {isSubmitting ? 'Mengklasifikasi...' : 'Klasifikasi gambar'}
          </Button>
        </form>

        {latestResult && (
          <div className="rounded-2xl border p-4">
            <img src={latestResult.imageUrl} alt={latestResult.originalFileName} className="mb-4 max-h-64 w-full rounded-xl object-cover" />
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-sm text-muted-foreground">Hasil prediksi</p>
                <h3 className="text-xl font-semibold">{latestResult.disease.label}</h3>
                <p className="text-sm text-muted-foreground">Confidence {(latestResult.confidence * 100).toFixed(1)}%</p>
              </div>
              <RiskBadge level={latestResult.disease.riskLevel} />
            </div>
            <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
              {latestResult.disease.recommendations.slice(0, 3).map((recommendation) => (
                <li key={recommendation}>• {recommendation}</li>
              ))}
            </ul>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 3: Wire dashboard image queries**

Modify `apps/web/src/pages/dashboard-page.tsx`:

- Add `ImageClassificationForm` import.
- Add a fourth `useQueries` entry with `queryKey: ['image-classifications']` and `queryFn: () => apiClient.getImageClassifications()`.
- Add `const imageClassifications = imageClassificationsQuery.data || [];`.
- Add `useMutation` for `apiClient.createImageClassification(file)` and invalidate `image-classifications` on success.
- Render `ImageClassificationForm` above `ManualClassificationForm` with `latestResult={imageClassifications[0] ?? null}`.
- Add a history `Card` for image classifications showing thumbnail, label, confidence, and date.

- [ ] **Step 4: Verify web typecheck**

Run: `bun run --cwd apps/web typecheck`

Expected: TypeScript exits with code 0.

---

### Task 6: Full verification and manual behavior check

**Files:**
- Modify only if verification reveals a concrete bug.

- [ ] **Step 1: Run full typecheck and build**

Run: `bun run typecheck && bun run build`

Expected: all workspace typecheck and build tasks pass.

- [ ] **Step 2: Start API and web**

Run API: `bun run --cwd apps/api start`

Run web: `bun run --cwd apps/web dev`

Expected: API logs `ZeaVis Edu API running...`; Vite serves the app.

- [ ] **Step 3: Check API without database**

Run: `curl -s -w '\n%{http_code}' http://localhost:3000/api/v1/classifications/image`

Expected without `DATABASE_URL`: JSON `{ "error": "Database unavailable" }` with status `503`, not a crash.

- [ ] **Step 4: Check upload route validation**

Run: `curl -s -X POST -w '\n%{http_code}' http://localhost:3000/api/v1/classifications/image`

Expected: JSON error with status `400`.

- [ ] **Step 5: Browser check dashboard**

Open `/dashboard`. Confirm the image classification form renders. If no database is configured, confirm structured error state renders without crashing. If database is configured and migrated, submit a JPEG/PNG corn leaf image and verify the result card displays image, label, confidence, and recommendations.

---

## Self-review notes

- Spec coverage: backend TFJS inference, uploader integration, DB persistence, API routes, shared types, frontend upload/result/history, and verification are covered.
- Placeholder scan: no TBD/TODO/fill-later placeholders remain; every file and route has explicit behavior.
- Type consistency: `ImageClassificationRecord`, `PredictionProbability`, and `UploaderMetadata` are defined once in shared and used consistently across API and web.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
