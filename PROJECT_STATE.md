# Project State — GIOP-LAB

## Current phase

Phase 1 — Minimal Observability Lab complete and runtime-validated on 2026-09-29.

## Implemented components

- Docker Compose topology for PostgreSQL 16, Zabbix Server 7.0, Zabbix Web, Zabbix Agent 2, and controlled Nginx workload.
- Bootstrap job that configures a synthetic target, item, and trigger through the Zabbix API.
- Persistent named PostgreSQL volume; isolated monitor and workload bridge networks.
- PowerShell lifecycle, status, logs, and smoke-test scripts.
- Architecture and controlled-incident runbook.

## Architecture

Only Zabbix Web is exposed to the host on port 8080 by default through a dedicated frontend network. PostgreSQL and Zabbix Server remain on the internal monitor network. The synthetic web workload has no host port and lives on an internal workload network; Agent 2 bridges the networks solely to test its health endpoint.

## Environment assumptions

Windows PowerShell, Docker Desktop Engine, Docker Compose v2+, and a local `.env` are required. The `.env` is Git-ignored. All identifiers are synthetic.

## Commands

Copy `.env.example` to `.env`, replace placeholders, then run `./scripts/lab-up.ps1`, `./scripts/lab-status.ps1`, `./scripts/lab-smoke-test.ps1`, and `./scripts/lab-down.ps1`.

## Validation status

- Environment discovery: passed on 2026-09-29 (Docker Engine 29.8.0, Compose 5.5.1, WSL2 installed).
- `docker compose config --quiet`: passed.
- Compose stack: PostgreSQL and Nginx healthchecks healthy; Zabbix Server and Agent 2 running; Zabbix Web returned HTTP 200 on `localhost:8080`; bootstrap exited 0.
- `scripts/lab-smoke-test.ps1`: passed (Compose configuration, frontend HTTP 200, Agent 2 check value `1`).
- RB-LAB-001 outage: passed. Stopping only `web-workload` produced monitoring value `0` and one open `GIOP-LAB: controlled web workload TCP unavailable` problem.
- RB-LAB-001 recovery: passed. Starting only `web-workload` restored value `1` and open-problem count `0`.

## Known issues

Initial image pulls and database initialization can take several minutes. Phase 1 has no notification channel; the Zabbix problem event is the alert artifact. Direct PowerShell script execution is blocked by the current local execution policy; use the documented process-only bypass or an allowed local policy.

## Pending decisions

None for Phase 1. GLPI, Grafana, NetBox, Guacamole, MeshCentral, Oxidized, Ansible, and AI are explicitly out of scope.

## Next approved action

Keep Phase 1 stable, review the evidence in Zabbix, and explicitly approve a later phase before adding any integration.
