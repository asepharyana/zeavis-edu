# ZeaVis Edu — Metrics Endpoints

This document lists every Prometheus metrics endpoint exposed by the ZeaVis Edu
application stack and the payload each service provides.

---

## Overview

| Service               | Host (prod)                       | Metrics Endpoint           | Port (local) |
|-----------------------|-----------------------------------|----------------------------|--------------|
| Web (Vite dev)        | `zeavisedu.asepharyana.my.id`     | `GET /metrics`             | 5173         |
| API (Elysia)          | `api-zeavisedu.asepharyana.my.id`   | `GET /metrics`           | 4006         |
| ML Service (Axum)     | `ml-zeavisedu.asepharyana.my.id`    | `GET /metrics`           | 4012         |
| Prometheus Collector  | —                                 | `GET /metrics` (self)      | 9090         |

> In production all metrics are scraped by the Prometheus collector running in the
> Telemetry stack on a **separate VPS** connected via **Tailscale**.
> See [`telemetry/prometheus/targets/`](./telemetry/prometheus/targets/)
> for the auto‑discovery configuration. Target files must use **Tailscale IPs**
> (e.g. `100.121.180.82:4006`), not Docker hostnames, because the services are on
> different hosts.
>
> In production (nginx), the web app proxies `/metrics` to the API service:
> see [`apps/web/nginx.conf`](apps/web/nginx.conf).
>
> For local development the Vite plugin `vite-plugin-metrics.ts` serves
> client‑side session metrics at `GET /metrics` on the Vite dev server.

---

## 1. Web App — `GET /metrics`

| Endpoint          | Description                                      |
|-------------------|--------------------------------------------------|
| `/metrics`        | Vite dev‑server middleware + client‑side snapshot |

### Metrics

| Metric Name                         | Type    | Labels                        | Description                              |
|-------------------------------------|---------|-------------------------------|------------------------------------------|
| `zeavis_web_page_views_total`       | counter | —                             | Total page views this session            |
| `zeavis_web_vital_bucket`           | gauge   | `name`, `rating`              | Last‑seen Web Vitals (CLS, FCP, INP…)   |

**Development:** served inline by the Vite plugin `vite-plugin-metrics.ts`.
**Production:** the static frontend serves no `/metrics` endpoint — consider
forwarding the Vite dev server, or use the Telemetry collector to scrape
client‑side beacons.

---

## 2. API (Elysia/Bun) — `GET /metrics`

| Endpoint          | Description                                      |
|-------------------|--------------------------------------------------|
| `/metrics`        | Prometheus text format via `prom-client`         |

### Metrics

| Metric Name                                | Type      | Labels                         | Description                              |
|--------------------------------------------|-----------|--------------------------------|------------------------------------------|
| `zeavis_api_http_requests_total`           | counter   | `method`, `path`, `status`     | Total HTTP requests                      |
| `zeavis_api_http_request_duration_seconds` | histogram | `method`, `path`               | Request latency buckets                  |
| `zeavis_api_http_requests_active`          | gauge     | —                              | Concurrently‑handled requests            |
| `zeavis_api_classifications_total`         | counter   | `result`                       | AI image classifications                 |
| `zeavis_api_diagnoses_total`               | counter   | `disease`                      | Created diagnoses                        |
| `zeavis_api_auth_operations_total`         | counter   | `operation`, `success`         | Login / register attempts                |
| Default Node.js metrics                    | various   | —                              | CPU, memory, event‑loop lag, GC …       |

**Source:** `apps/api/src/lib/telemetry.ts`, instrumented in `routes/`.

---

## 3. ML Service (Rust/Axum) — `GET /metrics`

| Endpoint          | Description                                      |
|-------------------|--------------------------------------------------|
| `/metrics`        | Prometheus text format via `prometheus` crate    |

### Metrics

| Metric Name                                | Type      | Labels                         | Description                              |
|--------------------------------------------|-----------|--------------------------------|------------------------------------------|
| `zeavis_ml_http_requests_total`            | counter   | —                              | Total HTTP requests                      |
| `zeavis_ml_http_request_duration_seconds`  | histogram | —                              | Request latency buckets                  |
| `zeavis_ml_http_requests_active`           | gauge     | —                              | Concurrently‑handled requests            |
| `zeavis_ml_predictions_total`              | counter   | —                              | Successful ONNX predictions              |
| `zeavis_ml_model_load_status`              | gauge     | —                              | 1 = loaded, 0 = not loaded               |
| Process metrics (libc/procfs)              | various   | —                              | RSS, CPU, fd count …                    |

**Source:** `apps/ml-service/src/telemetry.rs`, instrumented in `routes.rs`.

---

## Prometheus Auto‑Discovery (Telemetry Stack)

The Telemetry submodule includes a Prometheus instance that uses
`file_sd_configs` to discover targets. Place a target file under
`telemetry/prometheus/targets/` with content such as:

```json
[
  {
    "targets": ["100.121.180.82:4006"],
    "labels": { "service": "zeavis-api", "component": "backend", "env": "production" }
  },
  {
    "targets": ["100.121.180.82:4012"],
    "labels": { "service": "zeavis-ml", "component": "inference", "env": "production" }
  }
]
```

> ⚠️ **Cross-VPS:** Gunakan **IP Tailscale** (bukan Docker hostname) karena
> Prometheus dan ZeaVis Edu berjalan di VPS berbeda. Pastikan port service
> (`:4006`, `:4012`) terekspos di `0.0.0.0` atau diizinkan oleh aturan
> `iptables`/`ufw` untuk interface Tailscale (`tailscale0`/`100.121.180.82`).

The Prometheus config (in `telemetry/prometheus/prometheus.yml`) will
automatically pick up new files within its 15‑second scrape interval —
no restart required.
