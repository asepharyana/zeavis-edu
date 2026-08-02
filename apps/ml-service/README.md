# ML Inference Service — ZeaVis Edu

> Layanan inferensi machine learning berbasis Rust/Axum + ONNX Runtime untuk klasifikasi penyakit daun jagung.

← [Kembali ke README utama](../../README.md)

---

## Daftar Isi

1. [Fitur](#1-fitur)
2. [Prasyarat & Instalasi](#2-prasyarat--instalasi)
3. [Menjalankan Service](#3-menjalankan-service)
4. [Environment Variables](#4-environment-variables)
5. [Endpoint API](#5-endpoint-api)
6. [Verifikasi & Testing](#6-verifikasi--testing)
7. [Docker Deployment](#7-docker-deployment)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Fitur

- **Framework:** Axum (async Rust web framework)
- **Runtime Inferensi:** ONNX Runtime untuk kompatibilitas lintas platform
- **Model:** EfficientNetV2B0 dalam format ONNX
- **Endpoint:** Health check, metadata, dan prediksi gambar
- **Multipart Upload:** Dukungan upload gambar langsung via HTTP POST

---

## 2. Prasyarat & Instalasi

- Rust 1.70+ dan Cargo
- Model ONNX di `../../Machine_Learning/model/model.onnx` (atau path custom via `MODEL_PATH`)

Dependensi Rust sudah terdaftar di `Cargo.toml`. Cargo akan mengunduh dan mengkompilasi otomatis saat pertama kali build.

```bash
cargo build
```

Output build lokal berada di `target/` dan direktori tersebut diabaikan oleh Git.

---

## 3. Menjalankan Service

Semua perintah di bawah dijalankan dari direktori `apps/ml-service`.

### Opsi 1: Default (Port 4012)

```bash
cargo run
```

Service akan mencari model di path default:
```
../../Machine_Learning/model/model.onnx
```

### Opsi 2: Local Development dengan .env.example (Port 8001)

```bash
source .env.example
cargo run
```

### Opsi 3: Custom Model Path & Port

```bash
ML_SERVICE_PORT=9000 MODEL_PATH=/path/to/model.onnx cargo run
```

---

## 4. Environment Variables

| Variable | Default | Keterangan |
|---|---|---|
| `ML_SERVICE_HOST` | `0.0.0.0` | Bind address |
| `ML_SERVICE_PORT` | `8000` | Bind port |
| `MODEL_PATH` | `../../Machine_Learning/model/model.onnx` | Path ke file model ONNX |
| `MODEL_INPUT_SIZE` | `224` | Ukuran input gambar (224×224 untuk EfficientNetV2B0) |
| `RUST_LOG` | `info` | Level logging (debug, info, warn, error) |

---

## 5. Endpoint API

### Health Check

```bash
curl http://localhost:4012/health
```

```json
{
  "status": "ok",
  "model_loaded": true
}
```

### Metadata

```bash
curl http://localhost:4012/metadata
```

```json
{
  "service_name": "zeavis-ml-service",
  "service_version": "0.1.0",
  "model_path": "../../Machine_Learning/model/model.onnx",
  "model_loaded": true,
  "input_size": 224,
  "labels": ["Bercak Daun", "Daun Sehat", "Karat Daun", "Hawar Daun"]
}
```

### Prediksi

Upload gambar daun jagung untuk klasifikasi:

```bash
curl -X POST http://localhost:4012/predict \
  -F "file=@/path/to/corn-leaf.jpg"
```

```json
{
  "label": "Daun Sehat",
  "confidence": 0.95,
  "probabilities": {
    "Bercak Daun": 0.02,
    "Daun Sehat": 0.95,
    "Karat Daun": 0.01,
    "Hawar Daun": 0.02
  }
}
```

---

## 6. Verifikasi & Testing

### Build Produksi

```bash
cargo build --release
# Binary di target/release/zeavis-ml-service
```

### Menjalankan Tests

```bash
cargo test
```

### Verifikasi Manual (default port 8000)

```bash
# 1. Start service
cargo run

# 2. Health check
curl http://localhost:4012/health

# 3. Metadata
curl http://localhost:4012/metadata

# 4. Prediksi
curl -X POST http://localhost:4012/predict \
  -F "file=@../../Machine_Learning/dataset/Daun\ Sehat/sample.jpg"
```

---

## 7. Docker Deployment

Service dapat di-deploy via Docker. Build dari root repository karena Dockerfile menyalin source service dan artifact ONNX dari beberapa direktori repo.

```bash
docker build -f apps/ml-service/Dockerfile -t zeavis-ml-service .
docker run -p 8000:4012 zeavis-ml-service
```

Pastikan `Machine_Learning/model/model.onnx` sudah dibuat sebelum build image.

---

## 8. Troubleshooting

### Model tidak ditemukan

**Error:** `Failed to load model: No such file or directory`

**Solusi:**
```bash
ls -la ../../Machine_Learning/model/model.onnx
# Atau set path custom:
MODEL_PATH=/absolute/path/to/model.onnx cargo run
```

### Port sudah digunakan

**Error:** `Address already in use`

**Solusi:**
```bash
ML_SERVICE_PORT=9000 cargo run
# Cek port yang digunakan:
lsof -i :4012
```

### ONNX Runtime tidak kompatibel

**Error:** `ONNX Runtime initialization failed`

**Solusi:** Pastikan binary ONNX Runtime kompatibel dengan sistem operasi. Jika masalah persisten:
```bash
cargo clean
cargo build
```

---

← [Kembali ke README utama](../../README.md) &bull; [Pipeline ML →](../../Machine_Learning/README.md) &bull; [Infra →](../../infra/README.md)
