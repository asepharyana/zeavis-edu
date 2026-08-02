# Rust ONNX ML Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Python FastAPI ML service with a Rust Axum service that serves ONNX Runtime inference while preserving the current API contract and deployment shape.

**Architecture:** `apps/ml-service` becomes a Rust binary crate with focused modules for config, routes, errors, image preprocessing, and ONNX inference. The ML pipeline keeps TensorFlow/Keras for training/export and adds ONNX conversion plus manual parity validation. Docker continues to publish an `ml` service listening on port `8000`.

**Tech Stack:** Rust, Axum, Tokio, Serde, image, ndarray, ort, Python TensorFlow/tf2onnx/onnxruntime for export validation, Docker.

---

## File structure

### Create

- `apps/ml-service/Cargo.toml` — Rust crate metadata and dependencies.
- `apps/ml-service/src/main.rs` — application startup, shared state, router binding.
- `apps/ml-service/src/config.rs` — environment parsing, constants, labels, model path resolution.
- `apps/ml-service/src/error.rs` — service error enum and Axum response mapping.
- `apps/ml-service/src/image.rs` — image decode, RGB conversion, resizing, NHWC float32 tensor creation.
- `apps/ml-service/src/model.rs` — ONNX Runtime session wrapper and prediction result mapping.
- `apps/ml-service/src/routes.rs` — `/health`, `/metadata`, and `/predict` handlers.
- `Machine_Learning/convert_onnx.py` — convert exported SavedModel to `model/model.onnx` using tf2onnx.
- `Machine_Learning/validate_onnx_parity.py` — manual parity check between Keras and ONNX for sample images.

### Modify

- `apps/ml-service/Dockerfile` — replace Python runtime with Rust multi-stage build and ONNX model copy.
- `apps/ml-service/moon.yml` — replace uvicorn/py_compile tasks with cargo tasks.
- `apps/ml-service/.env.example` — update default model path and port for Rust service.
- `Machine_Learning/requirements.txt` — add ONNX conversion/parity dependencies.
- `Machine_Learning/README.md` — document ONNX conversion and parity validation.
- `README.md` — update service description, prerequisites, endpoints, artifacts, and troubleshooting.

### Remove

- `apps/ml-service/main.py` — superseded by Rust Axum entrypoint.
- `apps/ml-service/model.py` — superseded by Rust ONNX model module.
- `apps/ml-service/schemas.py` — superseded by Rust response structs.
- `apps/ml-service/test_model.py` — superseded by Rust tests.
- `apps/ml-service/requirements.txt` — no longer used by serving runtime.

---

## Task 1: Create Rust crate skeleton and config

**Files:**
- Create: `apps/ml-service/Cargo.toml`
- Create: `apps/ml-service/src/main.rs`
- Create: `apps/ml-service/src/config.rs`

- [ ] **Step 1: Write crate manifest**

Create `apps/ml-service/Cargo.toml`:

```toml
[package]
name = "zeavis-ml-service"
version = "0.1.0"
edition = "2021"

[dependencies]
anyhow = "1.0"
axum = { version = "0.7", features = ["multipart"] }
image = "0.25"
ndarray = "0.15"
ort = "2.0.0-rc.10"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.0", features = ["macros", "rt-multi-thread", "net"] }
tower = "0.5"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

[dev-dependencies]
temp-env = "0.3"
```

- [ ] **Step 2: Write config tests first**

Create `apps/ml-service/src/config.rs` with only constants and tests initially:

```rust
use std::path::{Path, PathBuf};

pub const LABELS: [&str; 4] = ["Bercak Daun", "Daun Sehat", "Karat Daun", "Hawar Daun"];
pub const SERVICE_NAME: &str = "zeavis-ml-service";
pub const SERVICE_VERSION: &str = env!("CARGO_PKG_VERSION");
pub const DEFAULT_INPUT_SIZE: u32 = 224;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Config {
    pub host: String,
    pub port: u16,
    pub model_path: PathBuf,
    pub input_size: u32,
}

pub fn resolve_model_path(base_dir: &Path, model_path: &str) -> PathBuf {
    let path = PathBuf::from(model_path);
    if path.is_absolute() {
        path
    } else {
        base_dir.join(path)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn labels_match_training_class_order_with_display_names() {
        assert_eq!(LABELS, ["Bercak Daun", "Daun Sehat", "Karat Daun", "Hawar Daun"]);
    }

    #[test]
    fn relative_model_path_resolves_from_service_directory() {
        let base = Path::new("/repo/apps/ml-service");
        let resolved = resolve_model_path(base, "../../Machine_Learning/model/model.onnx");
        assert_eq!(resolved, PathBuf::from("/repo/apps/ml-service/../../Machine_Learning/model/model.onnx"));
    }

    #[test]
    fn absolute_model_path_is_preserved() {
        let base = Path::new("/repo/apps/ml-service");
        let resolved = resolve_model_path(base, "/models/model.onnx");
        assert_eq!(resolved, PathBuf::from("/models/model.onnx"));
    }
}
```

- [ ] **Step 3: Run tests and verify expected compile failure**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml
```

Expected: compilation fails because there is no `src/main.rs` target yet or because the crate has no complete binary entrypoint.

- [ ] **Step 4: Add minimal main file**

Create `apps/ml-service/src/main.rs`:

```rust
mod config;

fn main() {
    println!("zeavis-ml-service");
}
```

- [ ] **Step 5: Run tests and verify they pass**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml
```

Expected: all config tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/ml-service/Cargo.toml apps/ml-service/src/main.rs apps/ml-service/src/config.rs
git commit -m "feat: scaffold Rust ML service crate"
```

---

## Task 2: Implement environment config loading

**Files:**
- Modify: `apps/ml-service/src/config.rs`

- [ ] **Step 1: Add failing tests for environment defaults and overrides**

Append these tests inside the existing `#[cfg(test)] mod tests` in `apps/ml-service/src/config.rs`:

```rust
    #[test]
    fn config_uses_default_values_when_env_is_absent() {
        temp_env::with_vars_unset(
            ["ML_SERVICE_HOST", "ML_SERVICE_PORT", "MODEL_PATH", "MODEL_INPUT_SIZE"],
            || {
                let config = Config::from_env_with_base_dir(Path::new("/repo/apps/ml-service")).unwrap();

                assert_eq!(config.host, "0.0.0.0");
                assert_eq!(config.port, 8000);
                assert_eq!(config.input_size, 224);
                assert_eq!(
                    config.model_path,
                    PathBuf::from("/repo/apps/ml-service/../../Machine_Learning/model/model.onnx")
                );
            },
        );
    }

    #[test]
    fn config_reads_environment_overrides() {
        temp_env::with_vars(
            [
                ("ML_SERVICE_HOST", Some("127.0.0.1")),
                ("ML_SERVICE_PORT", Some("9000")),
                ("MODEL_PATH", Some("/tmp/model.onnx")),
                ("MODEL_INPUT_SIZE", Some("128")),
            ],
            || {
                let config = Config::from_env_with_base_dir(Path::new("/repo/apps/ml-service")).unwrap();

                assert_eq!(config.host, "127.0.0.1");
                assert_eq!(config.port, 9000);
                assert_eq!(config.input_size, 128);
                assert_eq!(config.model_path, PathBuf::from("/tmp/model.onnx"));
            },
        );
    }

    #[test]
    fn invalid_port_returns_error() {
        temp_env::with_vars(
            [("ML_SERVICE_PORT", Some("not-a-port"))],
            || {
                let error = Config::from_env_with_base_dir(Path::new("/repo/apps/ml-service")).unwrap_err();
                assert!(error.to_string().contains("ML_SERVICE_PORT"));
            },
        );
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml config
```

Expected: FAIL with `no function or associated item named 'from_env_with_base_dir'`.

- [ ] **Step 3: Implement config loader**

Replace the top-level implementation in `apps/ml-service/src/config.rs` with:

```rust
use anyhow::{Context, Result};
use std::env;
use std::path::{Path, PathBuf};

pub const LABELS: [&str; 4] = ["Bercak Daun", "Daun Sehat", "Karat Daun", "Hawar Daun"];
pub const SERVICE_NAME: &str = "zeavis-ml-service";
pub const SERVICE_VERSION: &str = env!("CARGO_PKG_VERSION");
pub const DEFAULT_INPUT_SIZE: u32 = 224;
pub const DEFAULT_MODEL_PATH: &str = "../../Machine_Learning/model/model.onnx";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Config {
    pub host: String,
    pub port: u16,
    pub model_path: PathBuf,
    pub input_size: u32,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        let base_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        Self::from_env_with_base_dir(&base_dir)
    }

    pub fn from_env_with_base_dir(base_dir: &Path) -> Result<Self> {
        let host = env::var("ML_SERVICE_HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
        let port = parse_env_u16("ML_SERVICE_PORT", 8000)?;
        let input_size = parse_env_u32("MODEL_INPUT_SIZE", DEFAULT_INPUT_SIZE)?;
        let model_path = env::var("MODEL_PATH").unwrap_or_else(|_| DEFAULT_MODEL_PATH.to_string());

        Ok(Self {
            host,
            port,
            model_path: resolve_model_path(base_dir, &model_path),
            input_size,
        })
    }
}

pub fn resolve_model_path(base_dir: &Path, model_path: &str) -> PathBuf {
    let path = PathBuf::from(model_path);
    if path.is_absolute() {
        path
    } else {
        base_dir.join(path)
    }
}

fn parse_env_u16(name: &str, default: u16) -> Result<u16> {
    match env::var(name) {
        Ok(value) => value
            .parse::<u16>()
            .with_context(|| format!("{name} must be a valid u16")),
        Err(_) => Ok(default),
    }
}

fn parse_env_u32(name: &str, default: u32) -> Result<u32> {
    match env::var(name) {
        Ok(value) => value
            .parse::<u32>()
            .with_context(|| format!("{name} must be a valid u32")),
        Err(_) => Ok(default),
    }
}
```

Keep the existing tests after this implementation.

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml config
```

Expected: all config tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/ml-service/src/config.rs apps/ml-service/Cargo.toml
git commit -m "feat: load ML service config from environment"
```

---

## Task 3: Implement HTTP error mapping and response schemas

**Files:**
- Create: `apps/ml-service/src/error.rs`
- Create: `apps/ml-service/src/routes.rs`
- Modify: `apps/ml-service/src/main.rs`

- [ ] **Step 1: Write error mapping tests**

Create `apps/ml-service/src/error.rs`:

```rust
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde::Serialize;

#[derive(Debug, Clone)]
pub enum ServiceError {
    BadRequest(String),
    ModelUnavailable(String),
    PredictionFailed(String),
}

#[derive(Serialize)]
struct ErrorResponse {
    detail: String,
}

impl IntoResponse for ServiceError {
    fn into_response(self) -> Response {
        let (status, detail) = match self {
            ServiceError::BadRequest(detail) => (StatusCode::BAD_REQUEST, detail),
            ServiceError::ModelUnavailable(detail) => (StatusCode::SERVICE_UNAVAILABLE, detail),
            ServiceError::PredictionFailed(detail) => (StatusCode::INTERNAL_SERVER_ERROR, detail),
        };

        (status, Json(ErrorResponse { detail })).into_response()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::to_bytes;

    #[tokio::test]
    async fn bad_request_maps_to_400() {
        let response = ServiceError::BadRequest("Uploaded file must be an image".to_string()).into_response();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);

        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let value: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(value["detail"], "Uploaded file must be an image");
    }

    #[tokio::test]
    async fn model_unavailable_maps_to_503() {
        let response = ServiceError::ModelUnavailable("Model is not loaded".to_string()).into_response();
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[tokio::test]
    async fn prediction_failed_maps_to_500() {
        let response = ServiceError::PredictionFailed("Prediction failed".to_string()).into_response();
        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }
}
```

- [ ] **Step 2: Run error tests and verify module is not wired**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml error
```

Expected: FAIL because `error.rs` is not declared in `main.rs` yet.

- [ ] **Step 3: Wire module and create route response structs**

Replace `apps/ml-service/src/main.rs` with:

```rust
mod config;
mod error;
mod routes;

fn main() {
    println!("zeavis-ml-service");
}
```

Create `apps/ml-service/src/routes.rs`:

```rust
use crate::config::{LABELS, SERVICE_NAME, SERVICE_VERSION};
use serde::Serialize;
use std::collections::BTreeMap;

#[derive(Serialize)]
pub struct HealthResponse {
    pub status: &'static str,
    pub model_loaded: bool,
}

#[derive(Serialize)]
pub struct MetadataResponse {
    pub service_name: &'static str,
    pub service_version: &'static str,
    pub model_path: String,
    pub model_loaded: bool,
    pub input_size: u32,
    pub labels: Vec<&'static str>,
}

#[derive(Debug, Serialize, PartialEq)]
pub struct PredictionResponse {
    pub label: String,
    pub confidence: f32,
    pub probabilities: BTreeMap<String, f32>,
}

pub fn health_response(model_loaded: bool) -> HealthResponse {
    HealthResponse {
        status: "ok",
        model_loaded,
    }
}

pub fn metadata_response(model_path: String, model_loaded: bool, input_size: u32) -> MetadataResponse {
    MetadataResponse {
        service_name: SERVICE_NAME,
        service_version: SERVICE_VERSION,
        model_path,
        model_loaded,
        input_size,
        labels: LABELS.to_vec(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn health_response_matches_existing_contract() {
        let response = health_response(false);
        let value = serde_json::to_value(response).unwrap();

        assert_eq!(value["status"], "ok");
        assert_eq!(value["model_loaded"], false);
    }

    #[test]
    fn metadata_response_matches_existing_contract() {
        let response = metadata_response("/models/model.onnx".to_string(), true, 224);
        let value = serde_json::to_value(response).unwrap();

        assert_eq!(value["service_name"], "zeavis-ml-service");
        assert_eq!(value["service_version"], env!("CARGO_PKG_VERSION"));
        assert_eq!(value["model_path"], "/models/model.onnx");
        assert_eq!(value["model_loaded"], true);
        assert_eq!(value["input_size"], 224);
        assert_eq!(value["labels"], serde_json::json!(["Bercak Daun", "Daun Sehat", "Karat Daun", "Hawar Daun"]));
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml error routes
```

Expected: error and route response tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/ml-service/src/main.rs apps/ml-service/src/error.rs apps/ml-service/src/routes.rs
git commit -m "feat: define ML service API responses"
```

---

## Task 4: Implement image preprocessing

**Files:**
- Create: `apps/ml-service/src/image.rs`
- Modify: `apps/ml-service/src/main.rs`

- [ ] **Step 1: Write preprocessing tests**

Create `apps/ml-service/src/image.rs`:

```rust
use crate::error::ServiceError;
use ndarray::Array4;

pub fn preprocess_image(_bytes: &[u8], _input_size: u32) -> Result<Array4<f32>, ServiceError> {
    unimplemented!("preprocess image bytes")
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{DynamicImage, ImageFormat, RgbImage};
    use std::io::Cursor;

    fn png_bytes() -> Vec<u8> {
        let mut image = RgbImage::new(2, 1);
        image.put_pixel(0, 0, image::Rgb([10, 20, 30]));
        image.put_pixel(1, 0, image::Rgb([40, 50, 60]));

        let mut bytes = Vec::new();
        DynamicImage::ImageRgb8(image)
            .write_to(&mut Cursor::new(&mut bytes), ImageFormat::Png)
            .unwrap();
        bytes
    }

    #[test]
    fn preprocess_returns_nhwc_float32_batch() {
        let tensor = preprocess_image(&png_bytes(), 2).unwrap();

        assert_eq!(tensor.shape(), &[1, 2, 2, 3]);
        assert_eq!(tensor[[0, 0, 0, 0]], 10.0);
        assert_eq!(tensor[[0, 0, 0, 1]], 20.0);
        assert_eq!(tensor[[0, 0, 0, 2]], 30.0);
    }

    #[test]
    fn invalid_image_returns_bad_request() {
        let error = preprocess_image(b"not an image", 224).unwrap_err();

        match error {
            ServiceError::BadRequest(detail) => assert_eq!(detail, "Uploaded file is not a valid image"),
            other => panic!("expected bad request, got {other:?}"),
        }
    }
}
```

- [ ] **Step 2: Wire module and run tests to verify failure**

Add `mod image;` to `apps/ml-service/src/main.rs`:

```rust
mod config;
mod error;
mod image;
mod routes;

fn main() {
    println!("zeavis-ml-service");
}
```

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml image
```

Expected: FAIL because `preprocess_image` is unimplemented.

- [ ] **Step 3: Implement preprocessing**

Replace `apps/ml-service/src/image.rs` implementation section above the tests with:

```rust
use crate::error::ServiceError;
use image::imageops::FilterType;
use ndarray::Array4;

pub fn preprocess_image(bytes: &[u8], input_size: u32) -> Result<Array4<f32>, ServiceError> {
    let image = image::load_from_memory(bytes)
        .map_err(|_| ServiceError::BadRequest("Uploaded file is not a valid image".to_string()))?
        .to_rgb8();

    let resized = image::imageops::resize(&image, input_size, input_size, FilterType::Triangle);
    let size = input_size as usize;
    let mut tensor = Array4::<f32>::zeros((1, size, size, 3));

    for (x, y, pixel) in resized.enumerate_pixels() {
        let x = x as usize;
        let y = y as usize;
        tensor[[0, y, x, 0]] = pixel[0] as f32;
        tensor[[0, y, x, 1]] = pixel[1] as f32;
        tensor[[0, y, x, 2]] = pixel[2] as f32;
    }

    Ok(tensor)
}
```

Keep the existing tests below this implementation.

- [ ] **Step 4: Run image tests and verify they pass**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml image
```

Expected: image preprocessing tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/ml-service/src/main.rs apps/ml-service/src/image.rs
git commit -m "feat: preprocess uploaded images in Rust"
```

---

## Task 5: Implement ONNX model wrapper

**Files:**
- Create: `apps/ml-service/src/model.rs`
- Modify: `apps/ml-service/src/main.rs`

- [ ] **Step 1: Write prediction mapping tests**

Create `apps/ml-service/src/model.rs`:

```rust
use crate::config::LABELS;
use crate::error::ServiceError;
use ndarray::Array4;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[derive(Debug, PartialEq)]
pub struct Prediction {
    pub label: String,
    pub confidence: f32,
    pub probabilities: BTreeMap<String, f32>,
}

pub struct ModelService {
    model_path: PathBuf,
    input_size: u32,
    loaded: bool,
}

impl ModelService {
    pub fn new(_model_path: &Path, _input_size: u32) -> Self {
        unimplemented!("create model service")
    }

    pub fn is_loaded(&self) -> bool {
        self.loaded
    }

    pub fn model_path(&self) -> &Path {
        &self.model_path
    }

    pub fn input_size(&self) -> u32 {
        self.input_size
    }

    pub fn predict(&self, _input: Array4<f32>) -> Result<Prediction, ServiceError> {
        unimplemented!("run ONNX inference")
    }
}

pub fn prediction_from_probabilities(probabilities: &[f32]) -> Result<Prediction, ServiceError> {
    if probabilities.len() != LABELS.len() {
        return Err(ServiceError::PredictionFailed("Prediction failed".to_string()));
    }

    let mut top_index = 0usize;
    let mut top_value = probabilities[0];
    let mut mapped = BTreeMap::new();

    for (index, label) in LABELS.iter().enumerate() {
        let value = probabilities[index];
        if value > top_value {
            top_index = index;
            top_value = value;
        }
        mapped.insert((*label).to_string(), value);
    }

    Ok(Prediction {
        label: LABELS[top_index].to_string(),
        confidence: top_value,
        probabilities: mapped,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prediction_mapping_selects_top_label_and_all_probabilities() {
        let prediction = prediction_from_probabilities(&[0.1, 0.2, 0.6, 0.1]).unwrap();

        assert_eq!(prediction.label, "Karat Daun");
        assert_eq!(prediction.confidence, 0.6);
        assert_eq!(prediction.probabilities["Bercak Daun"], 0.1);
        assert_eq!(prediction.probabilities["Daun Sehat"], 0.2);
        assert_eq!(prediction.probabilities["Karat Daun"], 0.6);
        assert_eq!(prediction.probabilities["Hawar Daun"], 0.1);
    }

    #[test]
    fn prediction_mapping_rejects_wrong_output_length() {
        let error = prediction_from_probabilities(&[0.1, 0.2]).unwrap_err();

        match error {
            ServiceError::PredictionFailed(detail) => assert_eq!(detail, "Prediction failed"),
            other => panic!("expected prediction failure, got {other:?}"),
        }
    }
}
```

- [ ] **Step 2: Wire module and run tests to verify current failures**

Add `mod model;` to `apps/ml-service/src/main.rs`:

```rust
mod config;
mod error;
mod image;
mod model;
mod routes;

fn main() {
    println!("zeavis-ml-service");
}
```

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml model
```

Expected: mapping tests pass, but `ModelService::new` and `predict` are still unimplemented for runtime behavior.

- [ ] **Step 3: Implement ONNX session storage**

Replace `apps/ml-service/src/model.rs` with:

```rust
use crate::config::LABELS;
use crate::error::ServiceError;
use ndarray::Array4;
use ort::session::Session;
use ort::value::TensorRef;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

#[derive(Debug, PartialEq)]
pub struct Prediction {
    pub label: String,
    pub confidence: f32,
    pub probabilities: BTreeMap<String, f32>,
}

pub struct ModelService {
    model_path: PathBuf,
    input_size: u32,
    session: Option<Mutex<Session>>,
}

impl ModelService {
    pub fn new(model_path: &Path, input_size: u32) -> Self {
        let session = Session::builder()
            .and_then(|builder| builder.commit_from_file(model_path))
            .map(Mutex::new)
            .ok();

        Self {
            model_path: model_path.to_path_buf(),
            input_size,
            session,
        }
    }

    pub fn is_loaded(&self) -> bool {
        self.session.is_some()
    }

    pub fn model_path(&self) -> &Path {
        &self.model_path
    }

    pub fn input_size(&self) -> u32 {
        self.input_size
    }

    pub fn predict(&self, input: Array4<f32>) -> Result<Prediction, ServiceError> {
        let session = self
            .session
            .as_ref()
            .ok_or_else(|| ServiceError::ModelUnavailable("Model is not loaded".to_string()))?;

        let input = TensorRef::from_array_view(input.view())
            .map_err(|_| ServiceError::PredictionFailed("Prediction failed".to_string()))?;
        let mut session = session
            .lock()
            .map_err(|_| ServiceError::PredictionFailed("Prediction failed".to_string()))?;
        let outputs = session
            .run(ort::inputs![input])
            .map_err(|_| ServiceError::PredictionFailed("Prediction failed".to_string()))?;
        let output = outputs
            .values()
            .next()
            .ok_or_else(|| ServiceError::PredictionFailed("Prediction failed".to_string()))?;
        let probabilities = output
            .try_extract_tensor::<f32>()
            .map_err(|_| ServiceError::PredictionFailed("Prediction failed".to_string()))?;
        let probabilities: Vec<f32> = probabilities.view().iter().copied().collect();

        prediction_from_probabilities(&probabilities)
    }
}

pub fn prediction_from_probabilities(probabilities: &[f32]) -> Result<Prediction, ServiceError> {
    if probabilities.len() != LABELS.len() {
        return Err(ServiceError::PredictionFailed("Prediction failed".to_string()));
    }

    let mut top_index = 0usize;
    let mut top_value = probabilities[0];
    let mut mapped = BTreeMap::new();

    for (index, label) in LABELS.iter().enumerate() {
        let value = probabilities[index];
        if value > top_value {
            top_index = index;
            top_value = value;
        }
        mapped.insert((*label).to_string(), value);
    }

    Ok(Prediction {
        label: LABELS[top_index].to_string(),
        confidence: top_value,
        probabilities: mapped,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prediction_mapping_selects_top_label_and_all_probabilities() {
        let prediction = prediction_from_probabilities(&[0.1, 0.2, 0.6, 0.1]).unwrap();

        assert_eq!(prediction.label, "Karat Daun");
        assert_eq!(prediction.confidence, 0.6);
        assert_eq!(prediction.probabilities["Bercak Daun"], 0.1);
        assert_eq!(prediction.probabilities["Daun Sehat"], 0.2);
        assert_eq!(prediction.probabilities["Karat Daun"], 0.6);
        assert_eq!(prediction.probabilities["Hawar Daun"], 0.1);
    }

    #[test]
    fn prediction_mapping_rejects_wrong_output_length() {
        let error = prediction_from_probabilities(&[0.1, 0.2]).unwrap_err();

        match error {
            ServiceError::PredictionFailed(detail) => assert_eq!(detail, "Prediction failed"),
            other => panic!("expected prediction failure, got {other:?}"),
        }
    }

    #[test]
    fn missing_model_file_creates_unloaded_service() {
        let service = ModelService::new(Path::new("/missing/model.onnx"), 224);

        assert!(!service.is_loaded());
        assert_eq!(service.model_path(), Path::new("/missing/model.onnx"));
        assert_eq!(service.input_size(), 224);
    }
}
```

- [ ] **Step 4: Run model tests and fix any ort API mismatch**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml model
```

Expected: all model tests pass. If the `ort` API differs from the snippets above, inspect compiler errors and update only `ModelService::new` and `ModelService::predict` to the equivalent current `ort` calls while preserving the public methods and tests.

- [ ] **Step 5: Commit**

```bash
git add apps/ml-service/src/main.rs apps/ml-service/src/model.rs apps/ml-service/Cargo.toml
git commit -m "feat: add ONNX model inference wrapper"
```

---

## Task 6: Implement Axum routes and app startup

**Files:**
- Modify: `apps/ml-service/src/routes.rs`
- Modify: `apps/ml-service/src/main.rs`

- [ ] **Step 1: Add app state and route handler tests**

Replace `apps/ml-service/src/routes.rs` with:

```rust
use crate::config::{LABELS, SERVICE_NAME, SERVICE_VERSION};
use crate::error::ServiceError;
use crate::image::preprocess_image;
use crate::model::{ModelService, Prediction};
use axum::extract::{Multipart, State};
use axum::{routing::get, routing::post, Json, Router};
use serde::Serialize;
use std::collections::BTreeMap;
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub model: Arc<ModelService>,
}

#[derive(Serialize)]
pub struct HealthResponse {
    pub status: &'static str,
    pub model_loaded: bool,
}

#[derive(Serialize)]
pub struct MetadataResponse {
    pub service_name: &'static str,
    pub service_version: &'static str,
    pub model_path: String,
    pub model_loaded: bool,
    pub input_size: u32,
    pub labels: Vec<&'static str>,
}

#[derive(Debug, Serialize, PartialEq)]
pub struct PredictionResponse {
    pub label: String,
    pub confidence: f32,
    pub probabilities: BTreeMap<String, f32>,
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/metadata", get(metadata))
        .route("/predict", post(predict))
        .with_state(state)
}

pub async fn health(State(state): State<AppState>) -> Json<HealthResponse> {
    Json(health_response(state.model.is_loaded()))
}

pub async fn metadata(State(state): State<AppState>) -> Json<MetadataResponse> {
    Json(metadata_response(
        state.model.model_path().display().to_string(),
        state.model.is_loaded(),
        state.model.input_size(),
    ))
}

pub async fn predict(
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> Result<Json<PredictionResponse>, ServiceError> {
    let mut image_bytes = None;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|_| ServiceError::BadRequest("Uploaded file must be an image".to_string()))?
    {
        if field.name() == Some("file") {
            if let Some(content_type) = field.content_type() {
                if !content_type.starts_with("image/") {
                    return Err(ServiceError::BadRequest("Uploaded file must be an image".to_string()));
                }
            }

            image_bytes = Some(
                field
                    .bytes()
                    .await
                    .map_err(|_| ServiceError::BadRequest("Uploaded file must be an image".to_string()))?,
            );
            break;
        }
    }

    let image_bytes = image_bytes
        .ok_or_else(|| ServiceError::BadRequest("Uploaded file must be an image".to_string()))?;
    let input = preprocess_image(&image_bytes, state.model.input_size())?;
    let prediction = state.model.predict(input)?;

    Ok(Json(prediction_response(prediction)))
}

pub fn health_response(model_loaded: bool) -> HealthResponse {
    HealthResponse {
        status: "ok",
        model_loaded,
    }
}

pub fn metadata_response(model_path: String, model_loaded: bool, input_size: u32) -> MetadataResponse {
    MetadataResponse {
        service_name: SERVICE_NAME,
        service_version: SERVICE_VERSION,
        model_path,
        model_loaded,
        input_size,
        labels: LABELS.to_vec(),
    }
}

pub fn prediction_response(prediction: Prediction) -> PredictionResponse {
    PredictionResponse {
        label: prediction.label,
        confidence: prediction.confidence,
        probabilities: prediction.probabilities,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::prediction_from_probabilities;

    #[test]
    fn health_response_matches_existing_contract() {
        let response = health_response(false);
        let value = serde_json::to_value(response).unwrap();

        assert_eq!(value["status"], "ok");
        assert_eq!(value["model_loaded"], false);
    }

    #[test]
    fn metadata_response_matches_existing_contract() {
        let response = metadata_response("/models/model.onnx".to_string(), true, 224);
        let value = serde_json::to_value(response).unwrap();

        assert_eq!(value["service_name"], "zeavis-ml-service");
        assert_eq!(value["service_version"], env!("CARGO_PKG_VERSION"));
        assert_eq!(value["model_path"], "/models/model.onnx");
        assert_eq!(value["model_loaded"], true);
        assert_eq!(value["input_size"], 224);
        assert_eq!(value["labels"], serde_json::json!(["Bercak Daun", "Daun Sehat", "Karat Daun", "Hawar Daun"]));
    }

    #[test]
    fn prediction_response_matches_existing_contract() {
        let prediction = prediction_from_probabilities(&[0.1, 0.2, 0.6, 0.1]).unwrap();
        let response = prediction_response(prediction);
        let value = serde_json::to_value(response).unwrap();

        assert_eq!(value["label"], "Karat Daun");
        assert_eq!(value["confidence"], 0.6);
        assert_eq!(value["probabilities"]["Karat Daun"], 0.6);
    }
}
```

- [ ] **Step 2: Run route tests**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml routes
```

Expected: route response tests pass.

- [ ] **Step 3: Implement async main startup**

Replace `apps/ml-service/src/main.rs` with:

```rust
mod config;
mod error;
mod image;
mod model;
mod routes;

use anyhow::Context;
use config::Config;
use model::ModelService;
use routes::{router, AppState};
use std::sync::Arc;
use tokio::net::TcpListener;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let config = Config::from_env()?;
    let model = Arc::new(ModelService::new(&config.model_path, config.input_size));
    let address = format!("{}:{}", config.host, config.port);
    let listener = TcpListener::bind(&address)
        .await
        .with_context(|| format!("failed to bind {address}"))?;

    tracing::info!(address, model_loaded = model.is_loaded(), "starting ML service");

    axum::serve(listener, router(AppState { model })).await?;

    Ok(())
}
```

- [ ] **Step 4: Run full Rust tests and build**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml
cargo build --manifest-path apps/ml-service/Cargo.toml --release
```

Expected: tests pass and release binary builds.

- [ ] **Step 5: Commit**

```bash
git add apps/ml-service/src/routes.rs apps/ml-service/src/main.rs
git commit -m "feat: serve ML inference endpoints with Axum"
```

---

## Task 7: Replace ML service runtime files and tasks

**Files:**
- Modify: `apps/ml-service/moon.yml`
- Modify: `apps/ml-service/.env.example`
- Remove: `apps/ml-service/main.py`
- Remove: `apps/ml-service/model.py`
- Remove: `apps/ml-service/schemas.py`
- Remove: `apps/ml-service/test_model.py`
- Remove: `apps/ml-service/requirements.txt`

- [ ] **Step 1: Update Moon tasks**

Replace `apps/ml-service/moon.yml` with:

```yaml
tasks:
  dev:
    command: cargo run
  typecheck:
    command: cargo check
    inputs:
      - Cargo.toml
      - src/**/*.rs
  test:
    command: cargo test
    inputs:
      - Cargo.toml
      - src/**/*.rs
  build:
    command: cargo build --release
    inputs:
      - Cargo.toml
      - src/**/*.rs
```

- [ ] **Step 2: Update local env example**

Replace `apps/ml-service/.env.example` with:

```env
MODEL_PATH=../../Machine_Learning/model/model.onnx
MODEL_INPUT_SIZE=224
ML_SERVICE_HOST=0.0.0.0
ML_SERVICE_PORT=8001
```

- [ ] **Step 3: Remove Python serving files**

Run:

```bash
rm apps/ml-service/main.py apps/ml-service/model.py apps/ml-service/schemas.py apps/ml-service/test_model.py apps/ml-service/requirements.txt
```

Expected: Python service files are removed. Do not remove `.venv` or `__pycache__` in this task unless they are tracked by git.

- [ ] **Step 4: Run Rust service checks**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml
cargo check --manifest-path apps/ml-service/Cargo.toml
```

Expected: tests and check pass.

- [ ] **Step 5: Commit**

```bash
git add apps/ml-service/moon.yml apps/ml-service/.env.example apps/ml-service/Cargo.toml apps/ml-service/src
git rm apps/ml-service/main.py apps/ml-service/model.py apps/ml-service/schemas.py apps/ml-service/test_model.py apps/ml-service/requirements.txt
git commit -m "refactor: replace Python ML service runtime with Rust"
```

---

## Task 8: Add ONNX conversion script

**Files:**
- Create: `Machine_Learning/convert_onnx.py`
- Modify: `Machine_Learning/requirements.txt`

- [ ] **Step 1: Add conversion dependencies**

Append these lines to `Machine_Learning/requirements.txt` if they are not present:

```txt
tf2onnx>=1.16.1
onnx>=1.16.0
onnxruntime>=1.17.0
```

- [ ] **Step 2: Write conversion script**

Create `Machine_Learning/convert_onnx.py`:

```python
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys


DEFAULT_SAVED_MODEL_PATH = Path("model/saved_model")
DEFAULT_OUTPUT_PATH = Path("model/model.onnx")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert ZeaVis SavedModel export to ONNX.")
    parser.add_argument("--saved-model", type=Path, default=DEFAULT_SAVED_MODEL_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_PATH)
    parser.add_argument("--opset", type=int, default=13)
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if not args.saved_model.exists():
        raise FileNotFoundError(f"SavedModel directory not found: {args.saved_model}")

    args.output.parent.mkdir(parents=True, exist_ok=True)

    command = [
        sys.executable,
        "-m",
        "tf2onnx.convert",
        "--saved-model",
        str(args.saved_model),
        "--output",
        str(args.output),
        "--opset",
        str(args.opset),
    ]
    subprocess.run(command, check=True)
    print(f"ONNX model exported to {args.output}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Compile-check script**

Run:

```bash
python -m py_compile Machine_Learning/convert_onnx.py
```

Expected: command exits successfully.

- [ ] **Step 4: Commit**

```bash
git add Machine_Learning/requirements.txt Machine_Learning/convert_onnx.py
git commit -m "feat: add ONNX conversion script"
```

---

## Task 9: Add manual Keras vs ONNX parity validation

**Files:**
- Create: `Machine_Learning/validate_onnx_parity.py`

- [ ] **Step 1: Write parity validation script**

Create `Machine_Learning/validate_onnx_parity.py`:

```python
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, UnidentifiedImageError
import tensorflow as tf


LABELS = ["Bercak Daun", "Daun Sehat", "Karat Daun", "Hawar Daun"]
DEFAULT_KERAS_MODEL_PATH = Path("best_model/best_model.keras")
DEFAULT_ONNX_MODEL_PATH = Path("model/model.onnx")


class ParityError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Keras and ONNX predictions match for sample images.")
    parser.add_argument("images", nargs="+", type=Path)
    parser.add_argument("--keras-model", type=Path, default=DEFAULT_KERAS_MODEL_PATH)
    parser.add_argument("--onnx-model", type=Path, default=DEFAULT_ONNX_MODEL_PATH)
    parser.add_argument("--input-size", type=int, default=224)
    parser.add_argument("--atol", type=float, default=1e-4)
    return parser.parse_args()


def preprocess_image(image_path: Path, input_size: int) -> np.ndarray:
    try:
        image = Image.open(image_path).convert("RGB")
    except (UnidentifiedImageError, OSError) as exc:
        raise ParityError(f"Invalid image: {image_path}") from exc

    image = image.resize((input_size, input_size))
    image_array = np.asarray(image, dtype=np.float32)
    return np.expand_dims(image_array, axis=0)


def predict_keras(model: tf.keras.Model, batch: np.ndarray) -> np.ndarray:
    return np.asarray(model.predict(batch, verbose=0)[0], dtype=np.float32)


def predict_onnx(session: ort.InferenceSession, batch: np.ndarray) -> np.ndarray:
    input_name = session.get_inputs()[0].name
    predictions = session.run(None, {input_name: batch})[0][0]
    return np.asarray(predictions, dtype=np.float32)


def validate_image(image_path: Path, keras_model: tf.keras.Model, onnx_session: ort.InferenceSession, input_size: int, atol: float) -> None:
    batch = preprocess_image(image_path, input_size)
    keras_probs = predict_keras(keras_model, batch)
    onnx_probs = predict_onnx(onnx_session, batch)

    keras_top = int(np.argmax(keras_probs))
    onnx_top = int(np.argmax(onnx_probs))

    if keras_top != onnx_top:
        raise ParityError(
            f"Top-1 mismatch for {image_path}: Keras={LABELS[keras_top]} ONNX={LABELS[onnx_top]}"
        )

    if not np.allclose(keras_probs, onnx_probs, atol=atol):
        raise ParityError(
            f"Probability mismatch for {image_path}: Keras={keras_probs.tolist()} ONNX={onnx_probs.tolist()}"
        )

    print(f"PASS {image_path}: {LABELS[keras_top]}")


def main() -> None:
    args = parse_args()

    if not args.keras_model.exists():
        raise FileNotFoundError(f"Keras model not found: {args.keras_model}")
    if not args.onnx_model.exists():
        raise FileNotFoundError(f"ONNX model not found: {args.onnx_model}")

    keras_model = tf.keras.models.load_model(args.keras_model, compile=False)
    onnx_session = ort.InferenceSession(str(args.onnx_model), providers=["CPUExecutionProvider"])

    for image_path in args.images:
        validate_image(image_path, keras_model, onnx_session, args.input_size, args.atol)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Compile-check script**

Run:

```bash
python -m py_compile Machine_Learning/validate_onnx_parity.py
```

Expected: command exits successfully.

- [ ] **Step 3: Commit**

```bash
git add Machine_Learning/validate_onnx_parity.py
git commit -m "test: add ONNX parity validation script"
```

---

## Task 10: Update Docker image for Rust ML service

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.

**Files:**
- Modify: `apps/ml-service/Dockerfile`

- [ ] **Step 1: Replace Dockerfile with Rust multi-stage image**

Replace `apps/ml-service/Dockerfile` with:

```dockerfile
FROM rust:1.82-bookworm AS builder

WORKDIR /app
COPY apps/ml-service/Cargo.toml ./Cargo.toml
COPY apps/ml-service/src ./src
RUN cargo build --release

FROM debian:bookworm-slim AS runner

WORKDIR /app
ENV MODEL_PATH=/app/model/model.onnx
ENV MODEL_INPUT_SIZE=224
ENV ML_SERVICE_HOST=0.0.0.0
ENV ML_SERVICE_PORT=8000
ENV RUST_LOG=info

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/zeavis-ml-service /usr/local/bin/zeavis-ml-service
COPY Machine_Learning/model/model.onnx /app/model/model.onnx

EXPOSE 8000
CMD ["zeavis-ml-service"]
```

- [ ] **Step 2: Build Rust binary before Docker build**

Run:

```bash
cargo build --manifest-path apps/ml-service/Cargo.toml --release
```

Expected: release binary builds locally.

- [ ] **Step 3: Document model artifact requirement for Docker build in commit context**

Run:

```bash
git diff -- apps/ml-service/Dockerfile
```

Expected: Dockerfile copies `Machine_Learning/model/model.onnx`; Docker build will require this generated artifact just like the previous image required `best_model.keras`.

- [ ] **Step 4: Commit**

```bash
git add apps/ml-service/Dockerfile
git commit -m "build: containerize Rust ML service"
```

---

## Task 11: Update README documentation

**Files:**
- Modify: `README.md`
- Modify: `Machine_Learning/README.md`
- Create or Modify: `apps/ml-service/README.md`

- [ ] **Step 1: Update root README ML service sections**

In `README.md`, make these exact content changes:

- Replace `ML service berbasis FastAPI untuk inferensi penyakit daun jagung dari gambar.` with `ML service berbasis Rust, Axum, dan ONNX Runtime untuk inferensi penyakit daun jagung dari gambar.`
- Replace tech stack bullets `Python`, `TensorFlow/Keras`, `EfficientNetV2B0`, `FastAPI`, `Uvicorn`, `TFLite`, `TensorFlow.js` under `### Machine Learning` with:

```markdown
- Python untuk preprocessing, training, dan ekspor model
- TensorFlow/Keras
- EfficientNetV2B0
- Rust
- Axum
- ONNX Runtime
- TFLite
- TensorFlow.js
```

- Replace the ML service local run block with:

```markdown
### ML Service

```bash
cd apps/ml-service
cargo run
```

Default path model adalah:

```text
../../Machine_Learning/model/model.onnx
```

Jika model berada di lokasi lain, gunakan environment variable `MODEL_PATH`.
```

- Add `Machine_Learning/model/model.onnx` to artifact tables and generated artifact lists as the ONNX model used by the Rust service.
- Replace troubleshooting that points to `best_model.keras` for serving with `Machine_Learning/model/model.onnx` and show:

```bash
MODEL_PATH=/path/to/model.onnx cargo run
```

- [ ] **Step 2: Update Machine Learning README export section**

In `Machine_Learning/README.md`, after the SavedModel/TFLite export instructions, add this section:

```markdown
### Langkah 2: Konversi ke ONNX (untuk Rust ML Service)

Setelah `model/saved_model/` tersedia, jalankan:

```bash
python convert_onnx.py
```

Output default:

```text
model/model.onnx
```

Model ONNX ini digunakan oleh service Rust di `apps/ml-service`.

Untuk memvalidasi hasil ONNX terhadap model Keras, jalankan parity check manual dengan satu atau lebih gambar contoh:

```bash
python validate_onnx_parity.py /path/to/corn-leaf.jpg
```

Validasi ini mengecek label top-1 dan kedekatan probabilitas antara Keras dan ONNX.
```

Also add `model/model.onnx` to the final output table with usage `Inferensi server-side via Rust ONNX Runtime`.

- [ ] **Step 3: Create ML service README**

Create `apps/ml-service/README.md`:

```markdown
# ZeaVis ML Service

Rust service for corn leaf disease inference using Axum and ONNX Runtime.

## Requirements

- Rust stable toolchain
- ONNX model at `../../Machine_Learning/model/model.onnx`

## Run locally

```bash
cargo run
```

The service listens on `0.0.0.0:8001` when `ML_SERVICE_PORT=8001` is set in local env files. In production Docker it listens on port `8000`.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `MODEL_PATH` | `../../Machine_Learning/model/model.onnx` | ONNX model path |
| `MODEL_INPUT_SIZE` | `224` | Input image size |
| `ML_SERVICE_HOST` | `0.0.0.0` | Bind host |
| `ML_SERVICE_PORT` | `8000` | Bind port |

## Endpoints

```bash
curl http://localhost:8001/health
curl http://localhost:8001/metadata
curl -X POST http://localhost:8001/predict -F "file=@/path/to/corn-leaf.jpg"
```

## Verification

```bash
cargo test
cargo build --release
```
```

- [ ] **Step 4: Review documentation for stale FastAPI/Uvicorn runtime references**

Run:

```bash
grep -R "FastAPI\|Uvicorn\|uvicorn\|best_model.keras" -n README.md apps/ml-service Machine_Learning/README.md
```

Expected: FastAPI/Uvicorn should not appear as the current serving runtime. `best_model.keras` may still appear only in training/export documentation.

- [ ] **Step 5: Commit**

```bash
git add README.md Machine_Learning/README.md apps/ml-service/README.md
git commit -m "docs: document Rust ONNX ML service"
```

---

## Task 12: Final verification

**Files:**
- No planned edits unless verification finds a defect.

- [ ] **Step 1: Run Rust tests**

Run:

```bash
cargo test --manifest-path apps/ml-service/Cargo.toml
```

Expected: all tests pass.

- [ ] **Step 2: Run Rust release build**

Run:

```bash
cargo build --manifest-path apps/ml-service/Cargo.toml --release
```

Expected: release build succeeds.

- [ ] **Step 3: Compile-check ML scripts**

Run:

```bash
python -m py_compile Machine_Learning/convert_onnx.py Machine_Learning/validate_onnx_parity.py
```

Expected: command exits successfully.

- [ ] **Step 4: Run root typecheck if available**

Run:

```bash
bun run typecheck
```

Expected: Moon typecheck tasks pass. If this fails because the root workspace assumes Python files that were removed, update the relevant Moon task to point at Rust cargo commands and rerun.

- [ ] **Step 5: Optional endpoint verification with real ONNX model**

Only run this if `Machine_Learning/model/model.onnx` exists:

```bash
cd apps/ml-service
ML_SERVICE_PORT=8001 cargo run
```

In another shell:

```bash
curl http://localhost:8001/health
curl http://localhost:8001/metadata
curl -X POST http://localhost:8001/predict -F "file=@/path/to/corn-leaf.jpg"
```

Expected: `/health` and `/metadata` return JSON matching the existing contract. `/predict` returns `label`, `confidence`, and `probabilities` when a valid image is provided.

- [ ] **Step 6: Inspect git status**

Run:

```bash
git status --short
```

Expected: no unintended untracked files. Large generated artifacts such as `model.onnx` should not be committed unless repository policy explicitly allows it.

- [ ] **Step 7: Commit verification fixes if any**

If verification required fixes, commit them:

```bash
git add <changed-files>
git commit -m "fix: align Rust ML service verification"
```

If no fixes were needed, do not create an empty commit.

---

## Self-review notes

- Spec coverage: Rust Axum replacement, API compatibility, ONNX runtime, preprocessing, ONNX conversion, parity validation, Docker, docs, and verification are all mapped to tasks.
- Placeholder scan: no `TBD`, `TODO`, `FIXME`, or intentionally vague implementation steps remain.
- Type consistency: config, route response, model prediction, and error names are consistent across tasks.
