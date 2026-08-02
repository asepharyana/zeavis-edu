# Rust ONNX ML Service Migration Design

## Goal

Replace the current Python/FastAPI ML serving runtime with a Rust service that uses Axum and ONNX Runtime while preserving the existing HTTP contract, deployment shape, and model labels. The migration also adds an ONNX conversion path so the Keras/SavedModel training output can produce the model artifact used by the Rust service.

## Current context

The existing service lives in `apps/ml-service` and exposes three endpoints:

- `GET /health`
- `GET /metadata`
- `POST /predict`

It loads a Keras model from `MODEL_PATH`, defaults to `../../Machine_Learning/best_model/best_model.keras`, preprocesses uploaded images as RGB resized to `224x224`, sends a float32 NHWC batch to the model, and returns the top label, confidence, and all label probabilities.

Deployment already expects an `ml` service listening on port `8000`, with API integration configured through `ML_SERVICE_URL`.

## Decisions

- Replace the Python serving code fully rather than running Python and Rust side by side.
- Use Rust with Axum for the HTTP server.
- Use the `ort` crate for ONNX Runtime inference.
- Keep the current API contract for `/health`, `/metadata`, and `/predict`.
- Keep the current preprocessing behavior: RGB, resize to `224x224`, float32 tensor, NHWC shape `[1, 224, 224, 3]`, no additional normalization.
- Keep deployment compatibility: service name `ml`, internal port `8000`.
- Add ONNX conversion to the ML export workflow.
- Add parity validation as a manual verification command because model artifacts and sample images are not guaranteed to exist in fresh clones or CI.

## Architecture

`apps/ml-service` becomes a Rust binary crate. The service is split into small modules:

- `main.rs`: startup, configuration loading, Axum router, TCP listener.
- `config.rs`: environment variables, defaults, labels, service metadata.
- `routes.rs`: HTTP handlers and response types.
- `model.rs`: ONNX session loading and prediction.
- `image.rs`: upload image decoding and preprocessing.
- `error.rs`: typed errors mapped to HTTP responses.

The default model path changes to `../../Machine_Learning/model/model.onnx`. `MODEL_PATH` can still override the path. `MODEL_INPUT_SIZE` defaults to `224`.

## API contract

### `GET /health`

Returns:

```json
{
  "status": "ok",
  "model_loaded": true
}
```

The endpoint still responds even if the model failed to load, with `model_loaded: false`.

### `GET /metadata`

Returns:

```json
{
  "service_name": "zeavis-ml-service",
  "service_version": "0.1.0",
  "model_path": ".../Machine_Learning/model/model.onnx",
  "model_loaded": true,
  "input_size": 224,
  "labels": ["Bercak Daun", "Daun Sehat", "Karat Daun", "Hawar Daun"]
}
```

### `POST /predict`

Accepts multipart form data with field `file`. Returns:

```json
{
  "label": "Karat Daun",
  "confidence": 0.98,
  "probabilities": {
    "Bercak Daun": 0.01,
    "Daun Sehat": 0.0,
    "Karat Daun": 0.98,
    "Hawar Daun": 0.01
  }
}
```

## Data flow

1. Client uploads an image to `/predict` as multipart field `file`.
2. The route validates that a file is present and that the content type is an image when provided.
3. `image.rs` decodes the image, converts it to RGB, resizes it to `MODEL_INPUT_SIZE x MODEL_INPUT_SIZE`, casts pixels to `f32`, and creates an NHWC tensor with batch dimension.
4. `model.rs` runs the tensor through ONNX Runtime.
5. The output vector is mapped to the fixed Indonesian labels.
6. The service selects the highest-probability label and returns all probabilities.

## ONNX export pipeline

The ML pipeline keeps the current Keras and SavedModel exports, then adds an ONNX output:

1. Training produces `Machine_Learning/best_model/best_model.keras`.
2. `Machine_Learning/save_model.py` continues exporting SavedModel and TFLite.
3. A new conversion command or script produces `Machine_Learning/model/model.onnx` from the exported SavedModel or Keras model.
4. Documentation explains required Python dependencies and the exact command to regenerate `model.onnx`.

The ONNX artifact is generated/local like the existing model exports and may not exist in a fresh clone.

## Parity validation

Parity validation compares Keras and ONNX predictions for the same sample images. It is a manual verification command, not a required CI test.

The validation should check:

- Top-1 label matches.
- Probability vectors are numerically close within an explicit tolerance.
- The preprocessing used for comparison matches the Rust service: RGB resize, float32 NHWC, no extra normalization.

If parity fails, the migration should stop until conversion input shape, preprocessing, or output mapping is corrected.

## Error handling

The Rust service maps errors to the same behavior as the current Python service:

- Missing file or non-image upload: `400`.
- Invalid image bytes or decode failure: `400`.
- Model not loaded: `503`.
- Unexpected inference failure: `500`.

Startup should try to load the model and keep the service alive if loading fails so `/health` and `/metadata` can report `model_loaded: false`.

## Testing and verification

Required local verification:

- `cargo test` from `apps/ml-service`.
- `cargo build --release` from `apps/ml-service`.
- Manual endpoint checks with `curl` for `/health`, `/metadata`, and `/predict` when `model.onnx` is available.
- Manual parity validation when both Keras and ONNX artifacts plus sample images are available.

The repository has no existing global test suite, so the Rust service checks become the primary verification for this migration.

## Documentation and deployment updates

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.

Update documentation so runtime serving no longer describes FastAPI/TensorFlow as the production ML service. Keep Python/TensorFlow documentation for training and export.

Update:

- Root `README.md`.
- `apps/ml-service/README.md`.
- `Machine_Learning/README.md` where export artifacts and ONNX conversion are described.
- Dockerfile or deployment files that build the `ml` image.

Deployment remains compatible with the existing `ml` service and port `8000` expectation.

## Out of scope

- Changing the model architecture or class labels.
- Retraining the model.
- Changing API/backend integration contracts.
- Adding GPU acceleration.
- Making parity validation mandatory in CI.
