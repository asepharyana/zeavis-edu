# =============================================================================
# ZeaVis Edu — Root Makefile
#
# Orchestrates the application stack (web, api, ml) and the telemetry
# metric pipeline (Prometheus → Grafana).
#
# Telemetry commands operate on the submodule at telemetry/.
# =============================================================================

.PHONY: dev build typecheck
.PHONY: telemetry-up telemetry-down telemetry-build telemetry-logs telemetry-restart telemetry-init-db telemetry-test-metric telemetry-status
.PHONY: up-all down-all

SHELL := /bin/bash

# ──────────────────────────────────────────────────────────────────────────────
# Application (pnpm / Moon)
# ──────────────────────────────────────────────────────────────────────────────

dev:
	pnpm run dev

build:
	pnpm run build

typecheck:
	pnpm run typecheck

# ──────────────────────────────────────────────────────────────────────────────
# Telemetry Stack
#
#   Docker commands reference the telemetry submodule compose file:
#     telemetry/deploy/docker-compose.yml
#
#   For local development, append the port override:
#     make telemetry-up-local
#
#   The telmetry compose file is inside the submodule so paths (volumes,
#   build context) are relative to telemetry/ — but we run docker compose
#   from the project root using -f.
# ──────────────────────────────────────────────────────────────────────────────

TELEMETRY_COMPOSE := telemetry/deploy/docker-compose.yml
TELEMETRY_LOCAL   := telemetry/deploy/docker-compose.local.yml
TELEMETRY_ZEAVIS  := docker-compose.telemetry.yml

# Start all telemetry services (standalone — cross-VPS production mode)
# Prometheus scrapes ZeaVis Edu via Tailscale IPs, not Docker network.
telemetry-up:
	@echo ">> Starting Telemetry stack (standalone)..."
	CLICKHOUSE_USER=$${CLICKHOUSE_USER:-telemetry} \
	CLICKHOUSE_PASSWORD=$${CLICKHOUSE_PASSWORD:-telemetry} \
	docker compose -f $(TELEMETRY_COMPOSE) up -d
	@echo ">> Telemetry stack started. Use 'make telemetry-logs' to view output."

# Start telemetry services with ZeaVis Edu network sharing (local single-host dev)
# Prometheus can scrape app services via app-shared-net Docker network.
telemetry-up-local:
	@echo ">> Starting Telemetry stack (local dev mode)..."
	CLICKHOUSE_USER=$${CLICKHOUSE_USER:-telemetry} \
	CLICKHOUSE_PASSWORD=$${CLICKHOUSE_PASSWORD:-telemetry} \
	docker compose -f $(TELEMETRY_COMPOSE) -f $(TELEMETRY_LOCAL) -f $(TELEMETRY_ZEAVIS) up -d
	@echo ">> Telemetry stack started in local dev mode."

# Stop all telemetry services
telemetry-down:
	@echo ">> Stopping Telemetry stack..."
	docker compose -f $(TELEMETRY_COMPOSE) -f $(TELEMETRY_ZEAVIS) down
	@echo ">> Telemetry stack stopped."

# Build telemetry components (metric-ingester + telemetry-ui)
# Runs inside the telemetry submodule using its own Makefile.
telemetry-build:
	@echo ">> Building Telemetry components..."
	$(MAKE) -C telemetry build
	@echo ">> Telemetry components built."

# Tail telemetry logs (optionally filter by service: s=<name>)
telemetry-logs:
ifdef s
	CLICKHOUSE_USER=$${CLICKHOUSE_USER:-telemetry} \
	CLICKHOUSE_PASSWORD=$${CLICKHOUSE_PASSWORD:-telemetry} \
	docker compose -f $(TELEMETRY_COMPOSE) -f $(TELEMETRY_ZEAVIS) logs -f $(s)
else
	CLICKHOUSE_USER=$${CLICKHOUSE_USER:-telemetry} \
	CLICKHOUSE_PASSWORD=$${CLICKHOUSE_PASSWORD:-telemetry} \
	docker compose -f $(TELEMETRY_COMPOSE) -f $(TELEMETRY_ZEAVIS) logs -f
endif

# Restart a single telemetry service
telemetry-restart:
ifdef s
	@echo ">> Restarting service: $(s)..."
	CLICKHOUSE_USER=$${CLICKHOUSE_USER:-telemetry} \
	CLICKHOUSE_PASSWORD=$${CLICKHOUSE_PASSWORD:-telemetry} \
	docker compose -f $(TELEMETRY_COMPOSE) -f $(TELEMETRY_ZEAVIS) restart $(s)
	@echo ">> Service $(s) restarted."
else
	@echo "Usage: make telemetry-restart s=<service-name>"
	@echo "Services: prometheus metric-ingester vector clickhouse query-proxy telemetry-ui"
	@exit 1
endif

# Initialize ClickHouse schema
telemetry-init-db:
	@echo ">> Initializing ClickHouse schema..."
	cd telemetry/clickhouse && DOCKER_CONTAINER=telemetry-clickhouse bash init.sh
	@echo ">> Schema initialized."

# Send a test metric through the pipeline
telemetry-test-metric:
	@echo ">> Sending test metric to Vector on port 9001..."
	curl -X POST http://localhost:9001/metrics \
		-H "Content-Type: application/json" \
		-d '{"metric_name":"test_zeavis","value":1.0,"timestamp":"$(shell date -u +%Y-%m-%dT%H:%M:%SZ)","labels":{"service":"zeavis-edu"},"env":"dev","region":"local"}'
	@echo ""
	@echo ">> Metric sent. Check telemetry-logs to verify ingestion."

# Show service status (health check overview)
telemetry-status:
	@echo ">> Telemetry stack status:"
	@echo ""
	@echo "--- Prometheus ---"
	-curl -s --max-time 3 http://localhost:9090/-/healthy && echo " healthy" || echo " unhealthy"
	@echo ""
	@echo "--- Metric Ingester ---"
	-curl -s --max-time 3 http://localhost:9091/health || echo " unhealthy"
	@echo ""
	@echo "--- Vector ---"
	-curl -s --max-time 3 http://localhost:9001/health || echo " unhealthy"
	@echo ""
	@echo "--- ClickHouse ---"
	-curl -s --max-time 3 http://localhost:8123/ping && echo " healthy" || echo " unhealthy"
	@echo ""
	@echo "--- Query Proxy ---"
	-curl -s --max-time 3 http://localhost:9092/health || echo " unhealthy"
	@echo ""
	@echo "--- Telemetry UI ---"
	-curl -s --max-time 3 -o /dev/null -w "%{http_code}" http://localhost:8181/ && echo " ok" || echo " unhealthy"

# ──────────────────────────────────────────────────────────────────────────────
# Combined
# ──────────────────────────────────────────────────────────────────────────────

# Start everything (app + telemetry)
up-all: telemetry-up
	pnpm run dev

# Stop everything
down-all: telemetry-down
	@echo ">> All services stopped."
