# Backend Image Classification Design

## Goal

Extend ZeaVis Edu from manual classification tracking into real image classification. The backend will accept uploaded corn leaf photos, upload the original image to the external uploader service, run the local TensorFlow.js model exported from `Machine_Learning/`, store the prediction, and return educational guidance tied to the predicted disease.

## Scope

This work includes:

- Backend image classification endpoint using the exported TensorFlow.js model at `Machine_Learning/model/tfjs_model/model.json`.
- Integration with `https://upload.asepharyana.tech/api/upload` using `multipart/form-data` field `file`.
- Database persistence for image classification history.
- Shared TypeScript response/request types for image classification and uploader metadata.
- Frontend upload flow, prediction result card, and image classification history.

This work does not include retraining the model, changing labels, or adding automatic batch processing.

## Architecture

The web app sends a selected image file to the API. The API validates the request, forwards the file to the uploader service, runs backend inference with the local TFJS graph model, maps model output to the four ZeaVis Edu labels, fetches disease education metadata from PostgreSQL, stores the classification result, and returns the complete prediction response.

The backend owns inference so model loading, preprocessing, label mapping, and confidence calculation remain consistent across clients. The frontend only handles image selection, upload progress state, result display, and history display.

## Model inference

The API loads the local TFJS model from `Machine_Learning/model/tfjs_model/model.json`. Model loading should be cached in process so normal requests do not reload the graph. Image preprocessing should decode the uploaded image, resize it to the EfficientNetV2B0 input size, normalize it consistently with the training/export pipeline, and produce a batched tensor.

Output probabilities map to labels in this order:

1. `Bercak Daun` / `bercak-daun`
2. `Hawar Daun` / `hawar-daun`
3. `Karat Daun` / `karat-daun`
4. `Daun Sehat` / `daun-sehat`

The API returns the highest-confidence label and the full class probability list.

## Uploader integration

The external uploader contract comes from `https://upload.asepharyana.tech/swagger.json`:

- `POST /api/upload`
- `multipart/form-data`
- required field: `file`
- optional field: `fileName`
- success response includes `public_id`, `file_name`, `mime_type`, `size_bytes`, `file_type`, `created_at`, and `download_url`.

The API should treat uploader failures as a bad gateway response because the local API is available but an upstream dependency failed.

## Database design

Add `image_classifications`:

- `id` UUID primary key
- `predicted_disease_slug` references `disease_catalog.slug`
- `confidence` numeric or real value
- `probabilities` JSON payload of class probabilities
- `image_url`
- `original_file_name`
- `uploader_public_id`
- `uploader_payload` JSON for the full uploader response
- `created_at`

Manual classifications remain separate from image classifications so the UI can show which records came from human observation versus model prediction.

## API design

Routes under `/api/v1`:

- `POST /classifications/image`: accepts image file, uploads it to the external uploader, runs TFJS inference, stores the result, and returns the image classification record with disease metadata.
- `GET /classifications/image`: returns recent image classifications with disease metadata.

Error responses:

- `400` for missing file or unsupported file type.
- `502` for uploader failure.
- `503` for model loading/inference failure or database failure.

## Frontend design

The dashboard adds an image upload form near the manual classification form. The form accepts image files only, sends the file to `POST /api/v1/classifications/image`, and shows the latest prediction result with image preview, label, confidence, and recommendations. Dashboard history shows manual records and image prediction records in separate sections.

## Verification

The implementation should pass:

- `bun run typecheck`
- `bun run build`

Manual verification should launch API and web locally, open the dashboard, select an image, submit it, and verify that uploader/model/database success or structured error states render without crashing.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
