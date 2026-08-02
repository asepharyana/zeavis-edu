<p align="center">
  <br>
  <img src=".github/assets/zeavis-logo.svg" alt="ZeaVis Edu" width="128"><br>
  <h1 align="center">ZeaVis Edu</h1>
  <p align="center">
    <strong>Asisten Edukasi Interaktif untuk Deteksi Penyakit Daun Jagung</strong><br>
    <em>Computer Vision &bull; EfficientNetV2B0 &bull; Rust ONNX Runtime &bull; Tauri 2 Android</em>
  </p>
</p>

<p align="center">
  <a href="#-tentang"><b>Tentang</b></a> &bull;
  <a href="#-tim"><b>Tim</b></a> &bull;
  <a href="#-ringkasan-eksekutif"><b>Ringkasan</b></a> &bull;
  <a href="#-cakupan--deliverables"><b>Cakupan</b></a> &bull;
  <a href="#-jadwal"><b>Jadwal</b></a> &bull;
  <a href="#-tech-stack"><b>Tech Stack</b></a> &bull;
  <a href="#-memulai"><b>Memulai</b></a> &bull;
  <a href="#-platform"><b>Platform</b></a> &bull;
  <a href="#-dokumentasi"><b>Dokumentasi</b></a>
</p>

<br>

---

## 🌽 Tentang

**ZeaVis Edu** adalah aplikasi edukasi berbasis **Computer Vision** yang membantu petani, mahasiswa pertanian, dan penyuluh lapangan mengidentifikasi penyakit daun jagung secara mandiri — cukup dengan mengunggah foto daun jagung.

Proyek ini merupakan **Capstone Project** dalam program **Pijak × IBM SkillsBuild** dengan tema **"AI for Smart Education"**, dirancang untuk menjembatani kesenjangan antara pengetahuan teori pertanian dan kebutuhan praktis di lapangan.

---

## 👥 Tim

| NPM | Nama | Learning Path | Peran |
|---|---|---|---|
| APC246D6Y0028 | **Asep Haryana Saputra** | Back-End | Arsitektur sistem, RESTful API, deployment Docker/Cloud, keamanan upload stream |
| APC013D6X0081 | **Selly Supriyatin** | Front-End | UI/UX responsif, mekanisme unggah gambar, modul edukasi (rekomendasi obat & penanganan) |
| APC013D6Y0091 | **Taufik Pathurrohman** | Machine Learning | Data Engineering — ekstraksi dataset, cleaning, augmentasi gambar |
| APC414D6Y0138 | **Luhung Pandyaska Suyi** | Machine Learning | Model Architecture & Training — CNN, hyperparameter tuning |
| APC013D6Y0269 | **Ardian** | Machine Learning | Model Evaluation & Deployment Prep — confusion matrix, konversi ke production-ready |

---

## 📋 Ringkasan Eksekutif

### Masalah

Data BPS menunjukkan penurunan luas panen jagung dari **2.764.366 Ha (2022)** menjadi **2.487.191 Ha (2023)**. Salah satu penyebab utamanya adalah penyakit daun seperti **Hawar Daun**, **Karat Daun**, dan **Bercak Daun Abu-abu** yang menyebabkan nekrosis dan menghambat fotosintesis.

Petani sering kesulitan mengidentifikasi penyakit secara kasat mata dan memiliki **ketergantungan tinggi pada POPT** (Petugas Pengendali Organisme Pengganggu Tumbuhan) akibat minimnya media pembelajaran interaktif.

### Solusi

ZeaVis Edu menggunakan **Computer Vision** sebagai asisten edukasi interaktif:

1. 📸 **Unggah** foto daun jagung yang diduga terinfeksi
2. 🤖 **Deteksi otomatis** penyakit oleh model AI (EfficientNetV2B0)
3. 📚 **Dapatkan** informasi detail penyakit, panduan pencegahan, dan rekomendasi obat secara mandiri

### Metode Teknis

| Komponen | Pilihan |
|---|---|
| Arsitektur Model | **EfficientNetV2B0** — keseimbangan optimal antara akurasi dan efisiensi parameter |
| Metode Pelatihan | **Transfer Learning** pada Google Colab (GPU T4) |
| Sumber Dataset 1 | Kaggle — [Corn Leaf Disease](https://www.kaggle.com/datasets/ndisan/corn-leaf-disease) |
| Sumber Dataset 2 | Kaggle — [Corn or Maize Leaf Disease Dataset](https://www.kaggle.com/datasets/smaranjitghose/corn-or-maize-leaf-disease-dataset) |
| Sumber Dataset 3 | scidb — [Dataset of Corn Leaf Diseases based on Manual Annotation and Contrast Generation Model](https://www.scidb.cn/en/detail?dataSetId=19536c73f6d74946a212719a94f53ab3) |

| Deployment | VPS dengan Docker, ONNX Runtime untuk inferensi real-time |

---

## 🎯 Cakupan & Deliverables

### Cakupan

| ✅ Dalam Cakupan | ❌ Di Luar Cakupan |
|---|---|
| Klasifikasi 3 penyakit + 1 daun sehat | Penyakit pada batang atau buah jagung |
| Deteksi berbasis unggah gambar daun | Prediksi tanpa input gambar |
| Rekomendasi obat & penanganan | Diagnosis pengganti ahli/POPT |
| Aplikasi Web + Android (Tauri 2) | Aplikasi iOS |

### 4 Kelas yang Diklasifikasikan

| Label | Nama Ilmiah | Gejala |
|---|---|---|
| **Hawar Daun** | *Northern/Southern Leaf Blight* | Hawar coklat memanjang pada daun |
| **Karat Daun** | *Common Rust* | Bintik coklat kemerahan berbentuk pustula |
| **Bercak Daun** | *Gray Leaf Spot* | Bercak abu-abu memanjang |
| **Daun Sehat** | — | Tanpa gejala penyakit |

### Deliverables Proyek

| No | Tahapan | Deskripsi |
|---|---|---|
| 1 | **Pengumpulan Data** | Dataset gambar 3 penyakit + 1 daun sehat dari Kaggle beserta pelabelan |
| 2 | **Model ML** | Model Computer Vision terlatih di Google Colab, siap produksi |
| 3 | **UI Antarmuka** | Front-End berbasis React + Vite dengan fitur unggah gambar |
| 4 | **Back-End Integration** | API + ML Service untuk inferensi real-time via Docker |
| 5 | **Prototipe Akhir** | Aplikasi Web + Android (Tauri 2) dengan klasifikasi & modul edukasi (rekomendasi obat & penanganan) |

---

## 📅 Jadwal

| Minggu | Tanggal | Fase | Aktivitas |
|---|---|---|---|
| **1** | 11–17 Mei 2026 | Inisiasi & Data | Spesifikasi teknis (Asep) • Dataset dari Kaggle + preprocessing (Taufik) • Wireframe UI/UX (Selly) |
| **2** | 18–24 Mei 2026 | Training & Dev Awal | Implementasi EfficientNetV2B0 di Colab (Luhung) • Slicing UI ke React (Selly) • Setup server, database, routing API (Asep) |
| **3** | 25–31 Mei 2026 | Evaluasi & Modul Edukasi | Evaluasi akurasi + konversi model ke ONNX/TFLite (Ardian) • Halaman edukasi obat & penanganan (Selly) • RESTful API untuk image upload & inferensi (Asep) |
| **4** | 1–7 Juni 2026 | Integrasi & Testing | Integrasi penuh Front-End ↔ API ↔ Model ML • Pengujian end-to-end • Stress testing & error handling (Semua) |
| **5** | 8–14 Juni 2026 | Deployment & Finalisasi | Deployment ke VPS (Asep) • Bug fixing & optimalisasi UI/UX (Selly) • Dokumentasi teknis & materi presentasi (Semua) |

---

## ⚠️ Manajemen Risiko

| Risiko | Solusi |
|---|---|
| **Overfitting akibat imbalanced data** | Augmentasi tingkat lanjut (kecerahan, noise, rotasi) + confidence threshold < 75% → minta user foto ulang |
| **Server downtime / latensi tinggi** | Batasan upload ≤ 5 MB + kompresi server-side + rate limiting + container Docker isolasi resource |
| **Foto blur / objek bukan daun jagung** | Panduan visual (overlay) pada UI + validasi anomali + disclaimer "alat bantu edukasi, bukan pengganti POPT" |
| **Bottleneck integrasi ML ↔ API ↔ UI** | API Contract ketat di minggu ke-1 + integrasi bertahap (CI) mulai minggu ke-3 |

---

## 🏗️ Arsitektur Proyek

```
.
├── apps/
│   ├── api/                  # Backend Elysia/Bun + Drizzle ORM + PostgreSQL
│   ├── ml-service/           # Rust/Axum + ONNX Runtime inference engine
│   ├── tauri/                # Tauri 2 mobile wrapper → Android APK
│   └── web/                  # Frontend React + Vite + Tailwind CSS
├── Machine_Learning/         # Pipeline dataset, training Colab, ekspor model
│   └── README.md             # ⤷ Panduan lengkap pipeline ML
├── infra/
│   └── README.md             # ⤷ Panduan deployment multi-VPS
├── packages/shared/          # Tipe & utilitas TypeScript bersama
├── telemetry/                # Submodule — Prometheus → ClickHouse pipeline
├── docker-compose.yml        # Konfigurasi deployment container
├── package.json              # Root workspace Bun + Moon
└── README.md                 # ⤷ Anda di sini
```

| Komponen | Teknologi | Dokumentasi |
|---|---|---|
| Web Frontend | React, Vite, Tailwind, Zustand, TanStack Query | `apps/web/` |
| Android App | Tauri 2, Rust, WebView, Deep Link OAuth | `apps/tauri/` |
| API Backend | Bun, Elysia, Drizzle ORM, PostgreSQL | `apps/api/` |
| ML Inference Engine | Rust, Axum, ONNX Runtime | [`apps/ml-service/README.md`](apps/ml-service/README.md) |
| ML Pipeline | Python, TensorFlow/Keras, EfficientNetV2B0 | [`Machine_Learning/README.md`](Machine_Learning/README.md) |
| Infrastruktur | Docker, Coolify, Traefik, Tailscale | [`infra/README.md`](infra/README.md) |
| Telemetry | Prometheus, ClickHouse, Vector, Vue 3 | `telemetry/` |

---

## 🛠️ Tech Stack

### Frontend & Mobile
React &bull; Vite &bull; TypeScript &bull; React Router &bull; TanStack Query &bull; Zustand &bull; Tailwind CSS
**Tauri 2** (Android) &bull; Rust &bull; WebView &bull; Deep Link OAuth

### Backend API
Bun &bull; Elysia &bull; Drizzle ORM &bull; PostgreSQL &bull; prom-client

### Machine Learning
Python &bull; TensorFlow/Keras &bull; EfficientNetV2B0 &bull; Google Colab (GPU T4)

### Inference Engine
**Rust** &bull; **Axum** &bull; **ONNX Runtime** &bull; TFLite &bull; TensorFlow.js

### DevOps & Infrastruktur
Docker &bull; Docker Compose &bull; Coolify &bull; Traefik &bull; Tailscale &bull; GitHub Actions (CI/CD)

### Observabilitas
Prometheus &bull; Metric Ingester (Go) &bull; Vector &bull; ClickHouse &bull; Query Proxy (Go) &bull; Telemetry UI (Vue 3)

---

## 🚀 Memulai

### Prasyarat

- **Bun** — runtime & package manager
- **Python 3.9–3.11** — pipeline ML
- **Rust & Cargo** — `apps/ml-service` (inference) & `apps/tauri` (Android)
- **Java 21 + Android SDK** — build Android APK
- **Docker & Docker Compose** — deployment & telemetry
- **PostgreSQL** — backend API

### Instalasi

```bash
git clone https://github.com/ATLAS-PJK-GM007/ZeaVis-Edu.git
cd ZeaVis-Edu
bun install
```

### Menjalankan Development

```bash
bun run dev                # Semua service (web + api)
cd apps/web && bun run dev # Hanya frontend
cd apps/api && bun run start # Hanya backend API
cd apps/ml-service && cargo run  # ML inference engine (port 4012)
cd apps/tauri && bun run tauri dev        # Tauri desktop dev
cd apps/tauri && bun run tauri android dev  # Tauri Android dev
```

### Environment Variables

Salin `.env.example` ke `.env` dan isi:

| Variable | Keterangan |
|---|---|
| `DATABASE_URL` | URL koneksi PostgreSQL |
| `SESSION_SECRET` | Secret untuk session auth |
| `WEB_APP_URL` | URL frontend (untuk CORS) |
| `ML_SERVICE_URL` | URL layanan inferensi ML |

### Pipeline ML (Ringkasan)

1. Unduh 3 dataset ZIP → letakkan di `Machine_Learning/`
2. `python preprocessing.py` — gabungkan & bersihkan dataset
3. Upload `dataset.zip` ke Google Drive
4. Jalankan `notebook.ipynb` di Google Colab (GPU T4)
5. Download `best_model.keras`
6. `python save_model.py` → TFLite + SavedModel
7. Konversi ke TFJS & ONNX

> 📖 **Panduan lengkap:** [`Machine_Learning/README.md`](Machine_Learning/README.md)

### Deployment

```bash
docker compose up -d       # App services
make telemetry-up          # Telemetry stack
```

> 📖 **Panduan infrastruktur:** [`infra/README.md`](infra/README.md)

---

## 📱 Platform

ZeaVis Edu tersedia di **dua platform** dari satu codebase:

| Platform | Teknologi | Build |
|---|---|---|
| **Web** | React + Vite → Static SPA | `bun run build` |
| **Android** | Tauri 2 + Rust → WebView APK | `cd apps/tauri && bun run tauri android build --apk` |

### Tauri 2 Android

Aplikasi Android membungkus frontend web yang sama dalam **WebView native** menggunakan **Tauri 2**, memberikan akses ke API native Android tanpa menulis ulang UI.

**Fitur Android:**
- **Google OAuth** — Login via system browser + deep link `zeavisedu://` kembali ke app
- **Kamera** — Izin `CAMERA` untuk unggah foto daun jagung langsung dari kamera
- **Tauri Plugin Opener** — Buka URL eksternal di system browser
- **Tauri Plugin Deep Link** — Tangkap OAuth callback tanpa memerlukan server redirect

**CI/CD Android:**
- GitHub Actions workflow `.github/workflows/android.yml`
- Build otomatis di setiap push/PR ke `main`
- Patch `AndroidManifest.xml` untuk menambahkan izin kamera + intent filter deep link
- APK ditandatangani (signed) via `apksigner` + release ke GitHub Releases

```bash
# Development Android (butuh Android SDK + emulator/device)
cd apps/tauri
bun run tauri android init        # Init project Android
bun run tauri android dev         # Dev dengan hot reload
bun run tauri android build --apk # Build APK production

# CI/CD — dijalankan otomatis via GitHub Actions
.github/workflows/android.yml
```

> Konfigurasi: `apps/tauri/tauri.conf.json` &bull; `apps/tauri/gen/android/`

---

## 📚 Dokumentasi

| Dokumen | Isi |
|---|---|
| [`Machine_Learning/README.md`](Machine_Learning/README.md) | Pipeline ML lengkap — preprocessing, training Colab, ekspor TFLite/TFJS/ONNX |
| [`apps/ml-service/README.md`](apps/ml-service/README.md) | ML Inference Service — setup, endpoint API, konfigurasi |
| [`infra/README.md`](infra/README.md) | Arsitektur multi-VPS — diagram, GitHub Secrets, port, metrics flow |
| [`METRICS.md`](METRICS.md) | Daftar lengkap metrik Prometheus |
| `telemetry/` (submodule) | Source code telemetry stack |

---

## 🔧 Troubleshooting

| Masalah | Solusi |
|---|---|
| `bun install` gagal | `bun --version` — pastikan ≥ 1.x |
| API perlu database | Isi `DATABASE_URL` di root `.env` |
| ML service gagal muat model | `ls Machine_Learning/model/model.onnx` — jalankan pipeline ML jika belum ada |
| Docker Compose gagal | `docker network create app-shared-net` |
| Konversi TFJS gagal | `export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` |

---

## 📖 Daftar Pustaka

1. Prayogi, A. et al. *"Klasifikasi Penyakit Daun Jagung Menggunakan CNN"* — [SISTEMATIS](https://ejournal.rizaniamedia.com/index.php/sistematis/article/view/87/49)
2. Nugroho, A. et al. *"Deteksi Penyakit Daun Jagung dengan Deep Learning"* — [MIND Journal](https://ejurnal.itenas.ac.id/index.php/mindjournal/article/view/14032/4209)
3. Ramadhan, F. et al. *"Identifikasi Penyakit Jagung Berbasis Citra Digital"* — [Informa](https://www.informa.poltekindonusa.ac.id/index.php/informa/article/view/199/170)
4. Corteva Agriscience. *"Kenali Ragam Jenis Penyakit Jagung dan Cara Mengatasinya"* — [corteva.com](https://www.corteva.com/id/berita/Kenali-Ragam-Jenis-Penyakit-Jagung-dan-Cara-Mengatasinya.html)

---

<p align="center">
  <sub>
    Capstone Project • Pijak × IBM SkillsBuild • AI for Smart Education<br>
    © 2026 ZeaVis Edu Team
  </sub>
</p>
