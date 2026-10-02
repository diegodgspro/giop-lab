# GIOP-LAB

Local synthetic Infrastructure Operations laboratory. No real municipal operational dataset is represented by the synthetic LAB. The actual physical municipal site count remains TO VALIDATE.

PHASE 1: COMPLETE. PHASE 2: COMPLETE. PHASE 3: NOT STARTED.

Phase 1 provides Zabbix observability of a controlled Nginx workload. The operator validated the 2026-10-02 outage from 19:42:31 to 19:44:26 local time (1m55s), final problem RESOLVED and smoke result `lab.web.status [s|1]`: PASS.

Phase 2 provides GLPI 11.0.9 ITSM/CMDB with MySQL persistence. Validated seed: 41 Locations, 127 Computers, 51 NetworkEquipment and 93 Tickets. Separate GLPI Agent 1.20 inventory discovered `GUA-LAB-INVENTORY-001`, Computer ID 182. 127 seeded + 1 discovered = 128 conceptual LAB Computers. The endpoint remained ID 182 after `lab-down` / `lab-up`: persistence PASS.

## Local operation

1. Copy `.env.example` to `.env` and replace every `CHANGE_ME` value with a strong local secret. Keep `.env` ignored.
2. Run `./scripts/lab-up.ps1`.
3. Open Zabbix at http://localhost:8080 (Admin with local `ZABBIX_ADMIN_PASSWORD`) and GLPI at http://localhost:8081 with locally configured credentials.
4. Run `./scripts/lab-smoke-test.ps1` and `./scripts/glpi-smoke-test.ps1` when runtime checks are needed.

If execution policy blocks invocation, use a process-only bypass: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lab-up.ps1`.

`lab-status.ps1`, `glpi-status.ps1` and `lab-logs.ps1 [service]` inspect services. `lab-down.ps1` stops the base stack while retaining volumes. The inventory job has its own Compose file and exits after submission.

For API scripts, configure local `.env` keys `GLPI_API_BASE_URL` (http://localhost:8081), `GLPI_API_USERNAME`, `GLPI_API_PASSWORD`, `GLPI_OAUTH_CLIENT_ID`, `GLPI_OAUTH_CLIENT_SECRET`. The validated API client uses scope `api`; token acquisition and API read returned HTTP 200. `IDENTITY_CONFIRMATION=REQUIRES_USER_SCOPE` is expected.

For inventory, configure separate local `GLPI_INVENTORY_OAUTH_CLIENT_ID` and `GLPI_INVENTORY_OAUTH_CLIENT_SECRET` for OAuth Client Credentials, scope `inventory`. With the base stack running, invoke `docker compose --env-file .env -f docker/docker-compose.inventory.yml up --build --abort-on-container-exit --exit-code-from glpi-inventory-agent`, then read back using `scripts/glpi-agent-inventory-check.ps1`. Do not include credentials in commands, screenshots or committed logs.

## Scope and evidence

Frontends bind only 127.0.0.1 ports 8080/8081; databases expose no host ports. Agent uses only `giop-lab-glpi-frontend`, with no direct database network, host port, privileged mode, host networking, socket or host filesystem mount.

Entity creation was rejected; native Locations hold the synthetic topology. Ticket-to-CI mappings are logical manifest entries because the inspected High-Level API exposed no supported Ticket-Item association route. Historical timestamps were not manipulated. Container inventory has incomplete memory details and no native NetworkPort objects; no missing data is fabricated.

The older `Zabbix server` problem `Linux: Zabbix agent is not available (for 3m)` is unrelated LAB configuration noise to review; no recovery is claimed.

There is no Zabbix -> GLPI incident automation. The next proposed Phase 3 objective is architecture design for CI/severity mapping, deduplication, correlation, recovery, auditability and ticket-storm prevention, without autonomous remediation.

See [project state](PROJECT_STATE.md), [v0.2 architecture](docs/architecture/lab-v0.2.md), [CMDB model](docs/architecture/cmdb-model-v0.1.md), [CI naming](docs/standards/ci-naming-standard.md), [outage runbook](docs/runbooks/RB-LAB-001-service-outage.md) and [GLPI runbook](docs/runbooks/RB-LAB-002-glpi-incident-lifecycle.md). Runtime evidence is operator-supplied; finalization CLI checks are static.
