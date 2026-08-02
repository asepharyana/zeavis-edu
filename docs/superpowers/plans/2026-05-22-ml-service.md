# ML Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone FastAPI service at `apps/ml-service` that serves health, metadata, and corn leaf disease image predictions from the trained Keras model.

**Architecture:** The service is a small Python app separate from the Bun/Elysia API. `main.py` owns HTTP routes, `model.py` owns model loading/preprocessing/inference, and `schemas.py` defines response shapes. Runtime configuration is environment-variable based with safe defaults pointing back to `Machine_Learning/best_model/best_model.keras`.

**Tech Stack:** Python 3.9-3.11, FastAPI, Uvicorn, TensorFlow/Keras, Pillow, python-multipart, Pydantic.

---

## File Structure

Create these files:

- `apps/ml-service/requirements.txt` — Python dependencies for the inference service.
- `apps/ml-service/.env.example` — documented local configuration.
- `apps/ml-service/schemas.py` — Pydantic response models.
- `apps/ml-service/model.py` — model configuration, model loading, image preprocessing, and prediction logic.
- `apps/ml-service/main.py` — FastAPI app and route handlers.
- `apps/ml-service/README.md` — concise run and verification instructions for the service.

Modify these files:

- `.moon/workspace.yml` — register the Python service as a Moon project.
- `package.json` — include `apps/ml-service` in workspace discovery if needed by existing workspace pattern. No change is needed because `apps/*` already includes it.

Do not modify these files:

- `Machine_Learning/*` — remains the model pipeline and artifact location.
- `apps/api/*` — API-to-ML-service integration is out of scope for this plan.
- `apps/web/*` — frontend changes are out of scope.

---

### Task 1: Add service dependencies and configuration

**Files:**
- Create: `apps/ml-service/requirements.txt`
- Create: `apps/ml-service/.env.example`
- Modify: `.moon/workspace.yml`

- [ ] **Step 1: Create the service directory**

Run:

```bash
mkdir -p apps/ml-service
```

Expected: command exits successfully and `apps/ml-service` exists.

- [ ] **Step 2: Write dependency file**

Create `apps/ml-service/requirements.txt` with exactly:

```txt
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
tensorflow>=2.13.0
pillow>=10.0.0
python-multipart>=0.0.9
```

- [ ] **Step 3: Write example environment file**

Create `apps/ml-service/.env.example` with exactly:

```dotenv
MODEL_PATH=../../Machine_Learning/best_model/best_model.keras
MODEL_INPUT_SIZE=224
ML_SERVICE_HOST=0.0.0.0
ML_SERVICE_PORT=8001
```

- [ ] **Step 4: Register Moon project**

Modify `.moon/workspace.yml` so it becomes exactly:

```yaml
projects:
  web: apps/web
  api: apps/api
  ml-service: apps/ml-service
  shared: packages/shared
```

- [ ] **Step 5: Verify files are present**

Run:

```bash
ls apps/ml-service && grep -n "ml-service" .moon/workspace.yml
```

Expected: output includes `requirements.txt`, `.env.example` may not show because `ls` hides dotfiles, and `ml-service: apps/ml-service` appears from grep.

- [ ] **Step 6: Commit**

Run:

```bash
git add .moon/workspace.yml apps/ml-service/requirements.txt apps/ml-service/.env.example
git commit -m "feat: scaffold ML service configuration"
```

Expected: commit succeeds.

---

### Task 2: Add response schemas

**Files:**
- Create: `apps/ml-service/schemas.py`

- [ ] **Step 1: Write schemas**

Create `apps/ml-service/schemas.py` with exactly:

```python
from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool


class MetadataResponse(BaseModel):
    service_name: str
    service_version: str
    model_path: str
    model_loaded: bool
    input_size: int
    labels: list[str]


class PredictionResponse(BaseModel):
    label: str
    confidence: float
    probabilities: dict[str, float]
```

- [ ] **Step 2: Verify syntax**

Run:

```bash
python -m py_compile apps/ml-service/schemas.py
```

Expected: command exits with no output.

- [ ] **Step 3: Commit**

Run:

```bash
git add apps/ml-service/schemas.py
git commit -m "feat: add ML service response schemas"
```

Expected: commit succeeds.

---

### Task 3: Add model loading and prediction logic

**Files:**
- Create: `apps/ml-service/model.py`

- [ ] **Step 1: Write model module**

Create `apps/ml-service/model.py` with exactly:

```python
from io import BytesIO
import os
from pathlib import Path

import numpy as np
from PIL import Image, UnidentifiedImageError
import tensorflow as tf


LABELS = ["Bercak Daun", "Hawar Daun", "Karat Daun", "Daun Sehat"]
SERVICE_NAME = "zeavis-ml-service"
SERVICE_VERSION = "0.1.0"


class ImageDecodeError(ValueError):
    pass


class ModelService:
    def __init__(self) -> None:
        self.input_size = int(os.getenv("MODEL_INPUT_SIZE", "224"))
        self.model_path = self._resolve_model_path(os.getenv("MODEL_PATH", "../../Machine_Learning/best_model/best_model.keras"))
        self.model: tf.keras.Model | None = None
        self.load_error: str | None = None

    def _resolve_model_path(self, model_path: str) -> Path:
        path = Path(model_path)
        if path.is_absolute():
            return path
        return (Path(__file__).resolve().parent / path).resolve()

    @property
    def model_loaded(self) -> bool:
        return self.model is not None

    def load(self) -> None:
        try:
            self.model = tf.keras.models.load_model(self.model_path, compile=False)
            self.load_error = None
        except Exception as exc:
            self.model = None
            self.load_error = str(exc)

    def preprocess(self, image_bytes: bytes) -> np.ndarray:
        try:
            image = Image.open(BytesIO(image_bytes)).convert("RGB")
        except (UnidentifiedImageError, OSError) as exc:
            raise ImageDecodeError("Uploaded file is not a valid image") from exc

        image = image.resize((self.input_size, self.input_size))
        image_array = np.asarray(image, dtype=np.float32)
        return np.expand_dims(image_array, axis=0)

    def predict(self, image_bytes: bytes) -> tuple[str, float, dict[str, float]]:
        if self.model is None:
            raise RuntimeError("Model is not loaded")

        batch = self.preprocess(image_bytes)
        raw_predictions = self.model.predict(batch, verbose=0)[0]
        probabilities_array = np.asarray(raw_predictions, dtype=np.float32)
        top_index = int(np.argmax(probabilities_array))
        probabilities = {
            label: float(probabilities_array[index])
            for index, label in enumerate(LABELS)
        }

        return LABELS[top_index], float(probabilities_array[top_index]), probabilities


model_service = ModelService()
```

- [ ] **Step 2: Verify syntax**

Run:

```bash
python -m py_compile apps/ml-service/model.py
```

Expected: command exits with no output if TensorFlow and dependencies are installed in the active Python environment. If it fails with `ModuleNotFoundError: No module named 'tensorflow'`, install dependencies in a virtual environment before continuing:

```bash
python -m venv apps/ml-service/.venv
apps/ml-service/.venv/bin/pip install -r apps/ml-service/requirements.txt
apps/ml-service/.venv/bin/python -m py_compile apps/ml-service/model.py
```

Expected after dependency install: command exits with no output.

- [ ] **Step 3: Commit**

Run:

```bash
git add apps/ml-service/model.py
git commit -m "feat: add ML model prediction service"
```

Expected: commit succeeds.

---

### Task 4: Add FastAPI routes

**Files:**
- Create: `apps/ml-service/main.py`

- [ ] **Step 1: Write FastAPI app**

Create `apps/ml-service/main.py` with exactly:

```python
from fastapi import FastAPI, File, HTTPException, UploadFile

from model import ImageDecodeError, LABELS, SERVICE_NAME, SERVICE_VERSION, model_service
from schemas import HealthResponse, MetadataResponse, PredictionResponse


app = FastAPI(title="ZeaVis ML Service", version=SERVICE_VERSION)


@app.on_event("startup")
def load_model() -> None:
    model_service.load()


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", model_loaded=model_service.model_loaded)


@app.get("/metadata", response_model=MetadataResponse)
def metadata() -> MetadataResponse:
    return MetadataResponse(
        service_name=SERVICE_NAME,
        service_version=SERVICE_VERSION,
        model_path=str(model_service.model_path),
        model_loaded=model_service.model_loaded,
        input_size=model_service.input_size,
        labels=LABELS,
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict(file: UploadFile = File(...)) -> PredictionResponse:
    if file.content_type is None or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be an image")

    if not model_service.model_loaded:
        raise HTTPException(status_code=503, detail="Model is not loaded")

    image_bytes = await file.read()

    try:
        label, confidence, probabilities = model_service.predict(image_bytes)
    except ImageDecodeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Prediction failed") from exc

    return PredictionResponse(
        label=label,
        confidence=confidence,
        probabilities=probabilities,
    )
```

- [ ] **Step 2: Verify syntax**

Run with the service virtual environment if it exists:

```bash
apps/ml-service/.venv/bin/python -m py_compile apps/ml-service/main.py
```

If no virtual environment was created because dependencies were already installed globally, run:

```bash
python -m py_compile apps/ml-service/main.py
```

Expected: command exits with no output.

- [ ] **Step 3: Commit**

Run:

```bash
git add apps/ml-service/main.py
git commit -m "feat: add ML service API routes"
```

Expected: commit succeeds.

---

### Task 5: Add service documentation

**Files:**
- Create: `apps/ml-service/README.md`

- [ ] **Step 1: Write README**

Create `apps/ml-service/README.md` with exactly:

```markdown
# ZeaVis ML Service

FastAPI service for serving corn leaf disease predictions from the trained Keras model.

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

The default model path is `../../Machine_Learning/best_model/best_model.keras`. Override it with `MODEL_PATH` if needed.

## Run

```bash
uvicorn main:app --host 0.0.0.0 --port 8001
```

## Endpoints

- `GET /health` — service status and model loaded status.
- `GET /metadata` — service name, version, labels, input size, model path, and model loaded status.
- `POST /predict` — multipart image upload for disease classification.

## Verify

```bash
curl http://localhost:8001/health
curl http://localhost:8001/metadata
curl -X POST http://localhost:8001/predict -F "file=@/path/to/corn-leaf.jpg"
```
```

- [ ] **Step 2: Commit**

Run:

```bash
git add apps/ml-service/README.md
git commit -m "docs: add ML service usage guide"
```

Expected: commit succeeds.

---

### Task 6: Verify service behavior

**Files:**
- No code changes expected.

- [ ] **Step 1: Install dependencies if needed**

If `apps/ml-service/.venv` does not exist, run:

```bash
python -m venv apps/ml-service/.venv
apps/ml-service/.venv/bin/pip install -r apps/ml-service/requirements.txt
```

Expected: dependencies install successfully.

- [ ] **Step 2: Start the service**

Run:

```bash
cd apps/ml-service && .venv/bin/uvicorn main:app --host 127.0.0.1 --port 8001
```

Expected: Uvicorn starts and logs application startup. If `Machine_Learning/best_model/best_model.keras` is missing, the service should still start.

- [ ] **Step 3: Verify health endpoint**

In a second terminal, run:

```bash
curl -s http://127.0.0.1:8001/health
```

Expected when model is missing:

```json
{"status":"ok","model_loaded":false}
```

Expected when model exists and loads:

```json
{"status":"ok","model_loaded":true}
```

- [ ] **Step 4: Verify metadata endpoint**

Run:

```bash
curl -s http://127.0.0.1:8001/metadata
```

Expected: JSON includes these fields and labels:

```json
{
  "service_name": "zeavis-ml-service",
  "service_version": "0.1.0",
  "model_path": "/absolute/path/to/Machine_Learning/best_model/best_model.keras",
  "model_loaded": false,
  "input_size": 224,
  "labels": ["Bercak Daun", "Hawar Daun", "Karat Daun", "Daun Sehat"]
}
```

The exact absolute `model_path` value depends on the local checkout path.

- [ ] **Step 5: Verify predict unavailable when model is missing**

Run this only if `Machine_Learning/best_model/best_model.keras` is absent:

```bash
python - <<'PY'
from pathlib import Path
from PIL import Image

path = Path('/tmp/zeavis-test-image.jpg')
Image.new('RGB', (224, 224), color='green').save(path)
print(path)
PY
curl -s -o /tmp/zeavis-predict-response.json -w "%{http_code}\n" -X POST http://127.0.0.1:8001/predict -F "file=@/tmp/zeavis-test-image.jpg"
cat /tmp/zeavis-predict-response.json
```

Expected HTTP code: `503`

Expected response:

```json
{"detail":"Model is not loaded"}
```

- [ ] **Step 6: Verify predict success when model is present**

Run this only if `Machine_Learning/best_model/best_model.keras` exists:

```bash
curl -s -X POST http://127.0.0.1:8001/predict -F "file=@/path/to/real-corn-leaf-image.jpg"
```

Expected: JSON has `label`, `confidence`, and `probabilities`. `label` must be one of `Bercak Daun`, `Hawar Daun`, `Karat Daun`, or `Daun Sehat`.

- [ ] **Step 7: Stop the service**

Press `Ctrl+C` in the Uvicorn terminal.

Expected: server shuts down cleanly.

---

### Task 7: Final review and branch status

**Files:**
- Review all changed files.

- [ ] **Step 1: Check git status**

Run:

```bash
git status --short
```

Expected: no uncommitted changes if every task committed successfully.

- [ ] **Step 2: Review commit history**

Run:

```bash
git log --oneline -6
```

Expected: recent commits include the ML service configuration, schemas, model service, routes, and README commits.

- [ ] **Step 3: Summarize verification evidence**

Record in the final response:

```text
Verified:
- Python syntax compilation for schemas, model, and main app.
- FastAPI service starts on 127.0.0.1:8001.
- GET /health returns service status and model loaded status.
- GET /metadata returns labels, input size, model path, and model loaded status.
- POST /predict returns 503 when the model artifact is unavailable, or returns prediction JSON when the model artifact and sample image are available.
```

Expected: final response only claims checks that were actually run.

---

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.
