# GIOP-LAB

GIOP-LAB is a local, fully synthetic Infrastructure Operations simulation laboratory. It never contains or targets real municipal assets, credentials, addresses, names, or configurations.

## Phase 1

The minimal observability lab proves monitor → detect → alert/event → recover. It runs PostgreSQL, Zabbix Server, Zabbix Web, Zabbix Agent 2, and a stoppable synthetic Nginx workload.

## Quick start

1. Copy `.env.example` to `.env`.
2. Replace both `CHANGE_ME` passwords with strong local-only secrets.
3. Run `./scripts/lab-up.ps1`.
4. Open http://localhost:8080 and sign in as `Admin` with `ZABBIX_ADMIN_PASSWORD` from the local `.env`.
5. Run `./scripts/lab-smoke-test.ps1`.

If the local PowerShell execution policy blocks direct script invocation, use the non-persistent process-only form: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lab-up.ps1`. This does not alter the Windows execution policy.

See PROJECT_STATE.md, docs/architecture/lab-v0.1.md, and docs/runbooks/RB-LAB-001-service-outage.md.

## Operations

- `./scripts/lab-status.ps1` — service state
- `./scripts/lab-logs.ps1 [service]` — recent logs
- `./scripts/lab-down.ps1` — stop services while retaining persistent data

No destructive reset operation is included.
