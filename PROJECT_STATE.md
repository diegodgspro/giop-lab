# Project State - GIOP-LAB

## Phase status

PHASE 1: COMPLETE

PHASE 2: COMPLETE

PHASE 3: NOT STARTED

No real municipal operational dataset is represented by the synthetic LAB. The actual physical municipal site count remains TO VALIDATE.

## Validated operator runtime evidence

These results were supplied by the operator for Phase 2 finalization; they were not rerun as Docker runtime tests by the finalization CLI.

Phase 1 regression: PASS. Host `GUA-LAB-SRV-WEB-001 synthetic monitor` opened `GIOP-LAB: controlled web workload TCP unavailable` on 2026-10-02 at 19:42:31 local operator time, recovered at 19:44:26, duration 1m55s, final status RESOLVED. Healthy workload -> controlled outage -> Zabbix detected failure -> Problem opened -> workload restored -> Recovery detected -> Problem resolved -> `lab.web.status [s|1]`. Final smoke test passed.

GLPI 11.0.9: frontend HTTP 200; database schema OK. OAuth `TOKEN_ACQUISITION=SUCCESS`, `OAUTH_HTTP=200`, `API_READ_HTTP=200`, scope `api`. `IDENTITY_CONFIRMATION=REQUIRES_USER_SCOPE` is expected, not an error.

Deterministic seed 20260929: `SEED_COMPLETE LOCATIONS=41 COMPUTERS=127 NETWORK=51 TICKETS=93`. Computers comprise 11 server-class and 116 workstation-class CIs. Configuration: `data/glpi-phase2-seed.json`; non-secret read-back manifest: `artifacts/glpi-phase2-created.json`. Logical ticket-to-CI mappings remain in this manifest.

Automated inventory is separate: GLPI Agent 1.20 discovered `GUA-LAB-INVENTORY-001`, GLPI Computer ID 182, last inventory `2026-10-01T14:27:15+00:00`. OAuth Client Credentials uses scope `inventory`. Agent reached GLPI through Docker internal networking, detected Agent protocol support, executed Inventory, submitted inventory and exited code 0. Read-back: `INVENTORY_ENDPOINT=FOUND ID=182 NAME=GUA-LAB-INVENTORY-001`.

Discovered data includes Debian GNU/Linux 12 / bookworm, x86_64, kernel, processor/components, software inventory, automatic inventory metadata, Agent metadata, inventory timestamp and contact/IP metadata. Memory details were not fully populated and native GLPI NetworkPort objects were not populated. These are isolated Docker/WSL2 endpoint limitations; no fields are fabricated and no general production limitation is claimed.

127 seeded Computers + 1 discovered Computer = 128 conceptual LAB Computers. The discovered endpoint must not be added to the deterministic seed JSON.

Persistence: PASS. After `lab-down` -> `lab-up`, the endpoint remained Computer ID 182.

## Architecture and exposure

N3 Operator uses Zabbix for observability of the synthetic workload and GLPI for ITSM/CMDB, deterministic seed and automated inventory. No Zabbix -> GLPI incident automation exists.

Zabbix frontend binds `127.0.0.1:8080`; GLPI frontend binds `127.0.0.1:8081`; both returned HTTP 200. PostgreSQL and MySQL have no host exposure. Named volumes retain Zabbix PostgreSQL, GLPI MySQL and GLPI application data.

Agent is an isolated container on `giop-lab-glpi-frontend`, without direct connectivity to `giop-lab-glpi-db`, host ports, privileged mode, host networking, Docker socket or Windows host filesystem mounts. The independent inventory Compose file builds GLPI Agent 1.20 with a checked package SHA-256; credentials are runtime environment references, not build args or committed values.

## Operations and repository artifacts

Windows PowerShell, Docker Desktop/Compose, WSL2 and a Git-ignored local `.env` support the LAB. Copy `.env.example`, replace placeholders and configure local API and inventory OAuth credentials as described in README. Lifecycle: `scripts/lab-up.ps1`, `lab-status.ps1`, `lab-smoke-test.ps1`, `lab-logs.ps1`, `lab-down.ps1`. Stop retains volumes; no destructive reset is included.

GLPI checks: `glpi-smoke-test.ps1`, `glpi-status.ps1`, `glpi-api-probe.ps1`, `glpi-agent-inventory-check.ps1`. API diagnostics: `Test-GlpiOAuthConfiguration.ps1`, `Test-GlpiApiContext.ps1`, `Test-GlpiEntityCollection.ps1`. `seed-glpi-phase2.ps1` is the validated seed path. `bootstrap-glpi-phase2.ps1` is an earlier diagnostic bootstrap retained for provenance; it attempts the rejected Entity creation and is not the final seed procedure.

The seed uses read-before-create pagination. A one-time reviewed cleanup removed higher-ID synthetic workstation duplicates from diagnostics; validated read-back has 127 unique seeded computers. Do not run duplicate repair during finalization.

## Known limitations and LAB noise

- Dedicated GIOP-LAB Entity creation was rejected under current High-Level API authorization. Native Locations were used instead; the Entity label is a convention, not a created Entity claim.
- The inspected High-Level API exposed no supported native Ticket-Item association route. Manifest CI mappings are logical only; no native relationships are claimed.
- Historical ticket timestamps were not manipulated.
- Isolated Docker/WSL2 inventory lacks some physical-hardware details as recorded above.
- Older unrelated problem on host `Zabbix server`: `Linux: Zabbix agent is not available (for 3m)`. It predates the controlled regression and remains a LAB configuration/noise item to review. No recovery was fabricated and no unrelated Zabbix change was made.
- GLPI Compose uses `glpi/glpi:latest`; 11.0.9 is the observed validated version, not an immutable image pin. Zabbix also uses floating 7.0 tags.
- Credentials enter local process arguments/runtime environments; protect local process, Docker and log access. MySQL generates a root password which may appear in local initialization logs; logs must not be committed.

## Finalization static review

Repository secret review covers tracked and intended untracked files, local credential-value matching without printing values, credential signatures and manual review of runtime references. `.env` remains ignored. No real secret or copied credential-bearing Authorization header was found. The existing Zabbix bootstrap references the public factory default only to replace it with the local configured password; this is not a local secret. No accidental temporary artifacts were found.

Static checks passed: PowerShell parser for all scripts/tests, shell syntax for the Agent entrypoint and Zabbix bootstrap, repository structure validator, JSON counts/uniqueness/logical CI references, both Compose files via `docker compose config --quiet` with placeholders, and `git diff --check`. Compose validates YAML without starting containers. PSScriptAnalyzer and PyYAML were unavailable; no additional lint result is claimed. Runtime results above remain operator evidence; CLI finalization does not claim Docker runtime testing.

## Next proposed objective only

Design Zabbix -> GLPI event-to-incident integration with CI mapping, severity mapping, deduplication, event correlation, recovery handling, auditability, no ticket storm and no autonomous remediation. Phase 3 is NOT STARTED. No integration or additional platform is implemented or approved by this completion record.
