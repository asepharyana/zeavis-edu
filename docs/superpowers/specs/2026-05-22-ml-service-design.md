# ML Service Design

## Summary

Add a separate Python FastAPI inference service at `apps/ml-service`. The existing `Machine_Learning` directory remains responsible for model training, preprocessing, and export artifacts. The new service is responsible only for serving image classification predictions from the trained Keras model.

## Goals

- Serve corn leaf disease predictions through a small HTTP API.
- Keep TensorFlow/Keras runtime dependencies out of the Bun/Elysia API app.
- Keep the capstone deployment simple and easy to debug.
- Preserve `Machine_Learning` as the source for model artifacts and training workflow.

## Non-goals

- Do not introduce TensorFlow Serving.
- Do not switch to TFLite for the first implementation.
- Do not move the ML training/export pipeline into `apps/ml-service`.
- Do not add frontend UI changes in this scope.

## Architecture

`apps/ml-service` will be a standalone FastAPI application. It will load a Keras model from a configurable path, defaulting to the trained model artifact under `Machine_Learning/best_model/best_model.keras`.

The service exposes three endpoints:

- `GET /health` returns service health and whether the model is loaded.
- `GET /metadata` returns model/service metadata such as labels, input size, configured model path, and model loaded status.
- `POST /predict` accepts one uploaded image and returns the predicted Indonesian disease label, confidence, and class probabilities.

The existing TypeScript backend can later call this ML service over HTTP. That integration is outside this first service-scaffolding scope unless explicitly requested after the service exists.

## Components

- `apps/ml-service/main.py` creates the FastAPI app and defines routes.
- `apps/ml-service/model.py` owns model loading, image preprocessing, and prediction.
- `apps/ml-service/schemas.py` defines response models for health, metadata, and prediction responses.
- `apps/ml-service/requirements.txt` lists Python runtime dependencies: FastAPI, Uvicorn, TensorFlow, Pillow, and multipart upload support.
- `apps/ml-service/.env.example` documents runtime configuration such as `MODEL_PATH`, `MODEL_INPUT_SIZE`, and port.

## Runtime configuration

- `MODEL_PATH` controls the Keras model path. Default: `../../Machine_Learning/best_model/best_model.keras` relative to `apps/ml-service`.
- `MODEL_INPUT_SIZE` controls image resize dimensions. Default should match the trained EfficientNetV2B0 pipeline input size.
- `ML_SERVICE_HOST` and `ML_SERVICE_PORT` document how to run the service locally.

## Data flow for `POST /predict`

1. Client uploads an image as multipart form data.
2. Service validates that the upload is an image.
3. Service opens the image with Pillow, converts it to RGB, and resizes it to the configured input size.
4. Image pixels are converted to a batch tensor using the same normalization expected by the Keras model.
5. The loaded model returns class probabilities for the four labels.
6. Service returns JSON containing the top label, confidence, and probability per label.

## Labels

The model predicts the existing four Indonesian labels:

- `Bercak Daun`
- `Hawar Daun`
- `Karat Daun`
- `Daun Sehat`

The service must preserve this label order consistently with the trained model output.

## Error handling

- If the model cannot be loaded, `GET /health` returns a successful response with `model_loaded: false`.
- If the model is not loaded, `POST /predict` returns `503 Service Unavailable`.
- If the uploaded file is not an image or cannot be decoded, `POST /predict` returns `400 Bad Request`.
- If inference fails unexpectedly, `POST /predict` returns `500 Internal Server Error` with a generic message.
- `GET /metadata` still returns static metadata even when the model is not loaded, including `model_loaded` status.

## Verification

Manual verification for the initial implementation:

- Start the service with Uvicorn from `apps/ml-service`.
- Call `GET /health` and confirm the response includes service status and model loaded status.
- Call `GET /metadata` and confirm labels, input size, model path, and model loaded status are present.
- Call `POST /predict` with a real image file when an example corn leaf image is available.

The repository does not currently have a Python test suite for this new service. Automated tests can be added later if the service grows beyond the initial capstone scope.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
