# ZeaVis Edu Production MVP Design

## Goal

Build a production-style MVP demo for ZeaVis Edu where authenticated users can upload corn leaf images, receive AI diagnosis results, track diagnosis history, and route low-confidence cases to expert review.

The MVP should feel complete end-to-end while staying focused on corn leaf disease diagnosis, education, and review workflows.

## Scope

### In scope

- Email/password registration, login, logout, and authenticated session handling.
- Google OAuth support when required environment variables are configured.
- User roles: `user` and `expert`.
- PostgreSQL-backed persistence with Drizzle migrations.
- Image upload through the external uploader at `https://upload.asepharyana.tech`.
- Backend image classification with the existing TensorFlow.js model integration.
- Diagnosis records with top-k predictions, confidence, image metadata, and review status.
- User dashboard, diagnosis history, diagnosis detail page, and expert review queue.
- Existing disease catalog and disease detail pages remain available.

### Out of scope

- Anonymous diagnosis history.
- Memory or local-file database fallback.
- Production email delivery for magic links or notifications.
- Multi-crop disease support.
- Offline mobile/PWA behavior.
- Admin CMS for editing disease content.

## Architecture

The application remains a Bun + Moon monorepo with an Elysia API, React/Vite frontend, and shared TypeScript package.

### Backend modules

- `auth`: owns registration, login, logout, current-user lookup, password hashing, sessions, and optional Google OAuth routes.
- `diagnoses`: owns authenticated image diagnosis creation, diagnosis history, diagnosis detail retrieval, and diagnosis status transitions.
- `expert`: owns expert-only review queue and review submission.
- `diseases`: keeps the existing disease catalog API as the canonical disease label source.
- `uploader`: wraps the external upload API so the frontend never talks directly to the uploader service.
- `image-model`: keeps model loading and inference behind the existing backend classifier boundary.

### Frontend modules

- Auth pages: `/login` and `/register`.
- User workspace: `/dashboard` for upload, summary, recent diagnosis history, and catalog entry points.
- Diagnosis detail: `/diagnoses/:id` for result, image, top predictions, disease education, status, and expert notes.
- Expert workflow: `/expert/reviews` for low-confidence review queue and review actions.
- Existing catalog pages: `/catalog` and `/catalog/:slug`.

## Authentication and authorization

Email/password auth is required for the MVP. Passwords are stored only as secure hashes. Sessions are persisted in PostgreSQL and sent to the browser as HTTP-only cookies.

Google OAuth is optional. The API exposes Google OAuth routes only when `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and `GOOGLE_REDIRECT_URI` are all configured. The frontend hides the Google login button unless the API reports that OAuth is enabled.

Authorization rules:

- Unauthenticated users can access public landing and catalog content.
- Authenticated `user` accounts can create diagnoses and view only their own diagnoses.
- `expert` accounts can access the expert review queue and submit reviews.
- Expert accounts can also use normal user diagnosis features unless explicitly restricted later.

## Data model

### `users`

Stores identity and role data.

Fields:

- `id`
- `email`
- `name`
- `passwordHash` nullable for OAuth-only users
- `role`: `user` or `expert`
- `googleId` nullable
- `createdAt`
- `updatedAt`

### `sessions`

Stores server-side sessions.

Fields:

- `id`
- `userId`
- `tokenHash`
- `expiresAt`
- `createdAt`

### `diseases`

Continues to store the education catalog and canonical disease labels.

### `diagnoses`

Stores each uploaded classification request.

Fields:

- `id`
- `userId`
- `predictedDiseaseId` nullable when inference fails
- `imageUrl`
- `uploaderPublicId`
- `imageFileName`
- `imageMimeType`
- `imageSizeBytes`
- `confidence` nullable when inference fails
- `status`: `ai_verified`, `needs_review`, `expert_verified`, `expert_corrected`, or `failed`
- `failureReason` nullable
- `createdAt`
- `updatedAt`

Status rules:

- Confidence `>= 0.7` becomes `ai_verified`.
- Confidence `< 0.7` becomes `needs_review`.
- Expert verification changes status to `expert_verified`.
- Expert correction changes status to `expert_corrected`.
- Successful upload followed by inference failure creates `failed` with a failure reason.

### `diagnosis_predictions`

Stores top-k model predictions for each diagnosis.

Fields:

- `id`
- `diagnosisId`
- `diseaseId` nullable if a model label cannot be mapped
- `modelLabel`
- `confidence`
- `rank`

### `expert_reviews`

Stores expert decisions.

Fields:

- `id`
- `diagnosisId`
- `expertId`
- `verdict`: `verified` or `corrected`
- `correctedDiseaseId` nullable for verified results
- `notes`
- `createdAt`

## API design

### Auth

- `POST /auth/register`: creates a user account and session.
- `POST /auth/login`: creates a session for email/password credentials.
- `POST /auth/logout`: expires the current session.
- `GET /auth/me`: returns current user and feature flags such as Google OAuth availability.
- `GET /auth/google`: starts Google OAuth only when configured.
- `GET /auth/google/callback`: completes Google OAuth only when configured.

### Diagnoses

- `POST /diagnoses`: accepts multipart image upload, validates image constraints, uploads to the external uploader, runs model inference, stores diagnosis and predictions, and returns the created diagnosis.
- `GET /diagnoses`: returns diagnoses for the current user.
- `GET /diagnoses/:id`: returns one diagnosis if owned by the current user or accessible to the current expert.

### Expert review

- `GET /expert/reviews`: returns diagnoses with `needs_review` status.
- `POST /expert/reviews/:diagnosisId`: verifies or corrects a diagnosis and stores expert notes.

### Diseases

Existing disease catalog endpoints stay available and continue to back diagnosis result details.

## External uploader integration

The API integrates with `https://upload.asepharyana.tech` through a backend adapter.

Upload request:

- `POST /api/upload`
- `multipart/form-data`
- `file`: binary payload
- optional `fileName`

Stored response fields:

- `public_id`
- `download_url`
- `file_name`
- `mime_type`
- `size_bytes`
- `file_type`

The application stores `download_url` as the image URL shown in the UI and `public_id` for metadata/debugging. If the uploader fails, the diagnosis is not created and the API returns a clear upload failure response.

## User experience

### Standard user flow

1. User registers or logs in.
2. User opens the dashboard.
3. User uploads a corn leaf image and sees preview/progress.
4. API uploads, classifies, and stores the diagnosis.
5. User sees diagnosis result with image, disease, confidence, top predictions, status, and recommended actions.
6. User can revisit diagnosis history and details.

### Low-confidence flow

For confidence below 70%, the user still sees the AI result, but the status clearly says the result is awaiting expert review. The result page explains that the AI prediction is provisional.

### Expert flow

1. Expert logs in.
2. Expert opens `/expert/reviews`.
3. Expert sees all diagnoses needing review.
4. Expert opens a case, reviews the image and top predictions, then verifies or corrects the disease label with notes.
5. The user-facing diagnosis status updates to expert verified or expert corrected.

## Error handling

Validation happens at system boundaries:

- Registration and login payloads.
- Session cookie presence and validity.
- Role checks for expert endpoints.
- Upload file type and configured max size.
- Uploader response shape.
- Model label mapping to known disease records.

Failure behavior:

- Uploader failure returns an error and does not create a diagnosis.
- Inference failure after successful upload creates a `failed` diagnosis for auditability.
- Low confidence is not treated as an error; it routes to review.
- Missing Google OAuth env hides Google OAuth from the UI.

## Configuration

Required:

- `DATABASE_URL`
- `SESSION_SECRET`

Optional:

- `UPLOADER_BASE_URL`, defaulting to `https://upload.asepharyana.tech`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI`
- `UPLOAD_MAX_BYTES`
- `UPLOAD_ALLOWED_MIME_TYPES`

PostgreSQL is mandatory. The application should fail clearly during startup or first database access when `DATABASE_URL` is missing or invalid.

## Verification plan

Automated checks:

- `bun run typecheck`
- `bun run build`
- Drizzle migration generation/application check

Manual happy path:

1. Register a user.
2. Log in.
3. Upload a valid corn leaf image.
4. Confirm the diagnosis is saved and visible in history.
5. Confirm diagnosis detail shows image, top predictions, disease information, confidence, and status.
6. Log in as an expert.
7. Review a low-confidence diagnosis.
8. Confirm the user-facing diagnosis status and notes update.

Manual error path:

1. Upload a non-image file and confirm validation error.
2. Call a diagnosis endpoint while logged out and confirm unauthorized response.
3. Access expert review as a non-expert and confirm forbidden response.
4. Temporarily omit Google OAuth env and confirm Google login is hidden.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
