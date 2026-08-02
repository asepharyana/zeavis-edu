# API ML Service Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `apps/api` image classification from local TensorFlow.js inference to HTTP calls to `apps/ml-service` while preserving the existing `classifyImage(file)` contract.

**Architecture:** `apps/api/src/lib/image-model.ts` remains the only API-side inference boundary, but becomes a small HTTP adapter. API routes continue calling `classifyImage(file)` unchanged, while `apps/api/src/config/env.ts` provides `mlServiceUrl` from `ML_SERVICE_URL` with a local default. TFJS and image decoder dependencies are removed from the API package after the adapter no longer imports them.

**Tech Stack:** Bun, TypeScript, Elysia, built-in `fetch`/`FormData`, Moon typecheck, FastAPI ML service.

---

## File Structure

Modify these files:

- `apps/api/src/config/env.ts` — add `mlServiceUrl` with default `http://127.0.0.1:8001`.
- `apps/api/src/lib/image-model.ts` — replace TFJS local inference with HTTP adapter logic.
- `apps/api/package.json` — remove local inference dependencies `@tensorflow/tfjs`, `jpeg-js`, and `pngjs`.
- `bun.lock` — update automatically after dependency removal.

Create these files:

- `apps/api/src/lib/image-model.test.ts` — Bun tests for API-side ML service response mapping and failure behavior.

Do not modify these files:

- `apps/api/src/routes/classifications.ts` — existing route behavior should remain stable.
- `apps/api/src/routes/diagnoses.ts` — existing diagnosis behavior should remain stable.
- `apps/ml-service/*` — service already exposes the required `/predict` contract.
- Database schema files — schema is unchanged.
- Frontend files — frontend behavior is unchanged.

---

### Task 1: Add API ML service configuration

**Files:**
- Modify: `apps/api/src/config/env.ts`

- [ ] **Step 1: Update env configuration**

Modify `apps/api/src/config/env.ts` so the `env` object includes `mlServiceUrl` after `uploaderBaseUrl`:

```ts
const uploadAllowedMimeTypes = (Bun.env.UPLOAD_ALLOWED_MIME_TYPES ?? 'image/jpeg,image/png')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

const googleOAuthEnabled = Boolean(
  Bun.env.GOOGLE_CLIENT_ID && Bun.env.GOOGLE_CLIENT_SECRET && Bun.env.GOOGLE_REDIRECT_URI,
);

const webAppUrl = Bun.env.WEB_APP_URL ?? 'http://localhost:5173';
const secureCookies = Bun.env.SECURE_COOKIES === 'true' || webAppUrl.startsWith('https://');

export const env = {
  port: Number(Bun.env.API_PORT ?? 3000),
  databaseUrl: Bun.env.DATABASE_URL,
  sessionSecret: Bun.env.SESSION_SECRET,
  uploaderBaseUrl: Bun.env.UPLOADER_BASE_URL ?? 'https://upload.asepharyana.tech',
  mlServiceUrl: Bun.env.ML_SERVICE_URL ?? 'http://127.0.0.1:8001',
  uploadMaxBytes: Number(Bun.env.UPLOAD_MAX_BYTES ?? 5 * 1024 * 1024),
  uploadAllowedMimeTypes,
  googleOAuthEnabled,
  googleClientId: Bun.env.GOOGLE_CLIENT_ID,
  googleClientSecret: Bun.env.GOOGLE_CLIENT_SECRET,
  googleRedirectUri: Bun.env.GOOGLE_REDIRECT_URI,
  webAppUrl,
  secureCookies,
};

export function assertRequiredEnv() {
  if (!env.databaseUrl) {
    throw new Error('DATABASE_URL is required');
  }

  if (!env.sessionSecret || env.sessionSecret.length < 32) {
    throw new Error('SESSION_SECRET is required and must be at least 32 characters');
  }
}
```

- [ ] **Step 2: Run API typecheck**

Run from repository root:

```bash
bun run typecheck
```

Expected: typecheck exits 0. If unrelated existing typecheck failures appear, record exact failures before continuing.

- [ ] **Step 3: Commit**

Run:

```bash
git add apps/api/src/config/env.ts
git commit -m "feat: add ML service URL config"
```

Expected: commit succeeds.

---

### Task 2: Add failing tests for ML service adapter behavior

**Files:**
- Create: `apps/api/src/lib/image-model.test.ts`

- [ ] **Step 1: Write tests before changing adapter implementation**

Create `apps/api/src/lib/image-model.test.ts` with exactly:

```ts
import { afterEach, describe, expect, test } from 'bun:test';
import { classifyImage } from './image-model';

const originalFetch = globalThis.fetch;

afterEach(() => {
  globalThis.fetch = originalFetch;
});

function makeImageFile(type = 'image/jpeg') {
  return new File([new Uint8Array([1, 2, 3])], 'leaf.jpg', { type });
}

describe('classifyImage', () => {
  test('maps ML service prediction response to API classification result', async () => {
    globalThis.fetch = async (input, init) => {
      expect(String(input)).toBe('http://127.0.0.1:8001/predict');
      expect(init?.method).toBe('POST');
      expect(init?.body).toBeInstanceOf(FormData);

      return new Response(
        JSON.stringify({
          label: 'Daun Sehat',
          confidence: 0.92,
          probabilities: {
            'Bercak Daun': 0.02,
            'Daun Sehat': 0.92,
            'Karat Daun': 0.03,
            'Hawar Daun': 0.03,
          },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    };

    const result = await classifyImage(makeImageFile());

    expect(result.predictedDiseaseSlug).toBe('daun-sehat');
    expect(result.confidence).toBe(0.92);
    expect(result.probabilities).toEqual([
      { diseaseSlug: 'daun-sehat', label: 'Daun Sehat', confidence: 0.92 },
      { diseaseSlug: 'karat-daun', label: 'Karat Daun', confidence: 0.03 },
      { diseaseSlug: 'hawar-daun', label: 'Hawar Daun', confidence: 0.03 },
      { diseaseSlug: 'bercak-daun', label: 'Bercak Daun', confidence: 0.02 },
    ]);
  });

  test('rejects unsupported file types before calling ML service', async () => {
    let called = false;
    globalThis.fetch = async () => {
      called = true;
      return new Response('{}');
    };

    await expect(classifyImage(makeImageFile('image/webp'))).rejects.toThrow('File must be JPEG or PNG');
    expect(called).toBe(false);
  });

  test('throws when ML service returns a non-success response', async () => {
    globalThis.fetch = async () => new Response(JSON.stringify({ detail: 'Model is not loaded' }), { status: 503 });

    await expect(classifyImage(makeImageFile())).rejects.toThrow('ML service returned 503: Model is not loaded');
  });

  test('throws when ML service returns an unknown label', async () => {
    globalThis.fetch = async () => new Response(
      JSON.stringify({
        label: 'Unknown Disease',
        confidence: 0.7,
        probabilities: { 'Unknown Disease': 0.7 },
      }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );

    await expect(classifyImage(makeImageFile())).rejects.toThrow('Unknown ML service label: Unknown Disease');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail against existing TFJS implementation**

Run from repository root:

```bash
bun test apps/api/src/lib/image-model.test.ts
```

Expected: FAIL because the current implementation tries to load the local TFJS model or otherwise does not call `fetch` with `http://127.0.0.1:8001/predict`.

- [ ] **Step 3: Commit failing tests only if repository policy allows red commits**

Do not commit the failing test by itself in this repo. Continue to Task 3 and commit tests with the implementation once green.

---

### Task 3: Replace local TFJS inference with ML service HTTP adapter

**Files:**
- Modify: `apps/api/src/lib/image-model.ts`
- Test: `apps/api/src/lib/image-model.test.ts`

- [ ] **Step 1: Replace image-model implementation**

Replace all contents of `apps/api/src/lib/image-model.ts` with exactly:

```ts
import type { DiseaseSlug, DiseaseLabel, PredictionProbability } from '@zeavis/shared';
import { env } from '../config/env';

const DISEASE_CLASSES: Array<{ slug: DiseaseSlug; label: DiseaseLabel }> = [
  { slug: 'bercak-daun', label: 'Bercak Daun' },
  { slug: 'daun-sehat', label: 'Daun Sehat' },
  { slug: 'karat-daun', label: 'Karat Daun' },
  { slug: 'hawar-daun', label: 'Hawar Daun' },
];

const DISEASE_BY_LABEL = new Map<DiseaseLabel, { slug: DiseaseSlug; label: DiseaseLabel }>(
  DISEASE_CLASSES.map((disease) => [disease.label, disease]),
);

type MlPredictionResponse = {
  label: unknown;
  confidence: unknown;
  probabilities: unknown;
};

export type ClassificationResult = {
  predictedDiseaseSlug: DiseaseSlug;
  confidence: number;
  probabilities: PredictionProbability[];
};

function predictUrl() {
  return `${env.mlServiceUrl.replace(/\/+$/, '')}/predict`;
}

function assertKnownLabel(label: unknown): DiseaseLabel {
  if (typeof label !== 'string' || !DISEASE_BY_LABEL.has(label as DiseaseLabel)) {
    throw new Error(`Unknown ML service label: ${String(label)}`);
  }

  return label as DiseaseLabel;
}

function assertConfidence(value: unknown, label: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new Error(`Invalid ML service confidence for ${label}`);
  }

  return Math.max(0, Math.min(1, value));
}

function mapProbabilities(probabilities: unknown): PredictionProbability[] {
  if (!probabilities || typeof probabilities !== 'object' || Array.isArray(probabilities)) {
    throw new Error('Invalid ML service probabilities');
  }

  return Object.entries(probabilities).map(([label, confidence]) => {
    const knownLabel = assertKnownLabel(label);
    const disease = DISEASE_BY_LABEL.get(knownLabel)!;

    return {
      diseaseSlug: disease.slug,
      label: disease.label,
      confidence: assertConfidence(confidence, disease.label),
    };
  }).sort((a, b) => b.confidence - a.confidence);
}

async function parseErrorResponse(response: Response): Promise<string> {
  try {
    const body = await response.json();
    if (body && typeof body === 'object' && 'detail' in body) {
      return String(body.detail);
    }
  } catch {
    return response.statusText || 'Unknown error';
  }

  return response.statusText || 'Unknown error';
}

export async function classifyImage(file: File): Promise<ClassificationResult> {
  if (file.type !== 'image/jpeg' && file.type !== 'image/png') {
    throw new Error('File must be JPEG or PNG');
  }

  const formData = new FormData();
  formData.append('file', file, file.name || 'leaf-image');

  let response: Response;
  try {
    response = await fetch(predictUrl(), {
      method: 'POST',
      body: formData,
    });
  } catch (error) {
    throw new Error(`ML service request failed: ${error instanceof Error ? error.message : String(error)}`);
  }

  if (!response.ok) {
    const message = await parseErrorResponse(response);
    throw new Error(`ML service returned ${response.status}: ${message}`);
  }

  const prediction = await response.json() as MlPredictionResponse;
  const predictedLabel = assertKnownLabel(prediction.label);
  const predictedDisease = DISEASE_BY_LABEL.get(predictedLabel)!;

  return {
    predictedDiseaseSlug: predictedDisease.slug,
    confidence: assertConfidence(prediction.confidence, predictedDisease.label),
    probabilities: mapProbabilities(prediction.probabilities),
  };
}
```

- [ ] **Step 2: Run adapter tests to verify green**

Run from repository root:

```bash
bun test apps/api/src/lib/image-model.test.ts
```

Expected: PASS, 4 tests pass.

- [ ] **Step 3: Run API typecheck**

Run from repository root:

```bash
bun run typecheck
```

Expected: typecheck exits 0.

- [ ] **Step 4: Commit adapter and tests**

Run:

```bash
git add apps/api/src/lib/image-model.ts apps/api/src/lib/image-model.test.ts
git commit -m "feat: call ML service for image classification"
```

Expected: commit succeeds.

---

### Task 4: Remove local TFJS dependencies from API

**Files:**
- Modify: `apps/api/package.json`
- Modify: `bun.lock`

- [ ] **Step 1: Remove unused dependencies**

Run from repository root:

```bash
bun remove --cwd apps/api @tensorflow/tfjs jpeg-js pngjs
```

Expected: `apps/api/package.json` no longer lists `@tensorflow/tfjs`, `jpeg-js`, or `pngjs`, and `bun.lock` updates.

- [ ] **Step 2: Confirm no local inference imports remain in API source**

Run from repository root:

```bash
grep -R "@tensorflow/tfjs\|jpeg-js\|pngjs" -n apps/api/src apps/api/package.json || true
```

Expected: no output.

- [ ] **Step 3: Run tests and typecheck**

Run from repository root:

```bash
bun test apps/api/src/lib/image-model.test.ts
bun run typecheck
```

Expected: adapter tests pass and typecheck exits 0.

- [ ] **Step 4: Commit dependency cleanup**

Run:

```bash
git add apps/api/package.json bun.lock
git commit -m "chore: remove API local model dependencies"
```

Expected: commit succeeds.

---

### Task 5: Verify API adapter against running ML service

**Files:**
- No production code changes expected.

- [ ] **Step 1: Start ML service**

Run from `apps/ml-service`:

```bash
.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8001
```

Expected: service starts. If `Machine_Learning/best_model/best_model.keras` exists, startup loads the model.

- [ ] **Step 2: Confirm ML service health**

Run from another terminal:

```bash
curl -s http://127.0.0.1:8001/health
```

Expected when model artifact exists:

```json
{"status":"ok","model_loaded":true}
```

- [ ] **Step 3: Exercise API adapter with a synthetic image**

Run from repository root:

```bash
bun --cwd apps/api --env-file=../../.env - <<'TS'
import { classifyImage } from './src/lib/image-model';

const bytes = new Uint8Array([
  255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, 72, 0, 72, 0, 0,
  255, 219, 0, 67, 0, 8, 6, 6, 7, 6, 5, 8, 7, 7, 7, 9, 9, 8, 10, 12, 20,
  13, 12, 11, 11, 12, 25, 18, 19, 15, 20, 29, 26, 31, 30, 29, 26, 28, 28,
  32, 36, 46, 39, 32, 34, 44, 35, 28, 28, 40, 55, 41, 44, 48, 49, 52, 52,
  52, 31, 39, 57, 61, 56, 50, 60, 46, 51, 52, 50, 255, 192, 0, 11, 8, 0,
  1, 0, 1, 1, 1, 17, 0, 255, 196, 0, 20, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 196, 0, 20, 16, 1, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 218, 0, 8, 1, 1, 0, 0,
  63, 0, 127, 255, 217,
]);
const file = new File([bytes], 'synthetic.jpg', { type: 'image/jpeg' });
const result = await classifyImage(file);
console.log(JSON.stringify(result));
TS
```

Expected: JSON includes `predictedDiseaseSlug`, `confidence`, and `probabilities`. `predictedDiseaseSlug` is one of `bercak-daun`, `daun-sehat`, `karat-daun`, or `hawar-daun`.

- [ ] **Step 4: Stop ML service**

Press `Ctrl+C` in the ML service terminal.

Expected: server shuts down cleanly.

---

### Task 6: Final verification and review

**Files:**
- Review all changed files.

- [ ] **Step 1: Run final status check**

Run from repository root:

```bash
git status --short
```

Expected: no uncommitted changes.

- [ ] **Step 2: Run final static checks**

Run from repository root:

```bash
bun test apps/api/src/lib/image-model.test.ts
bun run typecheck
grep -R "@tensorflow/tfjs\|jpeg-js\|pngjs" -n apps/api/src apps/api/package.json || true
```

Expected: tests pass, typecheck exits 0, grep has no output.

- [ ] **Step 3: Request final code review**

Review range starts at commit before the API migration spec and ends at current HEAD. Ask reviewer to check:

```text
- API classifyImage still returns predictedDiseaseSlug, confidence, probabilities.
- Error behavior preserves existing route semantics.
- ML service URL config is safe and trims trailing slashes.
- Removed dependencies are not used anywhere under apps/api/src.
- No frontend or database schema changes were introduced.
```

Expected: reviewer reports no Critical or Important issues.

- [ ] **Step 4: Summarize actual verification evidence**

Final response must include only checks that were actually run:

```text
Verified:
- Adapter unit tests: <actual result>
- API typecheck: <actual result>
- Dependency import grep: <actual result>
- ML service health: <actual result if run>
- classifyImage against running ML service: <actual result if run>
```

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
