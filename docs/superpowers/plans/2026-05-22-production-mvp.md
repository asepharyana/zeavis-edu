# ZeaVis Edu Production MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an authenticated production-style MVP where users upload corn leaf images, receive persisted AI diagnoses, and low-confidence results are reviewed by expert users.

**Architecture:** Extend the existing Bun + Moon monorepo without replacing its current catalog/classification foundation. Add session-based auth, PostgreSQL-backed diagnosis records, expert review workflow, and frontend pages that consume the new APIs. Keep image uploading behind the API uploader adapter and keep TensorFlow.js inference behind `image-model`.

**Tech Stack:** Bun, TypeScript, Elysia, Drizzle ORM, PostgreSQL, React, Vite, React Router, TanStack Query, Zustand, Tailwind, TensorFlow.js.

---

## File structure map

### Backend

- Modify `apps/api/package.json`: add password hashing/session/OAuth dependencies if chosen during implementation (`bcryptjs` and `@types/bcryptjs` are sufficient for password hashing; Google OAuth can be implemented with standard `fetch` and `URLSearchParams`).
- Modify `apps/api/src/config/env.ts`: expose required auth/uploader/upload/OAuth config.
- Modify `apps/api/src/db/schema.ts`: add `users`, `sessions`, `diagnoses`, `diagnosisPredictions`, and `expertReviews`; keep existing tables for compatibility during migration.
- Create `apps/api/src/lib/auth.ts`: password hashing, session token creation/hash, cookie helpers, current-user lookup, auth/role guards.
- Modify `apps/api/src/lib/uploader-client.ts`: read uploader base URL from env and return typed metadata.
- Modify `apps/api/src/lib/image-model.ts`: ensure probabilities are top-k sorted and reusable for diagnosis prediction rows.
- Create `apps/api/src/routes/auth.ts`: register/login/logout/me and optional Google OAuth endpoints.
- Create `apps/api/src/routes/diagnoses.ts`: authenticated diagnosis creation/list/detail.
- Create `apps/api/src/routes/expert.ts`: expert-only review queue and review submission.
- Modify `apps/api/src/routes/dashboard.ts`: make user-specific summaries if auth is present.
- Modify `apps/api/src/index.ts`: register new route modules.
- Modify `apps/api/src/db/seed-data.ts`: seed diseases and at least one expert account for demos.

### Shared package

- Modify `packages/shared/src/classifications.ts`: add diagnosis/review/auth-facing DTO types while preserving existing exported types until consumers are migrated.
- Modify `packages/shared/src/index.ts`: export new DTO types.

### Frontend

- Modify `apps/web/src/lib/api-client.ts`: send credentials, add auth/diagnosis/expert APIs, keep existing disease APIs.
- Create `apps/web/src/store/auth-store.ts`: lightweight current-user state if needed outside queries.
- Create `apps/web/src/components/auth-form.tsx`: shared login/register form.
- Create `apps/web/src/components/auth-guard.tsx`: route guard for authenticated and expert routes.
- Create `apps/web/src/components/diagnosis-status-badge.tsx`: renders diagnosis statuses.
- Create `apps/web/src/components/diagnosis-card.tsx`: reusable diagnosis history/review card.
- Modify `apps/web/src/components/image-classification-form.tsx`: submit through new diagnosis endpoint and display progress/errors.
- Create `apps/web/src/pages/login-page.tsx`.
- Create `apps/web/src/pages/register-page.tsx`.
- Modify `apps/web/src/pages/dashboard-page.tsx`: authenticated dashboard with upload, summaries, and diagnosis history.
- Create `apps/web/src/pages/diagnosis-detail-page.tsx`.
- Create `apps/web/src/pages/expert-reviews-page.tsx`.
- Modify `apps/web/src/app.tsx`: add auth routes and guarded diagnosis/expert routes.

### Verification

- Run `bun install` after dependency changes.
- Run `bun run typecheck`.
- Run `bun run build`.
- Run `cd apps/api && bun run db:generate` and apply migrations in an environment with `DATABASE_URL`.
- Run the app and manually verify the user and expert flows.

---

## Task 1: Add shared auth, diagnosis, and review DTOs

**Files:**
- Modify: `packages/shared/src/classifications.ts`
- Modify: `packages/shared/src/index.ts`

- [ ] **Step 1: Inspect current shared classification types**

Run: `grep -n "export type" packages/shared/src/classifications.ts`

Expected: Output includes existing `ManualClassificationRecord`, `PredictionProbability`, `UploaderMetadata`, and `ImageClassificationRecord` exports.

- [ ] **Step 2: Replace shared classification module with backwards-compatible DTOs**

Write `packages/shared/src/classifications.ts` with this content:

```ts
import type { DiseaseCatalogItem, DiseaseSlug } from './diseases';

export type ManualClassificationRequest = {
  diseaseSlug: DiseaseSlug;
  observation: string;
  location: string;
};

export type ManualClassificationRecord = ManualClassificationRequest & {
  id: string;
  createdAt: string;
  disease: DiseaseCatalogItem;
};

export type PredictionProbability = {
  diseaseSlug: DiseaseSlug;
  label: string;
  confidence: number;
};

export type UploaderMetadata = {
  public_id: string;
  telegram_file_id?: string;
  telegram_file_unique_id?: string;
  file_name: string;
  mime_type: string;
  size_bytes: number;
  file_type: string;
  download_url: string;
};

export type DiagnosisStatus =
  | 'ai_verified'
  | 'needs_review'
  | 'expert_verified'
  | 'expert_corrected'
  | 'failed';

export type UserRole = 'user' | 'expert';

export type AuthUser = {
  id: string;
  email: string;
  name: string;
  role: UserRole;
};

export type AuthFeatures = {
  googleOAuthEnabled: boolean;
};

export type AuthMeResponse = {
  user: AuthUser | null;
  features: AuthFeatures;
};

export type AuthRequest = {
  email: string;
  password: string;
};

export type RegisterRequest = AuthRequest & {
  name: string;
};

export type AuthResponse = {
  user: AuthUser;
  features: AuthFeatures;
};

export type DiagnosisPrediction = {
  id: string;
  diseaseSlug: DiseaseSlug | null;
  modelLabel: string;
  confidence: number;
  rank: number;
};

export type ExpertReviewRecord = {
  id: string;
  diagnosisId: string;
  expertId: string;
  verdict: 'verified' | 'corrected';
  correctedDiseaseSlug: DiseaseSlug | null;
  notes: string;
  createdAt: string;
  expert: AuthUser;
};

export type DiagnosisRecord = {
  id: string;
  userId: string;
  predictedDiseaseSlug: DiseaseSlug | null;
  confidence: number | null;
  status: DiagnosisStatus;
  failureReason: string | null;
  imageUrl: string;
  uploaderPublicId: string;
  imageFileName: string;
  imageMimeType: string;
  imageSizeBytes: number;
  createdAt: string;
  updatedAt: string;
  disease: DiseaseCatalogItem | null;
  predictions: DiagnosisPrediction[];
  latestReview: ExpertReviewRecord | null;
};

export type ReviewDiagnosisRequest = {
  verdict: 'verified' | 'corrected';
  correctedDiseaseSlug?: DiseaseSlug;
  notes: string;
};

export type DashboardSummary = {
  diseaseCount: number;
  classificationCount: number;
  imageClassificationCount: number;
  needsReviewCount: number;
  riskDistribution: {
    low: number;
    medium: number;
    high: number;
  };
  latestClassification: ManualClassificationRecord | null;
  latestDiagnosis: DiagnosisRecord | null;
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
```

- [ ] **Step 3: Export the new types**

Modify `packages/shared/src/index.ts` so the classification export block is:

```ts
export type {
  ManualClassificationRequest,
  ManualClassificationRecord,
  DashboardSummary,
  PredictionProbability,
  UploaderMetadata,
  ImageClassificationRecord,
  DiagnosisStatus,
  UserRole,
  AuthUser,
  AuthFeatures,
  AuthMeResponse,
  AuthRequest,
  RegisterRequest,
  AuthResponse,
  DiagnosisPrediction,
  ExpertReviewRecord,
  DiagnosisRecord,
  ReviewDiagnosisRequest,
} from './classifications';
```

- [ ] **Step 4: Run shared typecheck**

Run: `bun run typecheck`

Expected: It may fail because backend/frontend have not been updated for the new `DashboardSummary` fields yet. If it fails only because `DashboardSummary` is missing fields in existing backend code, continue to Task 2.

- [ ] **Step 5: Commit**

```bash
git add packages/shared/src/classifications.ts packages/shared/src/index.ts
git commit -m "feat: define production diagnosis DTOs"
```

---

## Task 2: Add backend configuration and database schema

**Files:**
- Modify: `apps/api/package.json`
- Modify: `apps/api/src/config/env.ts`
- Modify: `apps/api/src/db/schema.ts`

- [ ] **Step 1: Add password hashing dependency**

Modify `apps/api/package.json` dependencies/devDependencies to include:

```json
"dependencies": {
  "@tensorflow/tfjs": "4.22.0",
  "@zeavis/shared": "workspace:*",
  "bcryptjs": "^2.4.3",
  "drizzle-orm": "^0.36.4",
  "elysia": "^1.1.25",
  "jpeg-js": "0.4.4",
  "pngjs": "7.0.0",
  "postgres": "^3.4.5"
},
"devDependencies": {
  "@types/bcryptjs": "^2.4.6",
  "@types/bun": "latest",
  "drizzle-kit": "^0.27.1",
  "typescript": "^5.6.3"
}
```

- [ ] **Step 2: Install dependencies**

Run: `bun install`

Expected: Bun updates `bun.lock` and installs `bcryptjs` plus types.

- [ ] **Step 3: Replace env config**

Write `apps/api/src/config/env.ts` with this content:

```ts
const uploadAllowedMimeTypes = (Bun.env.UPLOAD_ALLOWED_MIME_TYPES ?? 'image/jpeg,image/png')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

const googleOAuthEnabled = Boolean(
  Bun.env.GOOGLE_CLIENT_ID && Bun.env.GOOGLE_CLIENT_SECRET && Bun.env.GOOGLE_REDIRECT_URI,
);

export const env = {
  port: Number(Bun.env.API_PORT ?? 3000),
  databaseUrl: Bun.env.DATABASE_URL,
  sessionSecret: Bun.env.SESSION_SECRET,
  uploaderBaseUrl: Bun.env.UPLOADER_BASE_URL ?? 'https://upload.asepharyana.tech',
  uploadMaxBytes: Number(Bun.env.UPLOAD_MAX_BYTES ?? 5 * 1024 * 1024),
  uploadAllowedMimeTypes,
  googleOAuthEnabled,
  googleClientId: Bun.env.GOOGLE_CLIENT_ID,
  googleClientSecret: Bun.env.GOOGLE_CLIENT_SECRET,
  googleRedirectUri: Bun.env.GOOGLE_REDIRECT_URI,
  webAppUrl: Bun.env.WEB_APP_URL ?? 'http://localhost:5173',
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

- [ ] **Step 4: Replace database schema**

Write `apps/api/src/db/schema.ts` with this content:

```ts
import {
  index,
  integer,
  jsonb,
  pgTable,
  real,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

export const appEvents = pgTable('app_events', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: varchar('name', { length: 120 }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

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

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: varchar('email', { length: 240 }).notNull(),
  name: varchar('name', { length: 160 }).notNull(),
  passwordHash: text('password_hash'),
  role: varchar('role', { length: 20 }).notNull().default('user'),
  googleId: varchar('google_id', { length: 240 }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  emailIdx: uniqueIndex('users_email_idx').on(table.email),
  googleIdx: uniqueIndex('users_google_id_idx').on(table.googleId),
}));

export const sessions = pgTable('sessions', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => users.id),
  tokenHash: text('token_hash').notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  tokenIdx: uniqueIndex('sessions_token_hash_idx').on(table.tokenHash),
  userIdx: index('sessions_user_id_idx').on(table.userId),
}));

export const manualClassifications = pgTable('manual_classifications', {
  id: uuid('id').primaryKey().defaultRandom(),
  diseaseSlug: varchar('disease_slug', { length: 80 })
    .notNull()
    .references(() => diseaseCatalog.slug),
  observation: text('observation').notNull(),
  location: varchar('location', { length: 160 }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

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

export const diagnoses = pgTable('diagnoses', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => users.id),
  predictedDiseaseSlug: varchar('predicted_disease_slug', { length: 80 }).references(() => diseaseCatalog.slug),
  confidence: real('confidence'),
  status: varchar('status', { length: 40 }).notNull(),
  failureReason: text('failure_reason'),
  imageUrl: text('image_url').notNull(),
  uploaderPublicId: varchar('uploader_public_id', { length: 160 }).notNull(),
  imageFileName: varchar('image_file_name', { length: 240 }).notNull(),
  imageMimeType: varchar('image_mime_type', { length: 120 }).notNull(),
  imageSizeBytes: integer('image_size_bytes').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  userIdx: index('diagnoses_user_id_idx').on(table.userId),
  statusIdx: index('diagnoses_status_idx').on(table.status),
}));

export const diagnosisPredictions = pgTable('diagnosis_predictions', {
  id: uuid('id').primaryKey().defaultRandom(),
  diagnosisId: uuid('diagnosis_id').notNull().references(() => diagnoses.id),
  diseaseSlug: varchar('disease_slug', { length: 80 }).references(() => diseaseCatalog.slug),
  modelLabel: varchar('model_label', { length: 120 }).notNull(),
  confidence: real('confidence').notNull(),
  rank: integer('rank').notNull(),
}, (table) => ({
  diagnosisIdx: index('diagnosis_predictions_diagnosis_id_idx').on(table.diagnosisId),
}));

export const expertReviews = pgTable('expert_reviews', {
  id: uuid('id').primaryKey().defaultRandom(),
  diagnosisId: uuid('diagnosis_id').notNull().references(() => diagnoses.id),
  expertId: uuid('expert_id').notNull().references(() => users.id),
  verdict: varchar('verdict', { length: 20 }).notNull(),
  correctedDiseaseSlug: varchar('corrected_disease_slug', { length: 80 }).references(() => diseaseCatalog.slug),
  notes: text('notes').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  diagnosisIdx: index('expert_reviews_diagnosis_id_idx').on(table.diagnosisId),
  expertIdx: index('expert_reviews_expert_id_idx').on(table.expertId),
}));
```

- [ ] **Step 5: Run typecheck**

Run: `bun run typecheck`

Expected: It may fail until route code is updated to use the expanded schema and summary type. Continue to Task 3 if failures are limited to missing new fields in code.

- [ ] **Step 6: Commit**

```bash
git add apps/api/package.json bun.lock apps/api/src/config/env.ts apps/api/src/db/schema.ts
git commit -m "feat: add production auth and diagnosis schema"
```

---

## Task 3: Implement backend auth utilities and routes

**Files:**
- Create: `apps/api/src/lib/auth.ts`
- Create: `apps/api/src/routes/auth.ts`
- Modify: `apps/api/src/index.ts`

- [ ] **Step 1: Create auth utilities**

Write `apps/api/src/lib/auth.ts` with this content:

```ts
import { createHash, randomBytes } from 'crypto';
import bcrypt from 'bcryptjs';
import { and, eq, gt } from 'drizzle-orm';
import type { AuthUser } from '@zeavis/shared';
import { createDbClient } from '../db/client';
import { sessions, users } from '../db/schema';
import { env } from '../config/env';

export const sessionCookieName = 'zeavis_session';

export type CurrentUser = AuthUser;

export function getAuthFeatures() {
  return {
    googleOAuthEnabled: env.googleOAuthEnabled,
  };
}

export async function hashPassword(password: string) {
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(password: string, passwordHash: string) {
  return bcrypt.compare(password, passwordHash);
}

function hashToken(token: string) {
  return createHash('sha256').update(`${env.sessionSecret}:${token}`).digest('hex');
}

export function createSessionCookie(token: string) {
  const maxAge = 60 * 60 * 24 * 30;
  return `${sessionCookieName}=${token}; HttpOnly; Path=/; SameSite=Lax; Max-Age=${maxAge}`;
}

export function clearSessionCookie() {
  return `${sessionCookieName}=; HttpOnly; Path=/; SameSite=Lax; Max-Age=0`;
}

export function readSessionToken(cookieHeader: string | null | undefined) {
  if (!cookieHeader) return null;

  const cookies = cookieHeader.split(';').map((part) => part.trim());
  const sessionCookie = cookies.find((cookie) => cookie.startsWith(`${sessionCookieName}=`));
  if (!sessionCookie) return null;

  return decodeURIComponent(sessionCookie.slice(sessionCookieName.length + 1));
}

export async function createSession(userId: string) {
  const db = createDbClient();
  const token = randomBytes(32).toString('base64url');
  const tokenHash = hashToken(token);
  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);

  await db.insert(sessions).values({
    userId,
    tokenHash,
    expiresAt,
  });

  return token;
}

export async function deleteSession(token: string | null) {
  if (!token) return;

  const db = createDbClient();
  await db.delete(sessions).where(eq(sessions.tokenHash, hashToken(token)));
}

export async function getCurrentUser(cookieHeader: string | null | undefined): Promise<CurrentUser | null> {
  const token = readSessionToken(cookieHeader);
  if (!token) return null;

  const db = createDbClient();
  const rows = await db
    .select({
      id: users.id,
      email: users.email,
      name: users.name,
      role: users.role,
    })
    .from(sessions)
    .innerJoin(users, eq(sessions.userId, users.id))
    .where(and(eq(sessions.tokenHash, hashToken(token)), gt(sessions.expiresAt, new Date())))
    .limit(1);

  const user = rows[0];
  if (!user) return null;

  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role === 'expert' ? 'expert' : 'user',
  };
}

export function requireUser(user: CurrentUser | null): CurrentUser {
  if (!user) {
    throw new Error('UNAUTHORIZED');
  }
  return user;
}

export function requireExpert(user: CurrentUser | null): CurrentUser {
  const currentUser = requireUser(user);
  if (currentUser.role !== 'expert') {
    throw new Error('FORBIDDEN');
  }
  return currentUser;
}
```

- [ ] **Step 2: Create auth routes**

Write `apps/api/src/routes/auth.ts` with this content:

```ts
import { Elysia } from 'elysia';
import type { AuthRequest, RegisterRequest } from '@zeavis/shared';
import { eq } from 'drizzle-orm';
import { createDbClient } from '../db/client';
import { users } from '../db/schema';
import { badRequest, serviceUnavailable } from '../lib/http-errors';
import {
  clearSessionCookie,
  createSession,
  createSessionCookie,
  deleteSession,
  getAuthFeatures,
  getCurrentUser,
  hashPassword,
  readSessionToken,
  verifyPassword,
} from '../lib/auth';
import { env } from '../config/env';

function normalizeEmail(email: unknown) {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

function normalizeName(name: unknown) {
  return typeof name === 'string' ? name.trim() : '';
}

function validatePassword(password: unknown) {
  return typeof password === 'string' && password.length >= 8;
}

export const authRoutes = new Elysia({ prefix: '/api/v1/auth' })
  .get('/me', async ({ request }) => {
    const user = await getCurrentUser(request.headers.get('cookie'));
    return {
      user,
      features: getAuthFeatures(),
    };
  })
  .post('/register', async ({ body, set }) => {
    const req = body as Partial<RegisterRequest> | undefined;
    const email = normalizeEmail(req?.email);
    const name = normalizeName(req?.name);

    if (!email || !email.includes('@') || !name || !validatePassword(req?.password)) {
      return badRequest('Name, valid email, and password with at least 8 characters are required');
    }

    try {
      const db = createDbClient();
      const existing = await db.select().from(users).where(eq(users.email, email)).limit(1);
      if (existing.length > 0) {
        return badRequest('Email is already registered');
      }

      const passwordHash = await hashPassword(req!.password!);
      const inserted = await db
        .insert(users)
        .values({ email, name, passwordHash, role: 'user' })
        .returning();

      const user = inserted[0];
      const token = await createSession(user.id);
      set.headers['Set-Cookie'] = createSessionCookie(token);

      return {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: 'user' as const,
        },
        features: getAuthFeatures(),
      };
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  })
  .post('/login', async ({ body, set }) => {
    const req = body as Partial<AuthRequest> | undefined;
    const email = normalizeEmail(req?.email);

    if (!email || !validatePassword(req?.password)) {
      return badRequest('Valid email and password are required');
    }

    try {
      const db = createDbClient();
      const rows = await db.select().from(users).where(eq(users.email, email)).limit(1);
      const user = rows[0];

      if (!user?.passwordHash || !(await verifyPassword(req!.password!, user.passwordHash))) {
        return badRequest('Invalid email or password');
      }

      const token = await createSession(user.id);
      set.headers['Set-Cookie'] = createSessionCookie(token);

      return {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role === 'expert' ? 'expert' as const : 'user' as const,
        },
        features: getAuthFeatures(),
      };
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  })
  .post('/logout', async ({ request, set }) => {
    await deleteSession(readSessionToken(request.headers.get('cookie')));
    set.headers['Set-Cookie'] = clearSessionCookie();
    return { ok: true };
  })
  .get('/google', ({ set }) => {
    if (!env.googleOAuthEnabled) {
      set.status = 404;
      return { error: 'Google OAuth is not configured' };
    }

    const params = new URLSearchParams({
      client_id: env.googleClientId!,
      redirect_uri: env.googleRedirectUri!,
      response_type: 'code',
      scope: 'openid email profile',
      access_type: 'offline',
      prompt: 'select_account',
    });

    set.redirect = `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
  })
  .get('/google/callback', ({ set }) => {
    if (!env.googleOAuthEnabled) {
      set.status = 404;
      return { error: 'Google OAuth is not configured' };
    }

    set.redirect = `${env.webAppUrl}/login?oauth=not-implemented`;
  });
```

- [ ] **Step 3: Register auth routes and required env assertion**

Modify `apps/api/src/index.ts` to:

```ts
import { Elysia } from 'elysia';
import { env, assertRequiredEnv } from './config/env';
import { healthRoutes } from './routes/health';
import { statusRoutes } from './routes/status';
import { diseaseRoutes } from './routes/diseases';
import { classificationRoutes } from './routes/classifications';
import { dashboardRoutes } from './routes/dashboard';
import { authRoutes } from './routes/auth';

assertRequiredEnv();

const app = new Elysia()
  .use(healthRoutes)
  .use(statusRoutes)
  .use(authRoutes)
  .use(diseaseRoutes)
  .use(classificationRoutes)
  .use(dashboardRoutes)
  .listen(env.port);

console.log(`ZeaVis Edu API running at http://${app.server?.hostname}:${app.server?.port}`);

export type App = typeof app;
```

- [ ] **Step 4: Run typecheck**

Run: `bun run typecheck`

Expected: Auth files typecheck, but remaining failures may exist because diagnoses/expert/dashboard routes are not migrated yet.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/lib/auth.ts apps/api/src/routes/auth.ts apps/api/src/index.ts
git commit -m "feat: add session auth routes"
```

---

## Task 4: Implement diagnosis persistence routes

**Files:**
- Create: `apps/api/src/routes/diagnoses.ts`
- Modify: `apps/api/src/index.ts`
- Modify: `apps/api/src/lib/uploader-client.ts`

- [ ] **Step 1: Update uploader client to use env base URL**

Write `apps/api/src/lib/uploader-client.ts` with this content:

```ts
import type { UploaderMetadata } from '@zeavis/shared';
import { env } from '../config/env';

export async function uploadImageToStorage(file: File): Promise<UploaderMetadata> {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('fileName', file.name);

  const response = await fetch(`${env.uploaderBaseUrl}/api/upload`, {
    method: 'POST',
    body: formData,
  });

  if (!response.ok) {
    throw new Error(`Upload failed with HTTP ${response.status}`);
  }

  const payload = await response.json() as Partial<UploaderMetadata>;

  if (!payload.public_id || !payload.download_url || !payload.file_name || !payload.mime_type || typeof payload.size_bytes !== 'number') {
    throw new Error('Upload response is missing required metadata');
  }

  return {
    public_id: payload.public_id,
    telegram_file_id: payload.telegram_file_id,
    telegram_file_unique_id: payload.telegram_file_unique_id,
    file_name: payload.file_name,
    mime_type: payload.mime_type,
    size_bytes: payload.size_bytes,
    file_type: payload.file_type ?? 'image',
    download_url: payload.download_url,
  };
}
```

- [ ] **Step 2: Create diagnosis routes**

Write `apps/api/src/routes/diagnoses.ts` with this content:

```ts
import { Elysia } from 'elysia';
import type { DiagnosisPrediction, DiagnosisRecord, ExpertReviewRecord } from '@zeavis/shared';
import { and, desc, eq, inArray, or } from 'drizzle-orm';
import { createDbClient } from '../db/client';
import { diagnoses, diagnosisPredictions, diseaseCatalog, expertReviews, users } from '../db/schema';
import { badGateway, badRequest, forbidden, notFound, serviceUnavailable, unauthorized } from '../lib/http-errors';
import { getCurrentUser } from '../lib/auth';
import { classifyImage } from '../lib/image-model';
import { uploadImageToStorage } from '../lib/uploader-client';
import { toDisease } from '../lib/disease-mappers';
import { env } from '../config/env';

function toReview(row: any): ExpertReviewRecord | null {
  if (!row.reviewId) return null;

  return {
    id: row.reviewId,
    diagnosisId: row.reviewDiagnosisId,
    expertId: row.reviewExpertId,
    verdict: row.reviewVerdict,
    correctedDiseaseSlug: row.reviewCorrectedDiseaseSlug,
    notes: row.reviewNotes,
    createdAt: row.reviewCreatedAt.toISOString(),
    expert: {
      id: row.expertId,
      email: row.expertEmail,
      name: row.expertName,
      role: 'expert',
    },
  };
}

async function loadDiagnosisRecord(id: string, userId: string | null, expertAccess: boolean): Promise<DiagnosisRecord | null> {
  const db = createDbClient();
  const filters = [eq(diagnoses.id, id)];
  if (!expertAccess && userId) {
    filters.push(eq(diagnoses.userId, userId));
  }

  const rows = await db
    .select({
      id: diagnoses.id,
      userId: diagnoses.userId,
      predictedDiseaseSlug: diagnoses.predictedDiseaseSlug,
      confidence: diagnoses.confidence,
      status: diagnoses.status,
      failureReason: diagnoses.failureReason,
      imageUrl: diagnoses.imageUrl,
      uploaderPublicId: diagnoses.uploaderPublicId,
      imageFileName: diagnoses.imageFileName,
      imageMimeType: diagnoses.imageMimeType,
      imageSizeBytes: diagnoses.imageSizeBytes,
      createdAt: diagnoses.createdAt,
      updatedAt: diagnoses.updatedAt,
      disease: {
        slug: diseaseCatalog.slug,
        label: diseaseCatalog.label,
        commonName: diseaseCatalog.commonName,
        summary: diseaseCatalog.summary,
        description: diseaseCatalog.description,
        symptoms: diseaseCatalog.symptoms,
        recommendations: diseaseCatalog.recommendations,
        riskLevel: diseaseCatalog.riskLevel,
        accentColor: diseaseCatalog.accentColor,
        displayOrder: diseaseCatalog.displayOrder,
      },
      reviewId: expertReviews.id,
      reviewDiagnosisId: expertReviews.diagnosisId,
      reviewExpertId: expertReviews.expertId,
      reviewVerdict: expertReviews.verdict,
      reviewCorrectedDiseaseSlug: expertReviews.correctedDiseaseSlug,
      reviewNotes: expertReviews.notes,
      reviewCreatedAt: expertReviews.createdAt,
      expertId: users.id,
      expertEmail: users.email,
      expertName: users.name,
    })
    .from(diagnoses)
    .leftJoin(diseaseCatalog, eq(diagnoses.predictedDiseaseSlug, diseaseCatalog.slug))
    .leftJoin(expertReviews, eq(expertReviews.diagnosisId, diagnoses.id))
    .leftJoin(users, eq(expertReviews.expertId, users.id))
    .where(and(...filters))
    .limit(1);

  const row = rows[0];
  if (!row) return null;

  const predictionRows = await db
    .select()
    .from(diagnosisPredictions)
    .where(eq(diagnosisPredictions.diagnosisId, row.id))
    .orderBy(diagnosisPredictions.rank);

  const predictions: DiagnosisPrediction[] = predictionRows.map((prediction) => ({
    id: prediction.id,
    diseaseSlug: prediction.diseaseSlug as any,
    modelLabel: prediction.modelLabel,
    confidence: prediction.confidence,
    rank: prediction.rank,
  }));

  return {
    id: row.id,
    userId: row.userId,
    predictedDiseaseSlug: row.predictedDiseaseSlug as any,
    confidence: row.confidence,
    status: row.status as any,
    failureReason: row.failureReason,
    imageUrl: row.imageUrl,
    uploaderPublicId: row.uploaderPublicId,
    imageFileName: row.imageFileName,
    imageMimeType: row.imageMimeType,
    imageSizeBytes: row.imageSizeBytes,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    disease: row.disease?.slug ? toDisease(row.disease as any) : null,
    predictions,
    latestReview: toReview(row),
  };
}

function getFileFromBody(body: unknown): File | null {
  if (body instanceof FormData) {
    const formFile = body.get('file');
    return formFile instanceof File ? formFile : null;
  }

  if (typeof body === 'object' && body !== null) {
    const bodyObj = body as Record<string, unknown>;
    if (bodyObj.file instanceof File) return bodyObj.file;
    if (Array.isArray(bodyObj.file) && bodyObj.file[0] instanceof File) return bodyObj.file[0];
  }

  return null;
}

export const diagnosisRoutes = new Elysia({ prefix: '/api/v1' })
  .post('/diagnoses', async ({ body, request }) => {
    const user = await getCurrentUser(request.headers.get('cookie'));
    if (!user) return unauthorized('Authentication required');

    const file = getFileFromBody(body);
    if (!file) return badRequest('Missing required field: file');
    if (file.size === 0) return badRequest('File is empty');
    if (file.size > env.uploadMaxBytes) return badRequest(`File must be smaller than ${env.uploadMaxBytes} bytes`);
    if (!env.uploadAllowedMimeTypes.includes(file.type)) return badRequest('File type is not allowed');

    let uploaderMetadata;
    try {
      uploaderMetadata = await uploadImageToStorage(file);
    } catch (error) {
      return badGateway(`Upload service error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }

    const db = createDbClient();

    try {
      const classification = await classifyImage(file);
      const status = classification.confidence >= 0.7 ? 'ai_verified' : 'needs_review';
      const inserted = await db
        .insert(diagnoses)
        .values({
          userId: user.id,
          predictedDiseaseSlug: classification.predictedDiseaseSlug,
          confidence: classification.confidence,
          status,
          imageUrl: uploaderMetadata.download_url,
          uploaderPublicId: uploaderMetadata.public_id,
          imageFileName: uploaderMetadata.file_name || file.name,
          imageMimeType: uploaderMetadata.mime_type || file.type,
          imageSizeBytes: uploaderMetadata.size_bytes || file.size,
        })
        .returning();

      await db.insert(diagnosisPredictions).values(
        classification.probabilities.map((prediction, index) => ({
          diagnosisId: inserted[0].id,
          diseaseSlug: prediction.diseaseSlug,
          modelLabel: prediction.label,
          confidence: prediction.confidence,
          rank: index + 1,
        })),
      );

      const record = await loadDiagnosisRecord(inserted[0].id, user.id, false);
      return record!;
    } catch (error) {
      const inserted = await db
        .insert(diagnoses)
        .values({
          userId: user.id,
          status: 'failed',
          failureReason: error instanceof Error ? error.message : 'Model inference failed',
          imageUrl: uploaderMetadata.download_url,
          uploaderPublicId: uploaderMetadata.public_id,
          imageFileName: uploaderMetadata.file_name || file.name,
          imageMimeType: uploaderMetadata.mime_type || file.type,
          imageSizeBytes: uploaderMetadata.size_bytes || file.size,
        })
        .returning();

      const record = await loadDiagnosisRecord(inserted[0].id, user.id, false);
      return record!;
    }
  })
  .get('/diagnoses', async ({ request }) => {
    const user = await getCurrentUser(request.headers.get('cookie'));
    if (!user) return unauthorized('Authentication required');

    try {
      const db = createDbClient();
      const rows = await db
        .select({ id: diagnoses.id })
        .from(diagnoses)
        .where(eq(diagnoses.userId, user.id))
        .orderBy(desc(diagnoses.createdAt))
        .limit(30);

      const records = await Promise.all(rows.map((row) => loadDiagnosisRecord(row.id, user.id, false)));
      return records.filter(Boolean);
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  })
  .get('/diagnoses/:id', async ({ params, request }) => {
    const user = await getCurrentUser(request.headers.get('cookie'));
    if (!user) return unauthorized('Authentication required');

    try {
      const record = await loadDiagnosisRecord(params.id, user.id, user.role === 'expert');
      if (!record) return notFound('Diagnosis not found');
      return record;
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  });

export { loadDiagnosisRecord };
```

- [ ] **Step 3: Register diagnosis routes**

Modify `apps/api/src/index.ts` to import and use diagnosis routes:

```ts
import { diagnosisRoutes } from './routes/diagnoses';
```

Add `.use(diagnosisRoutes)` after `.use(classificationRoutes)`.

- [ ] **Step 4: Run typecheck**

Run: `bun run typecheck`

Expected: Any remaining failures should be limited to dashboard summary fields or expert route not existing yet.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/lib/uploader-client.ts apps/api/src/routes/diagnoses.ts apps/api/src/index.ts
git commit -m "feat: persist authenticated diagnoses"
```

---

## Task 5: Implement expert review routes

**Files:**
- Create: `apps/api/src/routes/expert.ts`
- Modify: `apps/api/src/index.ts`

- [ ] **Step 1: Create expert routes**

Write `apps/api/src/routes/expert.ts` with this content:

```ts
import { Elysia } from 'elysia';
import type { ReviewDiagnosisRequest } from '@zeavis/shared';
import { desc, eq } from 'drizzle-orm';
import { createDbClient } from '../db/client';
import { diagnoses, expertReviews } from '../db/schema';
import { badRequest, forbidden, notFound, serviceUnavailable, unauthorized } from '../lib/http-errors';
import { getCurrentUser } from '../lib/auth';
import { isDiseaseSlug } from '@zeavis/shared';
import { loadDiagnosisRecord } from './diagnoses';

export const expertRoutes = new Elysia({ prefix: '/api/v1/expert' })
  .get('/reviews', async ({ request }) => {
    const user = await getCurrentUser(request.headers.get('cookie'));
    if (!user) return unauthorized('Authentication required');
    if (user.role !== 'expert') return forbidden('Expert role required');

    try {
      const db = createDbClient();
      const rows = await db
        .select({ id: diagnoses.id })
        .from(diagnoses)
        .where(eq(diagnoses.status, 'needs_review'))
        .orderBy(desc(diagnoses.createdAt))
        .limit(50);

      const records = await Promise.all(rows.map((row) => loadDiagnosisRecord(row.id, null, true)));
      return records.filter(Boolean);
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  })
  .post('/reviews/:diagnosisId', async ({ params, body, request }) => {
    const user = await getCurrentUser(request.headers.get('cookie'));
    if (!user) return unauthorized('Authentication required');
    if (user.role !== 'expert') return forbidden('Expert role required');

    const req = body as Partial<ReviewDiagnosisRequest> | undefined;
    if (!req || (req.verdict !== 'verified' && req.verdict !== 'corrected')) {
      return badRequest('Verdict must be verified or corrected');
    }

    const notes = typeof req.notes === 'string' ? req.notes.trim() : '';
    if (!notes) return badRequest('Review notes are required');

    if (req.verdict === 'corrected' && !isDiseaseSlug(req.correctedDiseaseSlug)) {
      return badRequest('Corrected disease slug is required for corrected reviews');
    }

    try {
      const db = createDbClient();
      const existing = await db.select().from(diagnoses).where(eq(diagnoses.id, params.diagnosisId)).limit(1);
      const diagnosis = existing[0];
      if (!diagnosis) return notFound('Diagnosis not found');

      await db.insert(expertReviews).values({
        diagnosisId: diagnosis.id,
        expertId: user.id,
        verdict: req.verdict,
        correctedDiseaseSlug: req.verdict === 'corrected' ? req.correctedDiseaseSlug! : null,
        notes,
      });

      await db
        .update(diagnoses)
        .set({
          status: req.verdict === 'corrected' ? 'expert_corrected' : 'expert_verified',
          predictedDiseaseSlug: req.verdict === 'corrected' ? req.correctedDiseaseSlug! : diagnosis.predictedDiseaseSlug,
          updatedAt: new Date(),
        })
        .where(eq(diagnoses.id, diagnosis.id));

      return await loadDiagnosisRecord(diagnosis.id, null, true);
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  });
```

- [ ] **Step 2: Register expert routes**

Modify `apps/api/src/index.ts` to import and use expert routes:

```ts
import { expertRoutes } from './routes/expert';
```

Add `.use(expertRoutes)` after `.use(diagnosisRoutes)`.

- [ ] **Step 3: Run typecheck**

Run: `bun run typecheck`

Expected: Expert route typechecks. Remaining failures should be from dashboard/frontend migration.

- [ ] **Step 4: Commit**

```bash
git add apps/api/src/routes/expert.ts apps/api/src/index.ts
git commit -m "feat: add expert diagnosis review workflow"
```

---

## Task 6: Update dashboard summary and seed data

**Files:**
- Modify: `apps/api/src/routes/dashboard.ts`
- Modify: `apps/api/src/db/seed-data.ts`

- [ ] **Step 1: Update dashboard summary route**

Modify `apps/api/src/routes/dashboard.ts` so it imports new tables and returns the expanded `DashboardSummary`:

```ts
import { Elysia } from 'elysia';
import type { DashboardSummary } from '@zeavis/shared';
import { eq, desc, count } from 'drizzle-orm';
import { createDbClient } from '../db/client';
import { diseaseCatalog, manualClassifications, diagnoses } from '../db/schema';
import { serviceUnavailable } from '../lib/http-errors';
import { toDisease } from '../lib/disease-mappers';
import { getCurrentUser } from '../lib/auth';
import { loadDiagnosisRecord } from './diagnoses';

export const dashboardRoutes = new Elysia({ prefix: '/api/v1' })
  .get('/dashboard/summary', async ({ request }) => {
    try {
      const db = createDbClient();
      const user = await getCurrentUser(request.headers.get('cookie'));

      const diseases = await db.select().from(diseaseCatalog).orderBy(diseaseCatalog.displayOrder);
      const manualRows = await db.select().from(manualClassifications).orderBy(desc(manualClassifications.createdAt)).limit(1);

      const diagnosisFilters = user ? eq(diagnoses.userId, user.id) : undefined;
      const diagnosisRows = diagnosisFilters
        ? await db.select({ id: diagnoses.id }).from(diagnoses).where(diagnosisFilters).orderBy(desc(diagnoses.createdAt)).limit(1)
        : [];

      const diagnosisCountRows = user
        ? await db.select({ value: count() }).from(diagnoses).where(eq(diagnoses.userId, user.id))
        : [{ value: 0 }];

      const needsReviewRows = user?.role === 'expert'
        ? await db.select({ value: count() }).from(diagnoses).where(eq(diagnoses.status, 'needs_review'))
        : [{ value: 0 }];

      const latestDiagnosis = diagnosisRows[0]
        ? await loadDiagnosisRecord(diagnosisRows[0].id, user?.id ?? null, user?.role === 'expert')
        : null;

      const riskDistribution = diseases.reduce(
        (acc, disease) => {
          if (disease.riskLevel === 'high') acc.high += 1;
          if (disease.riskLevel === 'medium') acc.medium += 1;
          if (disease.riskLevel === 'low') acc.low += 1;
          return acc;
        },
        { low: 0, medium: 0, high: 0 },
      );

      const latestManual = manualRows[0];
      const latestDisease = latestManual
        ? diseases.find((disease) => disease.slug === latestManual.diseaseSlug)
        : null;

      const summary: DashboardSummary = {
        diseaseCount: diseases.length,
        classificationCount: manualRows.length,
        imageClassificationCount: diagnosisCountRows[0]?.value ?? 0,
        needsReviewCount: needsReviewRows[0]?.value ?? 0,
        riskDistribution,
        latestClassification: latestManual && latestDisease ? {
          id: latestManual.id,
          diseaseSlug: latestManual.diseaseSlug as any,
          observation: latestManual.observation,
          location: latestManual.location,
          createdAt: latestManual.createdAt.toISOString(),
          disease: toDisease(latestDisease),
        } : null,
        latestDiagnosis,
      };

      return summary;
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  });
```

- [ ] **Step 2: Ensure seed data includes an expert**

Inspect `apps/api/src/db/seed-data.ts`. Add an expert user seed with email `expert@zeavis.local`, name `ZeaVis Expert`, role `expert`, and a bcrypt hash for password `password123` using `hashPassword` if the seed script is executable TypeScript. If seed-data currently exports only disease arrays and is not executable, add a named export:

```ts
export const demoExpertUser = {
  email: 'expert@zeavis.local',
  name: 'ZeaVis Expert',
  role: 'expert' as const,
  password: 'password123',
};
```

- [ ] **Step 3: Run typecheck**

Run: `bun run typecheck`

Expected: Backend dashboard errors should be resolved. Frontend may still fail because it expects old image classification APIs.

- [ ] **Step 4: Commit**

```bash
git add apps/api/src/routes/dashboard.ts apps/api/src/db/seed-data.ts
git commit -m "feat: update dashboard for diagnosis workflow"
```

---

## Task 7: Add frontend auth and diagnosis API client methods

**Files:**
- Modify: `apps/web/src/lib/api-client.ts`
- Create: `apps/web/src/store/auth-store.ts`

- [ ] **Step 1: Replace API client**

Write `apps/web/src/lib/api-client.ts` with this content:

```ts
import type {
  AuthMeResponse,
  AuthRequest,
  AuthResponse,
  DiagnosisRecord,
  DiseaseCatalogItem,
  DiseaseSlug,
  ManualClassificationRequest,
  ManualClassificationRecord,
  RegisterRequest,
  ReviewDiagnosisRequest,
  DashboardSummary,
} from '@zeavis/shared';

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? '';

async function fetchApi<T>(endpoint: string, options?: RequestInit): Promise<T> {
  const url = `${apiBaseUrl}${endpoint}`;
  const response = await fetch(url, {
    credentials: 'include',
    ...options,
    headers: options?.headers,
  });

  if (!response.ok) {
    let errorMessage = `HTTP ${response.status}`;
    try {
      const errorData = await response.json();
      if (errorData.error) {
        errorMessage = errorData.error;
      }
    } catch {
    }
    throw new Error(errorMessage);
  }

  return response.json();
}

export const apiClient = {
  async getMe(): Promise<AuthMeResponse> {
    return fetchApi('/api/v1/auth/me');
  },

  async register(payload: RegisterRequest): Promise<AuthResponse> {
    return fetchApi('/api/v1/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  },

  async login(payload: AuthRequest): Promise<AuthResponse> {
    return fetchApi('/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  },

  async logout(): Promise<{ ok: boolean }> {
    return fetchApi('/api/v1/auth/logout', { method: 'POST' });
  },

  async getDiseases(): Promise<DiseaseCatalogItem[]> {
    return fetchApi('/api/v1/diseases');
  },

  async getDisease(slug: DiseaseSlug): Promise<DiseaseCatalogItem> {
    return fetchApi(`/api/v1/diseases/${slug}`);
  },

  async getManualClassifications(): Promise<ManualClassificationRecord[]> {
    return fetchApi('/api/v1/classifications/manual');
  },

  async createManualClassification(payload: ManualClassificationRequest): Promise<ManualClassificationRecord> {
    return fetchApi('/api/v1/classifications/manual', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  },

  async getDiagnoses(): Promise<DiagnosisRecord[]> {
    return fetchApi('/api/v1/diagnoses');
  },

  async getDiagnosis(id: string): Promise<DiagnosisRecord> {
    return fetchApi(`/api/v1/diagnoses/${id}`);
  },

  async createDiagnosis(file: File): Promise<DiagnosisRecord> {
    const formData = new FormData();
    formData.append('file', file);

    return fetchApi('/api/v1/diagnoses', {
      method: 'POST',
      body: formData,
    });
  },

  async getExpertReviews(): Promise<DiagnosisRecord[]> {
    return fetchApi('/api/v1/expert/reviews');
  },

  async reviewDiagnosis(id: string, payload: ReviewDiagnosisRequest): Promise<DiagnosisRecord> {
    return fetchApi(`/api/v1/expert/reviews/${id}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  },

  async getDashboardSummary(): Promise<DashboardSummary> {
    return fetchApi('/api/v1/dashboard/summary');
  },
};
```

- [ ] **Step 2: Create auth store**

Write `apps/web/src/store/auth-store.ts` with this content:

```ts
import { create } from 'zustand';
import type { AuthUser } from '@zeavis/shared';

type AuthState = {
  user: AuthUser | null;
  setUser: (user: AuthUser | null) => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  setUser: (user) => set({ user }),
}));
```

- [ ] **Step 3: Run typecheck**

Run: `bun run typecheck`

Expected: Frontend page/component errors remain because UI still calls old image classification methods.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/lib/api-client.ts apps/web/src/store/auth-store.ts
git commit -m "feat: add frontend production API client"
```

---

## Task 8: Add frontend auth pages and guards

**Files:**
- Create: `apps/web/src/components/auth-form.tsx`
- Create: `apps/web/src/components/auth-guard.tsx`
- Create: `apps/web/src/pages/login-page.tsx`
- Create: `apps/web/src/pages/register-page.tsx`
- Modify: `apps/web/src/app.tsx`

- [ ] **Step 1: Create auth form component**

Write `apps/web/src/components/auth-form.tsx` with this content:

```tsx
import { FormEvent, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

type AuthFormProps = {
  mode: 'login' | 'register';
  isSubmitting: boolean;
  error: string | null;
  googleOAuthEnabled: boolean;
  onSubmit: (payload: { name?: string; email: string; password: string }) => Promise<void>;
};

export function AuthForm({ mode, isSubmitting, error, googleOAuthEnabled, onSubmit }: AuthFormProps) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await onSubmit({ name, email, password });
  }

  return (
    <Card className="mx-auto w-full max-w-md">
      <CardHeader>
        <CardTitle>{mode === 'login' ? 'Masuk ke ZeaVis Edu' : 'Buat akun ZeaVis Edu'}</CardTitle>
        <CardDescription>
          {mode === 'login'
            ? 'Masuk untuk melihat riwayat diagnosis daun jagung Anda.'
            : 'Daftar untuk menyimpan diagnosis dan mengikuti review pakar.'}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form className="space-y-4" onSubmit={handleSubmit}>
          {mode === 'register' && (
            <div className="space-y-2">
              <Label htmlFor="name">Nama</Label>
              <Input id="name" value={name} onChange={(event) => setName(event.target.value)} required />
            </div>
          )}
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input id="email" type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password">Password</Label>
            <Input id="password" type="password" minLength={8} value={password} onChange={(event) => setPassword(event.target.value)} required />
          </div>
          {error && <p className="text-sm text-red-600">{error}</p>}
          <Button className="w-full" type="submit" disabled={isSubmitting}>
            {isSubmitting ? 'Memproses...' : mode === 'login' ? 'Masuk' : 'Daftar'}
          </Button>
        </form>
        {googleOAuthEnabled && (
          <Button className="mt-3 w-full" variant="outline" asChild>
            <a href="/api/v1/auth/google">Masuk dengan Google</a>
          </Button>
        )}
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 2: Create auth guard**

Write `apps/web/src/components/auth-guard.tsx` with this content:

```tsx
import { ReactNode, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Navigate } from 'react-router-dom';
import { apiClient } from '@/lib/api-client';
import { useAuthStore } from '@/store/auth-store';

type AuthGuardProps = {
  children: ReactNode;
  requireExpert?: boolean;
};

export function AuthGuard({ children, requireExpert = false }: AuthGuardProps) {
  const setUser = useAuthStore((state) => state.setUser);
  const query = useQuery({
    queryKey: ['auth', 'me'],
    queryFn: () => apiClient.getMe(),
  });

  useEffect(() => {
    if (query.data) {
      setUser(query.data.user);
    }
  }, [query.data, setUser]);

  if (query.isLoading) {
    return <main className="min-h-screen p-8 text-center text-muted-foreground">Memeriksa sesi...</main>;
  }

  if (!query.data?.user) {
    return <Navigate to="/login" replace />;
  }

  if (requireExpert && query.data.user.role !== 'expert') {
    return <Navigate to="/dashboard" replace />;
  }

  return <>{children}</>;
}
```

- [ ] **Step 3: Create login page**

Write `apps/web/src/pages/login-page.tsx` with this content:

```tsx
import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AuthForm } from '@/components/auth-form';
import { apiClient } from '@/lib/api-client';
import { useAuthStore } from '@/store/auth-store';

export function LoginPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const setUser = useAuthStore((state) => state.setUser);
  const [error, setError] = useState<string | null>(null);
  const meQuery = useQuery({ queryKey: ['auth', 'me'], queryFn: () => apiClient.getMe() });

  const mutation = useMutation({
    mutationFn: apiClient.login,
    onSuccess: (response) => {
      setUser(response.user);
      queryClient.setQueryData(['auth', 'me'], response);
      navigate('/dashboard');
    },
    onError: (err) => setError(err instanceof Error ? err.message : 'Login gagal'),
  });

  return (
    <main className="flex min-h-screen items-center justify-center px-6 py-12">
      <div className="w-full space-y-4">
        <AuthForm
          mode="login"
          isSubmitting={mutation.isPending}
          error={error}
          googleOAuthEnabled={Boolean(meQuery.data?.features.googleOAuthEnabled)}
          onSubmit={async ({ email, password }) => mutation.mutateAsync({ email, password })}
        />
        <p className="text-center text-sm text-muted-foreground">
          Belum punya akun? <Link className="text-primary" to="/register">Daftar</Link>
        </p>
      </div>
    </main>
  );
}
```

- [ ] **Step 4: Create register page**

Write `apps/web/src/pages/register-page.tsx` with this content:

```tsx
import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AuthForm } from '@/components/auth-form';
import { apiClient } from '@/lib/api-client';
import { useAuthStore } from '@/store/auth-store';

export function RegisterPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const setUser = useAuthStore((state) => state.setUser);
  const [error, setError] = useState<string | null>(null);
  const meQuery = useQuery({ queryKey: ['auth', 'me'], queryFn: () => apiClient.getMe() });

  const mutation = useMutation({
    mutationFn: apiClient.register,
    onSuccess: (response) => {
      setUser(response.user);
      queryClient.setQueryData(['auth', 'me'], response);
      navigate('/dashboard');
    },
    onError: (err) => setError(err instanceof Error ? err.message : 'Registrasi gagal'),
  });

  return (
    <main className="flex min-h-screen items-center justify-center px-6 py-12">
      <div className="w-full space-y-4">
        <AuthForm
          mode="register"
          isSubmitting={mutation.isPending}
          error={error}
          googleOAuthEnabled={Boolean(meQuery.data?.features.googleOAuthEnabled)}
          onSubmit={async ({ name, email, password }) => mutation.mutateAsync({ name: name ?? '', email, password })}
        />
        <p className="text-center text-sm text-muted-foreground">
          Sudah punya akun? <Link className="text-primary" to="/login">Masuk</Link>
        </p>
      </div>
    </main>
  );
}
```

- [ ] **Step 5: Add routes**

Modify `apps/web/src/app.tsx` to include auth and guards:

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createBrowserRouter, RouterProvider } from 'react-router-dom';
import { AuthGuard } from '@/components/auth-guard';
import { DashboardPage } from '@/pages/dashboard-page';
import { LandingPage } from '@/pages/landing-page';
import { CatalogPage } from '@/pages/catalog-page';
import { DiseaseDetailPage } from '@/pages/disease-detail-page';
import { LoginPage } from '@/pages/login-page';
import { RegisterPage } from '@/pages/register-page';

const queryClient = new QueryClient();

const router = createBrowserRouter([
  { path: '/', element: <LandingPage /> },
  { path: '/login', element: <LoginPage /> },
  { path: '/register', element: <RegisterPage /> },
  {
    path: '/dashboard',
    element: (
      <AuthGuard>
        <DashboardPage />
      </AuthGuard>
    ),
  },
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

- [ ] **Step 6: Run typecheck**

Run: `bun run typecheck`

Expected: Remaining errors should be dashboard/image classification component references to old APIs or missing diagnosis pages.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/components/auth-form.tsx apps/web/src/components/auth-guard.tsx apps/web/src/pages/login-page.tsx apps/web/src/pages/register-page.tsx apps/web/src/app.tsx
git commit -m "feat: add frontend authentication flow"
```

---

## Task 9: Add diagnosis UI components and detail page

**Files:**
- Create: `apps/web/src/components/diagnosis-status-badge.tsx`
- Create: `apps/web/src/components/diagnosis-card.tsx`
- Create: `apps/web/src/pages/diagnosis-detail-page.tsx`
- Modify: `apps/web/src/app.tsx`

- [ ] **Step 1: Create status badge**

Write `apps/web/src/components/diagnosis-status-badge.tsx` with this content:

```tsx
import type { DiagnosisStatus } from '@zeavis/shared';
import { cn } from '@/lib/utils';

const labels: Record<DiagnosisStatus, string> = {
  ai_verified: 'Terverifikasi AI',
  needs_review: 'Menunggu review pakar',
  expert_verified: 'Diverifikasi pakar',
  expert_corrected: 'Dikoreksi pakar',
  failed: 'Gagal diproses',
};

const styles: Record<DiagnosisStatus, string> = {
  ai_verified: 'bg-emerald-100 text-emerald-800',
  needs_review: 'bg-amber-100 text-amber-800',
  expert_verified: 'bg-blue-100 text-blue-800',
  expert_corrected: 'bg-purple-100 text-purple-800',
  failed: 'bg-red-100 text-red-800',
};

export function DiagnosisStatusBadge({ status, className }: { status: DiagnosisStatus; className?: string }) {
  return <span className={cn('rounded-full px-3 py-1 text-xs font-semibold', styles[status], className)}>{labels[status]}</span>;
}
```

- [ ] **Step 2: Create diagnosis card**

Write `apps/web/src/components/diagnosis-card.tsx` with this content:

```tsx
import { Link } from 'react-router-dom';
import type { DiagnosisRecord } from '@zeavis/shared';
import { Card, CardContent } from '@/components/ui/card';
import { DiagnosisStatusBadge } from '@/components/diagnosis-status-badge';

export function DiagnosisCard({ diagnosis, expertLink = false }: { diagnosis: DiagnosisRecord; expertLink?: boolean }) {
  const href = expertLink ? `/expert/reviews?diagnosis=${diagnosis.id}` : `/diagnoses/${diagnosis.id}`;

  return (
    <Link to={href}>
      <Card className="transition hover:border-primary">
        <CardContent className="flex gap-4 p-4">
          <img src={diagnosis.imageUrl} alt="Daun jagung" className="h-24 w-24 rounded-lg object-cover" />
          <div className="min-w-0 flex-1 space-y-2">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h3 className="font-semibold">{diagnosis.disease?.commonName ?? 'Diagnosis gagal'}</h3>
              <DiagnosisStatusBadge status={diagnosis.status} />
            </div>
            <p className="text-sm text-muted-foreground">
              {diagnosis.confidence === null ? 'Tidak ada confidence' : `Confidence ${(diagnosis.confidence * 100).toFixed(1)}%`}
            </p>
            <p className="text-xs text-muted-foreground">{new Date(diagnosis.createdAt).toLocaleString('id-ID')}</p>
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}
```

- [ ] **Step 3: Create diagnosis detail page**

Write `apps/web/src/pages/diagnosis-detail-page.tsx` with this content:

```tsx
import { Link, useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DiagnosisStatusBadge } from '@/components/diagnosis-status-badge';
import { RiskBadge } from '@/components/risk-badge';
import { apiClient } from '@/lib/api-client';

export function DiagnosisDetailPage() {
  const { id } = useParams();
  const query = useQuery({
    queryKey: ['diagnosis', id],
    queryFn: () => apiClient.getDiagnosis(id!),
    enabled: Boolean(id),
  });

  if (query.isLoading) return <main className="p-8 text-center text-muted-foreground">Memuat diagnosis...</main>;
  if (query.error || !query.data) return <main className="p-8 text-center text-red-600">Diagnosis tidak ditemukan</main>;

  const diagnosis = query.data;

  return (
    <main className="min-h-screen px-6 py-8">
      <div className="mx-auto max-w-5xl space-y-6">
        <div className="flex items-center justify-between gap-4">
          <div>
            <p className="text-sm font-medium text-primary">Detail Diagnosis</p>
            <h1 className="text-3xl font-bold">{diagnosis.disease?.commonName ?? 'Diagnosis gagal'}</h1>
          </div>
          <Button asChild variant="outline"><Link to="/dashboard">Kembali</Link></Button>
        </div>

        <section className="grid gap-6 lg:grid-cols-[360px_1fr]">
          <Card>
            <CardContent className="p-4">
              <img src={diagnosis.imageUrl} alt="Daun jagung" className="w-full rounded-xl object-cover" />
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="flex items-center justify-between gap-3">
                <CardTitle>Hasil AI</CardTitle>
                <DiagnosisStatusBadge status={diagnosis.status} />
              </div>
              <CardDescription>
                {diagnosis.confidence === null ? 'Model gagal memproses gambar.' : `Confidence ${(diagnosis.confidence * 100).toFixed(1)}%`}
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {diagnosis.status === 'needs_review' && (
                <div className="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
                  Hasil ini masih sementara karena confidence di bawah 70% dan sedang menunggu review pakar.
                </div>
              )}
              {diagnosis.failureReason && <p className="text-sm text-red-600">{diagnosis.failureReason}</p>}
              {diagnosis.disease && (
                <div className="space-y-3">
                  <div className="flex items-center gap-2">
                    <h2 className="text-xl font-semibold">{diagnosis.disease.label}</h2>
                    <RiskBadge level={diagnosis.disease.riskLevel} />
                  </div>
                  <p className="text-muted-foreground">{diagnosis.disease.summary}</p>
                  <div>
                    <h3 className="font-semibold">Rekomendasi</h3>
                    <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-muted-foreground">
                      {diagnosis.disease.recommendations.map((item) => <li key={item}>{item}</li>)}
                    </ul>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </section>

        <Card>
          <CardHeader>
            <CardTitle>Top Predictions</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {diagnosis.predictions.map((prediction) => (
              <div key={prediction.id} className="flex items-center justify-between rounded-lg border p-3 text-sm">
                <span>{prediction.rank}. {prediction.modelLabel}</span>
                <span className="font-semibold">{(prediction.confidence * 100).toFixed(1)}%</span>
              </div>
            ))}
          </CardContent>
        </Card>

        {diagnosis.latestReview && (
          <Card>
            <CardHeader>
              <CardTitle>Catatan Pakar</CardTitle>
              <CardDescription>{diagnosis.latestReview.expert.name}</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">{diagnosis.latestReview.notes}</p>
            </CardContent>
          </Card>
        )}
      </div>
    </main>
  );
}
```

- [ ] **Step 4: Register diagnosis detail route**

Modify `apps/web/src/app.tsx` imports:

```ts
import { DiagnosisDetailPage } from '@/pages/diagnosis-detail-page';
```

Add route:

```tsx
{
  path: '/diagnoses/:id',
  element: (
    <AuthGuard>
      <DiagnosisDetailPage />
    </AuthGuard>
  ),
},
```

- [ ] **Step 5: Run typecheck**

Run: `bun run typecheck`

Expected: Diagnosis detail components typecheck. Dashboard and expert page may still fail until updated.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/components/diagnosis-status-badge.tsx apps/web/src/components/diagnosis-card.tsx apps/web/src/pages/diagnosis-detail-page.tsx apps/web/src/app.tsx
git commit -m "feat: add diagnosis detail UI"
```

---

## Task 10: Migrate dashboard to authenticated diagnosis workflow

**Files:**
- Modify: `apps/web/src/components/image-classification-form.tsx`
- Modify: `apps/web/src/pages/dashboard-page.tsx`

- [ ] **Step 1: Replace image classification form props**

Modify `apps/web/src/components/image-classification-form.tsx` so it accepts `latestResult: DiagnosisRecord | null` and displays diagnosis status. Use this complete component:

```tsx
import { ChangeEvent, FormEvent, useState } from 'react';
import type { DiagnosisRecord } from '@zeavis/shared';
import { Upload } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DiagnosisStatusBadge } from '@/components/diagnosis-status-badge';

type ImageClassificationFormProps = {
  onSubmit: (file: File) => Promise<void>;
  isSubmitting: boolean;
  latestResult: DiagnosisRecord | null;
};

export function ImageClassificationForm({ onSubmit, isSubmitting, latestResult }: ImageClassificationFormProps) {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  function handleFileChange(event: ChangeEvent<HTMLInputElement>) {
    const selectedFile = event.target.files?.[0] ?? null;
    setError(null);
    setFile(selectedFile);
    setPreviewUrl(selectedFile ? URL.createObjectURL(selectedFile) : null);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!file) {
      setError('Pilih gambar terlebih dahulu');
      return;
    }

    try {
      await onSubmit(file);
      setFile(null);
      setPreviewUrl(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal mengirim gambar');
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2"><Upload className="h-5 w-5" /> Diagnosis Gambar</CardTitle>
        <CardDescription>Upload gambar daun jagung untuk klasifikasi AI dan review pakar jika confidence rendah.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <form onSubmit={handleSubmit} className="space-y-4">
          <input type="file" accept="image/jpeg,image/png" onChange={handleFileChange} />
          {previewUrl && <img src={previewUrl} alt="Preview" className="h-48 rounded-lg object-cover" />}
          {error && <p className="text-sm text-red-600">{error}</p>}
          <Button type="submit" disabled={isSubmitting}>{isSubmitting ? 'Memproses...' : 'Upload dan Diagnosis'}</Button>
        </form>

        {latestResult && (
          <div className="rounded-lg border p-4">
            <div className="mb-2 flex items-center justify-between gap-3">
              <h3 className="font-semibold">{latestResult.disease?.commonName ?? 'Diagnosis gagal'}</h3>
              <DiagnosisStatusBadge status={latestResult.status} />
            </div>
            <p className="text-sm text-muted-foreground">
              {latestResult.confidence === null ? 'Tidak ada confidence' : `Confidence ${(latestResult.confidence * 100).toFixed(1)}%`}
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 2: Replace dashboard page**

Write `apps/web/src/pages/dashboard-page.tsx` with this content:

```tsx
import { useMutation, useQueries, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import { BookOpen, History, LayoutDashboard, LogOut, ShieldCheck, TrendingUp } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { ImageClassificationForm } from '@/components/image-classification-form';
import { DiagnosisCard } from '@/components/diagnosis-card';
import { useUiStore } from '@/store/ui-store';
import { useAuthStore } from '@/store/auth-store';
import { apiClient } from '@/lib/api-client';

export function DashboardPage() {
  const { dashboardCompact, toggleDashboardCompact } = useUiStore();
  const user = useAuthStore((state) => state.user);
  const setUser = useAuthStore((state) => state.setUser);
  const queryClient = useQueryClient();
  const navigate = useNavigate();

  const [diseasesQuery, summaryQuery, diagnosesQuery] = useQueries({
    queries: [
      { queryKey: ['diseases'], queryFn: () => apiClient.getDiseases() },
      { queryKey: ['dashboard-summary'], queryFn: () => apiClient.getDashboardSummary() },
      { queryKey: ['diagnoses'], queryFn: () => apiClient.getDiagnoses() },
    ],
  });

  const createDiagnosisMutation = useMutation({
    mutationFn: async (file: File) => apiClient.createDiagnosis(file),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['diagnoses'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-summary'] });
    },
  });

  const logoutMutation = useMutation({
    mutationFn: () => apiClient.logout(),
    onSuccess: () => {
      setUser(null);
      queryClient.clear();
      navigate('/login');
    },
  });

  const diseases = diseasesQuery.data || [];
  const summary = summaryQuery.data;
  const diagnoses = diagnosesQuery.data || [];
  const isLoadingData = diseasesQuery.isLoading || summaryQuery.isLoading || diagnosesQuery.isLoading;
  const hasError = diseasesQuery.error || summaryQuery.error || diagnosesQuery.error;

  return (
    <main className="min-h-screen px-6 py-8">
      <div className="mx-auto max-w-6xl space-y-8">
        <header className="flex flex-col gap-4 rounded-3xl border bg-card p-6 shadow-sm md:flex-row md:items-center md:justify-between">
          <div className="space-y-2">
            <div className="flex items-center gap-2 text-sm font-medium text-primary">
              <LayoutDashboard className="h-4 w-4" /> Dashboard
            </div>
            <h1 className="text-3xl font-bold tracking-tight">ZeaVis Edu Workspace</h1>
            <p className="text-muted-foreground">Masuk sebagai {user?.name ?? 'pengguna'} untuk diagnosis daun jagung.</p>
          </div>
          <div className="flex flex-wrap gap-3">
            {user?.role === 'expert' && <Button asChild variant="outline"><Link to="/expert/reviews"><ShieldCheck className="mr-2 h-4 w-4" /> Review Pakar</Link></Button>}
            <Button variant="outline" onClick={toggleDashboardCompact}>{dashboardCompact ? 'Mode Nyaman' : 'Mode Ringkas'}</Button>
            <Button variant="outline" onClick={() => logoutMutation.mutate()}><LogOut className="mr-2 h-4 w-4" /> Keluar</Button>
          </div>
        </header>

        {isLoadingData && <Card className="p-8 text-center text-muted-foreground">Memuat data dashboard...</Card>}
        {hasError && <Card className="p-8 text-center text-red-600">Gagal memuat data dashboard</Card>}

        {!isLoadingData && !hasError && (
          <>
            {summary && (
              <section className={dashboardCompact ? 'grid gap-4 md:grid-cols-4' : 'grid gap-6 md:grid-cols-4'}>
                <Card><CardHeader className="pb-3"><CardTitle className="text-sm font-medium text-muted-foreground">Total Penyakit</CardTitle></CardHeader><CardContent><div className="text-3xl font-bold">{summary.diseaseCount}</div></CardContent></Card>
                <Card><CardHeader className="pb-3"><CardTitle className="text-sm font-medium text-muted-foreground">Diagnosis Saya</CardTitle></CardHeader><CardContent><div className="text-3xl font-bold">{summary.imageClassificationCount}</div></CardContent></Card>
                <Card><CardHeader className="pb-3"><CardTitle className="text-sm font-medium text-muted-foreground">Perlu Review</CardTitle></CardHeader><CardContent><div className="text-3xl font-bold text-amber-600">{summary.needsReviewCount}</div></CardContent></Card>
                <Card><CardHeader className="pb-3"><CardTitle className="text-sm font-medium text-muted-foreground">Risiko Tinggi</CardTitle></CardHeader><CardContent><div className="text-3xl font-bold text-red-600">{summary.riskDistribution.high}</div></CardContent></Card>
              </section>
            )}

            <section className={dashboardCompact ? 'grid gap-4 md:grid-cols-2' : 'grid gap-6 md:grid-cols-2'}>
              <Card>
                <CardHeader><CardTitle className="flex items-center gap-2"><BookOpen className="h-5 w-5" /> Katalog Penyakit</CardTitle><CardDescription>Pelajari tentang {diseases.length} penyakit daun jagung</CardDescription></CardHeader>
                <CardContent><Button asChild className="w-full"><Link to="/catalog">Buka Katalog</Link></Button></CardContent>
              </Card>
              <Card>
                <CardHeader><CardTitle className="flex items-center gap-2"><TrendingUp className="h-5 w-5" /> Distribusi Risiko</CardTitle><CardDescription>Penyakit berdasarkan tingkat risiko</CardDescription></CardHeader>
                <CardContent>{summary && <div className="space-y-2 text-sm text-muted-foreground"><div className="flex justify-between"><span>Risiko Tinggi</span><b>{summary.riskDistribution.high}</b></div><div className="flex justify-between"><span>Risiko Sedang</span><b>{summary.riskDistribution.medium}</b></div><div className="flex justify-between"><span>Risiko Rendah</span><b>{summary.riskDistribution.low}</b></div></div>}</CardContent>
              </Card>
            </section>

            <ImageClassificationForm
              onSubmit={async (file) => { await createDiagnosisMutation.mutateAsync(file); }}
              isSubmitting={createDiagnosisMutation.isPending}
              latestResult={diagnoses[0] ?? null}
            />

            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2"><History className="h-5 w-5" /> Riwayat Diagnosis</CardTitle>
                <CardDescription>{diagnoses.length} diagnosis tersimpan</CardDescription>
              </CardHeader>
              <CardContent className="grid gap-4 md:grid-cols-2">
                {diagnoses.length === 0 && <p className="text-sm text-muted-foreground">Belum ada diagnosis.</p>}
                {diagnoses.slice(0, 8).map((diagnosis) => <DiagnosisCard key={diagnosis.id} diagnosis={diagnosis} />)}
              </CardContent>
            </Card>
          </>
        )}
      </div>
    </main>
  );
}
```

- [ ] **Step 3: Run typecheck**

Run: `bun run typecheck`

Expected: Remaining errors should be only missing expert review route/page or backend route type issues.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/components/image-classification-form.tsx apps/web/src/pages/dashboard-page.tsx
git commit -m "feat: migrate dashboard to diagnosis workflow"
```

---

## Task 11: Add expert review page

**Files:**
- Create: `apps/web/src/pages/expert-reviews-page.tsx`
- Modify: `apps/web/src/app.tsx`

- [ ] **Step 1: Create expert reviews page**

Write `apps/web/src/pages/expert-reviews-page.tsx` with this content:

```tsx
import { FormEvent, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useMutation, useQueries, useQueryClient } from '@tanstack/react-query';
import type { DiseaseSlug } from '@zeavis/shared';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DiagnosisCard } from '@/components/diagnosis-card';
import { DiagnosisStatusBadge } from '@/components/diagnosis-status-badge';
import { apiClient } from '@/lib/api-client';

export function ExpertReviewsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const selectedId = searchParams.get('diagnosis');
  const [verdict, setVerdict] = useState<'verified' | 'corrected'>('verified');
  const [correctedDiseaseSlug, setCorrectedDiseaseSlug] = useState<DiseaseSlug | ''>('');
  const [notes, setNotes] = useState('');
  const queryClient = useQueryClient();

  const [reviewsQuery, diseasesQuery] = useQueries({
    queries: [
      { queryKey: ['expert-reviews'], queryFn: () => apiClient.getExpertReviews() },
      { queryKey: ['diseases'], queryFn: () => apiClient.getDiseases() },
    ],
  });

  const reviews = reviewsQuery.data || [];
  const diseases = diseasesQuery.data || [];
  const selected = useMemo(() => reviews.find((item) => item.id === selectedId) ?? reviews[0] ?? null, [reviews, selectedId]);

  const mutation = useMutation({
    mutationFn: () => apiClient.reviewDiagnosis(selected!.id, {
      verdict,
      correctedDiseaseSlug: verdict === 'corrected' ? correctedDiseaseSlug || undefined : undefined,
      notes,
    }),
    onSuccess: () => {
      setNotes('');
      setVerdict('verified');
      setCorrectedDiseaseSlug('');
      queryClient.invalidateQueries({ queryKey: ['expert-reviews'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-summary'] });
    },
  });

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selected) return;
    await mutation.mutateAsync();
  }

  return (
    <main className="min-h-screen px-6 py-8">
      <div className="mx-auto max-w-6xl space-y-6">
        <header className="flex items-center justify-between gap-4">
          <div>
            <p className="text-sm font-medium text-primary">Expert Review</p>
            <h1 className="text-3xl font-bold">Antrean Review Pakar</h1>
          </div>
          <Button asChild variant="outline"><Link to="/dashboard">Dashboard</Link></Button>
        </header>

        <section className="grid gap-6 lg:grid-cols-[360px_1fr]">
          <Card>
            <CardHeader>
              <CardTitle>Perlu Review</CardTitle>
              <CardDescription>{reviews.length} diagnosis confidence rendah</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              {reviewsQuery.isLoading && <p className="text-sm text-muted-foreground">Memuat antrean...</p>}
              {reviews.length === 0 && !reviewsQuery.isLoading && <p className="text-sm text-muted-foreground">Tidak ada antrean review.</p>}
              {reviews.map((diagnosis) => (
                <button key={diagnosis.id} className="block w-full text-left" onClick={() => setSearchParams({ diagnosis: diagnosis.id })}>
                  <DiagnosisCard diagnosis={diagnosis} expertLink />
                </button>
              ))}
            </CardContent>
          </Card>

          {selected && (
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <CardTitle>{selected.disease?.commonName ?? 'Diagnosis gagal'}</CardTitle>
                    <CardDescription>Confidence {selected.confidence === null ? '-' : `${(selected.confidence * 100).toFixed(1)}%`}</CardDescription>
                  </div>
                  <DiagnosisStatusBadge status={selected.status} />
                </div>
              </CardHeader>
              <CardContent className="space-y-5">
                <img src={selected.imageUrl} alt="Daun jagung" className="max-h-80 rounded-xl object-cover" />
                <div className="space-y-2">
                  {selected.predictions.map((prediction) => (
                    <div key={prediction.id} className="flex justify-between rounded-lg border p-3 text-sm">
                      <span>{prediction.rank}. {prediction.modelLabel}</span>
                      <span className="font-semibold">{(prediction.confidence * 100).toFixed(1)}%</span>
                    </div>
                  ))}
                </div>
                <form className="space-y-4" onSubmit={handleSubmit}>
                  <div className="flex gap-4 text-sm">
                    <label><input type="radio" checked={verdict === 'verified'} onChange={() => setVerdict('verified')} /> Verifikasi hasil AI</label>
                    <label><input type="radio" checked={verdict === 'corrected'} onChange={() => setVerdict('corrected')} /> Koreksi label</label>
                  </div>
                  {verdict === 'corrected' && (
                    <select className="w-full rounded-md border bg-background p-2" value={correctedDiseaseSlug} onChange={(event) => setCorrectedDiseaseSlug(event.target.value as DiseaseSlug)} required>
                      <option value="">Pilih label koreksi</option>
                      {diseases.map((disease) => <option key={disease.slug} value={disease.slug}>{disease.commonName}</option>)}
                    </select>
                  )}
                  <textarea className="min-h-28 w-full rounded-md border bg-background p-3" value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Catatan pakar" required />
                  {mutation.error && <p className="text-sm text-red-600">{mutation.error instanceof Error ? mutation.error.message : 'Review gagal'}</p>}
                  <Button type="submit" disabled={mutation.isPending}>{mutation.isPending ? 'Menyimpan...' : 'Simpan Review'}</Button>
                </form>
              </CardContent>
            </Card>
          )}
        </section>
      </div>
    </main>
  );
}
```

- [ ] **Step 2: Register expert route**

Modify `apps/web/src/app.tsx` imports:

```ts
import { ExpertReviewsPage } from '@/pages/expert-reviews-page';
```

Add route:

```tsx
{
  path: '/expert/reviews',
  element: (
    <AuthGuard requireExpert>
      <ExpertReviewsPage />
    </AuthGuard>
  ),
},
```

- [ ] **Step 3: Run typecheck**

Run: `bun run typecheck`

Expected: Frontend routes typecheck.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/pages/expert-reviews-page.tsx apps/web/src/app.tsx
git commit -m "feat: add expert review UI"
```

---

## Task 12: Generate migrations and run full verification

**Files:**
- Generated: `apps/api/drizzle/*.sql`
- Generated/modified: `apps/api/drizzle/meta/*.json`
- Verify: no source changes unless typecheck reveals required fixes

- [ ] **Step 1: Generate Drizzle migration**

Run: `cd apps/api && bun run db:generate`

Expected: A new SQL migration is generated under `apps/api/drizzle/` for users, sessions, diagnoses, diagnosis_predictions, and expert_reviews.

- [ ] **Step 2: Run full typecheck**

Run: `bun run typecheck`

Expected: PASS.

- [ ] **Step 3: Run production build**

Run: `bun run build`

Expected: PASS for shared, api, and web build tasks.

- [ ] **Step 4: Apply migration when DATABASE_URL is available**

Run: `cd apps/api && bun run db:migrate`

Expected: PASS against the configured PostgreSQL database. If `DATABASE_URL` is not available, record that migration application was not run and do not claim DB verification.

- [ ] **Step 5: Run the app for manual browser verification**

Run: `bun run dev`

Expected: API and web dev servers start through Moon.

- [ ] **Step 6: Manual happy path**

In the browser:

1. Open the web app.
2. Register a user with a unique email and password at least 8 characters.
3. Confirm redirect to `/dashboard`.
4. Upload a JPEG or PNG corn leaf image.
5. Confirm a diagnosis appears in history.
6. Open the diagnosis detail page.
7. Confirm image, disease, confidence, top predictions, status, and recommendations render.
8. Log out.
9. Log in as an expert user.
10. Open `/expert/reviews`.
11. Review a `needs_review` diagnosis.
12. Confirm it disappears from the queue and the diagnosis detail shows expert review notes.

Expected: All steps pass. If no low-confidence image is naturally available, temporarily lower the review threshold in local code for manual testing, verify the flow, then revert the threshold before committing.

- [ ] **Step 7: Manual error path**

In the browser or via API client:

1. Upload a `.txt` file and confirm a validation error.
2. Visit `/dashboard` after logout and confirm redirect to `/login`.
3. Log in as a normal user and visit `/expert/reviews`; confirm redirect to `/dashboard`.
4. Run without Google env and confirm the Google login button is hidden.

Expected: All error paths behave as specified.

- [ ] **Step 8: Commit migration and verification fixes**

```bash
git add apps/api/drizzle apps/api/drizzle/meta
git commit -m "feat: add production MVP database migration"
```

---

## Self-review notes

Spec coverage:

- Auth email/password, sessions, roles, and optional Google OAuth are covered in Tasks 2, 3, 7, and 8.
- PostgreSQL schema and migrations are covered in Tasks 2 and 12.
- External uploader integration is covered in Task 4.
- Backend TFJS classification persistence and top predictions are covered in Task 4.
- User dashboard/history/detail pages are covered in Tasks 9 and 10.
- Expert review queue and review submission are covered in Tasks 5 and 11.
- Error handling and verification are covered in Tasks 3, 4, 5, 10, 11, and 12.

Red-flag scan: no unresolved planning markers are intentionally present. The only implementation choice left to workers is resolving compile errors revealed by real typecheck output, which must be fixed directly before completing each task.

Type consistency: shared DTO names are introduced first and reused by backend/frontend tasks. Diagnosis status strings match the design spec.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
