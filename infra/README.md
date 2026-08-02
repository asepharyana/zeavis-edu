# Infrastruktur — ZeaVis Edu

> Arsitektur multi-VPS untuk deployment produksi ZeaVis Edu dengan Tailscale mesh VPN dan observabilitas penuh.
>
> > **Catatan (2026-08-02):** Produksi kini memakai **Nix + systemd + Caddy 2.11.4** (Docker/Traefik/Coolify dihapus). Deploy: GitHub Actions → `nix build` → `nix copy ssh://` → `systemctl restart`.

← [Kembali ke README utama](../README.md)

---

## Daftar Isi

1. [Arsitektur](#1-arsitektur)
2. [Prasyarat GitHub Secrets](#2-prasyarat-github-secrets)
3. [Setup VPS](#3-setup-vps)
4. [Port yang Dibuka](#4-port-yang-dibuka)
5. [Metrics Flow](#5-metrics-flow)
6. [Perintah Penting](#6-perintah-penting)

---

## 1. Arsitektur

ZeaVis Edu berjalan di **dua VPS terpisah** yang terhubung melalui **Tailscale** mesh VPN:

```
┌─────────────────────────────────────────────┐     ┌──────────────────────────────────────────────┐
│              App VPS (imrnes)               │     │         Telemetry VPS (orange)                │
│             100.121.180.82                   │     │         100.96.248.86                        │
│             Arch Linux                      │     │         Ubuntu                               │
│                                             │     │                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │     │  ┌──────────┐  ┌──────────────┐             │
│  │  Web     │  │  API     │  │  ML      │  │     │  │Prometheus│  │Metric        │             │
│  │:4011     │  │:4006     │  │:4012     │  │     │  │:9090     │  │Ingester      │             │
│  │/metrics  │  │/metrics  │  │/metrics  │  │     │  │          │  │:9091         │             │
│  └──────────┘  └──────────┘  └──────────┘  │     │  └────┬─────┘  └──────┬───────┘             │
│  ┌──────────────────────────────────────┐  │     │       │               │                     │
│  │        Node Exporter                 │  │     │       │  remote_write │                     │
│  │        :9100                         │  │     │       ▼               ▼                     │
│  └──────────────────────────────────────┘  │     │  ┌──────────────────────────────────────┐   │
│                                             │     │  │          Vector                      │   │
│     ┌──────────────┐                        │     │  │          :9001                       │   │
│     │    Caddy     │                        │     │  └────────────────┬─────────────────────┘   │
│     │  2.11.4      │                        │     │                   │                         │
│     └──────────────┘                        │     │                   ▼                         │
│                                             │     │  ┌──────────────────────────────────────┐   │
│  ZeaVis Edu Apps via                        │     │  │           ClickHouse                  │   │
│  zeavisedu.asepharyana.my.id                │     │  │           :8123                       │   │
│                                             │     │  └───────────────┬──────────────────────┘   │
│                                             │     │                   │                         │
│                                             │     │                   ▼                         │
│  ==== Tailscale (WireGuard) ====            │     │  ┌──────────────────────────────────────┐   │
│                                             │     │  │         Query Proxy                 │   │
│                                             │     │  │         :9092                       │   │
│                                             │     │  └───────────────┬──────────────────────┘   │
│                                             │     │                   │                         │
│                                             │     │                   ▼                         │
│                                             │     │  ┌──────────────────────────────────────┐   │
│                                             │     │  │      Telemetry UI (nginx)            │   │
│                                             │     │  │      :8181                          │   │
│                                             │     │  └──────────────────────────────────────┘   │
│                                             │     │                                              │
│                                             │     │  Caddy handles:                          │
│                                             │     │  telemetry.zeavisedu.asepharyana.my.id    │
└─────────────────────────────────────────────┘     └──────────────────────────────────────────────┘
```

| VPS | Hostname | OS | Peran |
|---|---|---|---|
| **App VPS** | `imrnes` | Arch Linux | Web nginx (:4011), API (:4006), ML Service (:4012) |
| **Telemetry VPS** | `orange` | Ubuntu | Prometheus, ClickHouse, Telemetry UI |

---

## 2. Prasyarat GitHub Secrets

### App VPS — `.github/workflows/deploy.yml`

| Secret | Keterangan |
|---|---|
| `VPS_HOST` | `100.121.180.82` (imrnes) |
| `VPS_USER` | `mytheclipse` |
| `VPS_SSH_KEY` | Private SSH key untuk imrnes |
| `VPS_PORT` | `22` |
| `DATABASE_URL` | PostgreSQL connection string |
| `SESSION_SECRET` | Random session secret |

### Telemetry VPS — `.github/workflows/telemetry-ci-cd.yml`

| Secret | Keterangan |
|---|---|
| `TELEMETRY_VPS_HOST` | `100.96.248.86` (orange) |
| `TELEMETRY_VPS_USER` | SSH username |
| `TELEMETRY_VPS_SSH_KEY` | Private SSH key |
| `TELEMETRY_VPS_PORT` | `22` |
| `GHCR_PAT` | GitHub PAT dengan `write:packages` + `read:packages` |

---

## 3. Setup VPS

### App VPS (imrnes — 100.121.180.82)

```bash
# Semua service dikelola Nix + systemd — deploy otomatis via GitHub Actions:
#   nix build .#<service> → nix copy ssh://imrnes → systemctl restart zeavis-<service>
# Reverse proxy: Caddy 2.11.4 (systemd caddy.service, /etc/caddy/Caddyfile, auto-TLS LE)
```

### Telemetry VPS (orange — 100.96.248.86)

Deploy via GitHub Actions atau manual:

```bash
ssh mytheclipse@100.96.248.86
# Telemetry stack juga Nix + systemd (Docker dihapus dari produksi 2026-08-02)
# Deploy otomatis via GitHub Actions → nix build → nix copy ssh:// → systemctl restart
```

---

## 4. Port yang Dibuka

### App VPS (imrnes)

| Port | Service | Akses |
|---|---|---|
| 80/443 | Web entry (Caddy, auto-TLS LE) | Public |
| 4011 | Web nginx (`zeavisedu.asepharyana.my.id`) | Public (via Caddy) |
| 4006 | API metrics (zeavis-api) | via Caddy / Tailscale-only |
| 4012 | ML service metrics (zeavis-ml) | Tailscale-only |
| 9100 | Node Exporter | Tailscale-only |

### Telemetry VPS (orange)

| Port | Service | Akses |
|---|---|---|
| 80/443 | Telemetry UI (via Caddy) | Public |
| 8181 | Telemetry UI (direct) | Tailscale-only |
| 9090 | Prometheus | Tailscale-only |
| 9091 | Metric Ingester | Tailscale-only |
| 9001 | Vector HTTP source | Tailscale-only |
| 8123 | ClickHouse HTTP | Tailscale-only |
| 9000 | ClickHouse Native | Tailscale-only |

---

## 5. Metrics Flow

1. **App services** mengekspos `GET /metrics` di port masing-masing
2. **Prometheus** di orange VPS scrape via Tailscale IP (`100.121.180.82:PORT`)
3. Prometheus forward ke **Metric Ingester** via `remote_write`
4. Metric Ingester enrich → filter → forward ke **Vector**
5. Vector buffer → write ke **ClickHouse**
6. **Telemetry UI** query via **Query Proxy** → **ClickHouse**

```
App Services (/metrics)
    │
    ▼ (scrape via Tailscale)
Prometheus ──(remote_write)──► Metric Ingester ──► Vector ──► ClickHouse
                                                                │
                                                    Query Proxy ◄── Telemetry UI
```

---

## 6. Perintah Penting

```bash
# Status telemetry stack
make telemetry-status

# Lihat log service tertentu
make telemetry-logs s=prometheus

# Kirim test metric
make telemetry-test-metric

# Restart service
make telemetry-restart s=vector
```

---

← [Kembali ke README utama](../README.md) &bull; [ML Service →](../apps/ml-service/README.md) &bull; [Pipeline ML →](../Machine_Learning/README.md)
