# Root README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a complete Indonesian root `README.md` that explains ZeaVis Edu, how to run it locally, how services are structured, and where to find ML-specific details.

**Architecture:** Add one root documentation file that serves as the main entry point for the monorepo. Keep deep ML workflow details in `Machine_Learning/README.md` and deep ML service details in `apps/ml-service/README.md`, while summarizing both from the root.

**Tech Stack:** Markdown, Bun workspaces, Moon, React/Vite, Elysia, FastAPI, TensorFlow/Keras, PostgreSQL/Drizzle, Docker Compose.

---

## File Structure

- Create: `README.md`
  - Responsibility: Main repository documentation in Bahasa Indonesia.
  - Contents: overview, features, architecture, tech stack, prerequisites, installation, local run commands, Docker deployment notes, ML workflow summary, endpoints, generated artifacts, troubleshooting, and development workflow.

## Task 1: Create Root README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Confirm no root README currently exists**

Run:
```bash
test ! -f README.md
```
Expected: command exits successfully with no output.

- [ ] **Step 2: Create `README.md` with the approved full Indonesian documentation**

Write this exact content to `README.md`:

```markdown
# ZeaVis Edu

ZeaVis Edu adalah aplikasi edukasi untuk membantu mengenali penyakit daun jagung melalui klasifikasi gambar berbasis machine learning. Repositori ini menggabungkan aplikasi web, API backend, layanan inferensi ML, serta pipeline pelatihan dan ekspor model EfficientNetV2B0.

## Fitur Utama

- Aplikasi web untuk pengalaman pengguna dan interaksi edukatif.
- API backend untuk status layanan, integrasi data, dan komunikasi dengan layanan ML.
- ML service berbasis FastAPI untuk inferensi penyakit daun jagung dari gambar.
- Pipeline machine learning untuk preprocessing dataset, training di Google Colab, dan ekspor model produksi.
- Dukungan Docker untuk deployment web, API, dan ML service.
- Workspace monorepo berbasis Bun dan Moon untuk menjalankan task lint/typecheck/build secara terpusat.

## Kelas Penyakit

Model klasifikasi menargetkan empat label berbahasa Indonesia:

| Label | Deskripsi |
|---|---|
| Bercak Daun | Gray Leaf Spot |
| Hawar Daun | Northern/Southern Leaf Blight |
| Karat Daun | Common Rust |
| Daun Sehat | Daun jagung tanpa gejala penyakit |

## Struktur Proyek

```text
.
├── apps/
│   ├── api/              # Backend Elysia/Bun
│   ├── ml-service/       # Layanan inferensi FastAPI + TensorFlow
│   └── web/              # Frontend React + Vite
├── Machine_Learning/     # Pipeline dataset, training, dan ekspor model
├── packages/
│   └── shared/           # Tipe dan utilitas bersama TypeScript
├── docker-compose.yml    # Konfigurasi deployment container
├── package.json          # Script dan workspace root Bun
└── README.md             # Dokumentasi utama proyek
```

## Tech Stack

### Frontend

- React
- Vite
- TypeScript
- React Router
- TanStack Query
- Zustand
- Tailwind CSS

### Backend API

- Bun
- Elysia
- Drizzle ORM
- PostgreSQL

### Machine Learning

- Python
- TensorFlow/Keras
- EfficientNetV2B0
- FastAPI
- Uvicorn
- TFLite
- TensorFlow.js

### Tooling & Deployment

- Bun workspaces
- Moon task runner
- Docker
- Docker Compose
- GitHub Container Registry
- Traefik labels untuk routing deployment

## Prasyarat

Untuk menjalankan seluruh project secara lokal, siapkan:

- Bun
- Python 3.9–3.11 untuk pipeline ML
- Python 3.10+ untuk `apps/ml-service`
- Docker dan Docker Compose jika ingin menjalankan/deploy via container
- PostgreSQL jika fitur backend yang membutuhkan database digunakan
- File model `Machine_Learning/best_model/best_model.keras` untuk inferensi ML lokal

## Instalasi Root Workspace

Jalankan dari root repository:

```bash
bun install
```

## Menjalankan Project Lokal

### Menjalankan Semua Task Development

```bash
bun run dev
```

Script ini menjalankan task `dev` melalui Moon untuk workspace yang tersedia.

### Type Check

```bash
bun run typecheck
```

### Build Produksi

```bash
bun run build
```

## Menjalankan Service Secara Terpisah

### Web App

```bash
cd apps/web
bun run dev
```

Secara default Vite akan menjalankan server development dan menampilkan URL lokal di terminal.

### API Backend

```bash
cd apps/api
bun run start
```

API membaca konfigurasi dari file `.env` di root repository melalui script Bun.

Script lain yang tersedia:

```bash
bun run db:generate
bun run db:migrate
bun run db:seed
bun run typecheck
```

### ML Service

```bash
cd apps/ml-service
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8001
```

Default path model adalah:

```text
../../Machine_Learning/best_model/best_model.keras
```

Jika model berada di lokasi lain, gunakan environment variable `MODEL_PATH`.

## Endpoint Penting

### ML Service

| Method | Endpoint | Fungsi |
|---|---|---|
| GET | `/health` | Mengecek status service dan status model |
| GET | `/metadata` | Melihat metadata service, label, input size, dan path model |
| POST | `/predict` | Mengunggah gambar daun jagung untuk klasifikasi |

Contoh verifikasi:

```bash
curl http://localhost:8001/health
curl http://localhost:8001/metadata
curl -X POST http://localhost:8001/predict -F "file=@/path/to/corn-leaf.jpg"
```

## Docker Deployment

> Catatan (2026-08-02): port produksi sekarang API 4006, nginx 4011, ML 4012; deploy Nix+systemd+Caddy.

File `docker-compose.yml` di root menyiapkan tiga service produksi:

- `web` untuk frontend
- `api` untuk backend
- `ml` untuk layanan inferensi machine learning

Konfigurasi compose menggunakan image dari GitHub Container Registry:

```text
ghcr.io/${GITHUB_REPOSITORY:-mytheclipse/zeavis-edu}/web:main
ghcr.io/${GITHUB_REPOSITORY:-mytheclipse/zeavis-edu}/api:main
ghcr.io/${GITHUB_REPOSITORY:-mytheclipse/zeavis-edu}/ml:main
```

Compose juga mengasumsikan network eksternal bernama `app-shared-net` dan routing Traefik untuk domain produksi.

Contoh menjalankan compose setelah environment dan network siap:

```bash
docker compose up -d
```

## Workflow Machine Learning

Detail lengkap tersedia di [`Machine_Learning/README.md`](Machine_Learning/README.md). Ringkasnya:

1. Unduh `dataset_1.zip`, `dataset_2.zip`, dan `dataset_3.zip` lalu letakkan di `Machine_Learning/`.
2. Jalankan preprocessing lokal:

   ```bash
   cd Machine_Learning
   python preprocessing.py
   ```

3. Upload `dataset.zip` ke Google Drive.
4. Jalankan `notebook.ipynb` di Google Colab dengan GPU.
5. Download model terbaik sebagai `best_model/best_model.keras`.
6. Ekspor model produksi:

   ```bash
   python save_model.py
   ```

7. Konversi TensorFlow.js via CLI:

   ```bash
   export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
   tensorflowjs_converter \
     --input_format=tf_saved_model \
     --output_format=tfjs_graph_model \
     --signature_name=serving_default \
     --saved_model_tags=serve \
     model/saved_model \
     model/tfjs_model
   ```

Output utama pipeline ML:

| Path | Kegunaan |
|---|---|
| `Machine_Learning/dataset.zip` | Dataset siap upload ke Colab |
| `Machine_Learning/best_model/best_model.keras` | Model Keras hasil training |
| `Machine_Learning/model/saved_model/` | TensorFlow SavedModel |
| `Machine_Learning/model/model.tflite` | Model untuk mobile/TFLite |
| `Machine_Learning/model/tfjs_model/` | Model untuk TensorFlow.js |

## Artifact Lokal dan Generated Files

Beberapa file tidak tersedia di fresh clone karena berukuran besar, dihasilkan lokal, atau berasal dari sumber eksternal:

- `Machine_Learning/dataset_1.zip`
- `Machine_Learning/dataset_2.zip`
- `Machine_Learning/dataset_3.zip`
- `Machine_Learning/dataset/`
- `Machine_Learning/dataset.zip`
- `Machine_Learning/best_model/best_model.keras`
- `Machine_Learning/model/saved_model/`
- `Machine_Learning/model/model.tflite`
- `Machine_Learning/model/tfjs_model/`

## Environment Variable Penting

| Variable | Digunakan oleh | Keterangan |
|---|---|---|
| `DATABASE_URL` | API | URL koneksi PostgreSQL untuk Drizzle |
| `API_PORT` | API | Port backend produksi |
| `WEB_APP_URL` | API | URL frontend untuk konfigurasi CORS/integrasi |
| `ML_SERVICE_URL` | API | URL layanan ML |
| `MODEL_PATH` | ML Service | Lokasi file model Keras |
| `MODEL_INPUT_SIZE` | ML Service | Ukuran input model, default produksi `224` |

## Troubleshooting

### `bun run dev` gagal karena dependency belum tersedia

Jalankan ulang instalasi dari root repository:

```bash
bun install
```

### API membutuhkan database

Pastikan `DATABASE_URL` tersedia di `.env` root dan PostgreSQL dapat diakses oleh aplikasi.

### ML service gagal memuat model

Pastikan file model tersedia di path default:

```text
Machine_Learning/best_model/best_model.keras
```

Atau set path khusus:

```bash
MODEL_PATH=/path/to/best_model.keras uvicorn main:app --host 0.0.0.0 --port 8001
```

### Docker Compose gagal karena network tidak ditemukan

`docker-compose.yml` menggunakan network eksternal `app-shared-net`. Buat network tersebut jika belum ada:

```bash
docker network create app-shared-net
```

### Konversi TensorFlow.js gagal karena konflik protobuf

Jalankan konversi melalui CLI dan set environment variable berikut:

```bash
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
```

## Pengembangan

Alur umum pengembangan:

1. Install dependency dengan `bun install`.
2. Jalankan service yang dibutuhkan secara lokal.
3. Jalankan `bun run typecheck` sebelum membuat commit.
4. Jalankan `bun run build` untuk memverifikasi build produksi.
5. Untuk perubahan ML, ikuti dokumentasi detail di `Machine_Learning/README.md`.
6. Untuk perubahan ML service, cek juga `apps/ml-service/README.md`.

## Dokumentasi Terkait

- [`Machine_Learning/README.md`](Machine_Learning/README.md) — panduan lengkap dataset, training, dan ekspor model.
- [`apps/ml-service/README.md`](apps/ml-service/README.md) — panduan menjalankan dan memverifikasi layanan inferensi ML.
```

- [ ] **Step 3: Verify markdown file exists and contains the expected title**

Run:
```bash
grep -n "^# ZeaVis Edu" README.md
```
Expected output includes:
```text
1:# ZeaVis Edu
```

- [ ] **Step 4: Verify root commands still match `package.json`**

Run:
```bash
grep -n '"dev"\|"build"\|"typecheck"' package.json
```
Expected output includes root scripts for `dev`, `build`, and `typecheck`.

- [ ] **Step 5: Review generated README for broken internal references**

Run:
```bash
test -f Machine_Learning/README.md && test -f apps/ml-service/README.md && test -f docker-compose.yml
```
Expected: command exits successfully with no output.

- [ ] **Step 6: Check git diff**

Run:
```bash
git diff -- README.md
```
Expected: diff shows only the new root README content.

- [ ] **Step 7: Commit**

Run:
```bash
git add README.md
git commit -m "docs: add root project README"
```
Expected: commit succeeds.
