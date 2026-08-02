# API ML Service Migration Design

## Summary

Migrate `apps/api` image classification from in-process TensorFlow.js inference to the separate FastAPI ML service at `apps/ml-service`. The public API behavior and database writes stay the same; only the model inference boundary changes.

## Goals

- Remove TensorFlow.js model loading and image decoding from the Bun/Elysia API runtime.
- Keep existing route behavior for image classifications and diagnoses.
- Use `apps/ml-service` as the single runtime owner for Keras/TensorFlow inference.
- Preserve the internal `classifyImage(file)` API shape used by existing routes.

## Non-goals

- Do not change frontend behavior.
- Do not change database schema.
- Do not add a fallback to TFJS inference.
- Do not migrate upload storage or diagnosis workflows beyond the inference call.

## Architecture

`apps/api/src/lib/image-model.ts` remains the API-side classification boundary. Its implementation changes from local TFJS inference to an HTTP client for the ML service.

`classifyImage(file)` will:

1. Build multipart `FormData` with field name `file`.
2. POST it to `${env.mlServiceUrl}/predict`.
3. Validate the ML service response.
4. Map returned Indonesian labels to API disease slugs.
5. Return the existing `ClassificationResult` shape:
   - `predictedDiseaseSlug`
   - `confidence`
   - `probabilities`

Existing route files continue to call `classifyImage(file)`, so route and database logic remain stable.

## Runtime configuration

Add `mlServiceUrl` to `apps/api/src/config/env.ts`.

Default local value:

```txt
http://127.0.0.1:8001
```

Environment variable:

```txt
ML_SERVICE_URL=http://127.0.0.1:8001
```

The API should trim trailing slashes before appending `/predict` so both `http://127.0.0.1:8001` and `http://127.0.0.1:8001/` work.

## Label mapping

The ML service returns labels. The API maps labels to catalog slugs:

- `Bercak Daun` → `bercak-daun`
- `Daun Sehat` → `daun-sehat`
- `Karat Daun` → `karat-daun`
- `Hawar Daun` → `hawar-daun`

This mapping follows the trained model output order handled by the ML service while preserving API/catalog slugs.

## Error handling

`classifyImage(file)` throws `Error` when:

- The input file MIME type is not `image/jpeg` or `image/png`.
- The ML service cannot be reached.
- The ML service returns a non-2xx response.
- The ML service response is malformed.
- The ML service returns a label that does not map to a known disease slug.

Existing routes keep their current behavior:

- `POST /api/v1/classifications/image` catches the error and returns service unavailable with `Model service error: ...`.
- `POST /api/v1/diagnoses` catches the error and stores a failed diagnosis record.

## Dependency cleanup

Remove API dependencies that only supported local TFJS inference:

- `@tensorflow/tfjs`
- `jpeg-js`
- `pngjs`

Keep dependencies needed by routes, database, auth, and upload unchanged.

## Verification

Required verification after implementation:

- Run API typecheck with `bun run typecheck` from the repository root.
- Confirm no `@tensorflow/tfjs`, `jpeg-js`, or `pngjs` imports remain under `apps/api/src`.
- Start `apps/ml-service` and confirm `GET /health` returns `model_loaded: true` when the Keras model exists.
- Exercise `classifyImage(file)` against the running ML service with a local image file or synthetic image and confirm it returns `predictedDiseaseSlug`, `confidence`, and sorted probabilities.

If full API route testing is blocked by external database or upload service requirements, report that explicitly and include the lower-level verification evidence.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
