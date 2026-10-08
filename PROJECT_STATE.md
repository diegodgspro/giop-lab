# Project State - GIOP-LAB

## Public portfolio release preparation

Branch `release/1.0-public-portfolio` starts at `giop-lab-v0.6.0` /
`0f9186c9082aa16472d2d086cc49950e6d20e09f`. v1.0 preparation changes public
presentation, documentation/assets and review tooling only. No runtime feature,
outage or history rewrite is performed. Final preparation includes one release commit
and the local annotated `giop-lab-v1.0.0` tag; no push or publication.
Previous phase entries below remain historical engineering evidence.

Public README, four reviewed SYNTHETIC LAB captures, architecture/ownership overview,
staged setup, 5–8 minute demo, portfolio text and GitHub/release metadata are
prepared. Runtime evidence remains ignored. The owner selected the MIT License,
provided in LICENSE. SECURITY.md is concise.

The real AI limitation is preserved: Ollama 0.35.1 / llama3.2:3b passed structured
validation but partly marked supplied workload-state evidence UNKNOWN and selected
RB-OPS-001. Confidence is not calibrated and human decision remains authoritative.
See [public review](docs/release/public-safety-review.md),
[setup](docs/setup/quick-start.md) and [release notes](docs/release/v1.0-release-notes.md).

## Current Phase 6 state

Read-only AI analysis MVP on `phase/6-ai-incident-analysis`, from
`giop-lab-v0.5.0` / `385ef17cca4abdbd38e3e3aa24bcbfef2c12ff3a`.
Phase 6 finalized with local commit and annotated tag `giop-lab-v0.6.0`; no push.
Previous tags, Integration, runbooks and aggregation unchanged.
FastAPI AI Assistant receives sanitized bounded context from Control Center only.
Fixture remains deterministic for tests and is not a language model. The active
provider is now Ollama 0.35.1 / llama3.2:3b, installed by the operator. Real historical
analysis and one bounded injection check passed the strict advisory contract.
No host installation/configuration or new outage was performed.

Historical Problem 41 / Ticket 97 / Recovery 42 / Follow-up 4 is analyzed using
operator-projected RB-OPS-002 evidence. Historical degraded facts are separate from
current Healthy state. Counts remain 128 active Computers / 51 NetworkEquipment / 97
Tickets, all SYNTHETIC LAB. AI recommends known runbooks but cannot execute them.
Observed/inferred/unknown labels, confidence, risk and approval are visible.

Validation: 21 AI, 27 Control Center, 6 Phase 3 and 17 Phase 5 cases; browser/API
checks and desktop/mobile screenshots; credential/runtime/whitespace review.
AI outage does not prevent normal Control Center operation. Details and limitations:
[Phase 6 demo](docs/demo/phase6-ai-incident-analysis.md) and
[architecture](docs/architecture/ai-incident-analysis-v0.1.md).


Structured validity does not guarantee diagnostic correctness. Real llama3.2:3b
inference passed strict schema validation without output repair, but was not fully
operationally accurate: historical workload state was supplied and partly reported
as UNKNOWN. It recommended RB-OPS-001 (Service Health Check), not RB-OPS-003.
Model confidence values (40% overall, 60% inferred cause) are not calibrated
probabilities. AI output is advisory; operator review and human decision remain
authoritative. One injection-oriented check is not a general security guarantee.

## Historical Phase 5 status

PHASE 5: OPERATIONAL RUNBOOKS MVP COMPLETE AND LOCALLY VALIDATED; LOCAL RELEASE giop-lab-v0.5.0; NO PUSH.

Branch: `phase/5-operational-runbooks`, created from `giop-lab-v0.4.0`.
Frozen baseline remains `42e3cbab9758624dfe3be42459f6931ae3519197`.
The v0.4.0 tag and existing Integration write behavior are unchanged.

## Phase 5 implementation and live evidence (2026-10-06 UTC)

Exactly three operator-local PowerShell runbooks share `scripts/lib/GiopRunbooks.ps1`:
RB-OPS-001 read-only health, RB-OPS-002 read-only sanitized incident diagnostics,
RB-OPS-003 dry-run by default / explicit -Execute for only web-workload. Fixed
Compose/container/host/trigger/item/CI/Ticket identities fail closed. Apply rechecks
identity and holds a local mutex. No generic command inputs, automatic remediation,
new service/DB/network, DB access, or direct GLPI/Zabbix mutation is introduced.

Every execution writes ignored summary.json, summary.md and diagnostics.txt with
UTC timestamps, execution/runbook IDs, operator request, mode, fixed target,
preconditions, actions, results, validation and overall status. Fields are projected;
known credentials are redacted. No raw logs, headers, .env or container environment.
The static Control Center `/runbooks` catalog shows purpose/risk/mode, explicitly
reports latest execution unavailable, and offers no browser execution/API.

Actual controlled validation: Problem 41 → Ticket 97 → Recovery 42 → Follow-up 4.
Health was DEGRADED; diagnostics captured that actual episode. Plan performed no
action. Explicit recovery started only web-workload and validated fresh item=1,
trigger=OK, healthy HTTP workload, same recovered episode and API-confirmed GLPI
follow-up. Existing Phase 3 automation performed the Incident/Recovery writes.
Final workload and Control Center returned Healthy; Ticket remains for human validation.

Live artifacts (ignored): baseline `20261006T130553218Z-a782931f`, degraded health
`20261006T130618965Z-a1e757d7`, diagnostics `20261006T130620304Z-301c5034`, plan
`20261006T130621479Z-af7677a8`, apply `20261006T130622788Z-7d82a8f6`, final health
`20261006T130640183Z-7358269d`. Cross-reference: artifacts/runbooks/phase5-live-demo.json.
An initial interrupted validation exposed Windows PowerShell 5.1's treatment of
Docker progress on stderr; the workload was restored, producing historical
Problem 39 / Ticket 96 / Recovery 40 / Follow-up 3. The fixed runbook now uses the
native exit code. These actual LAB events are retained, not deleted or fabricated.
Current inventory remains 128 active Computers and 51 NetworkEquipment; Tickets
increased from the historical Phase 4 count 95 to 97 through these two actual incidents.

Validation: 17 offline runbook cases; 20 Control Center tests (including all existing
Phase 4 cases); six unchanged Phase 3 tests. Live apply/end-to-end evidence above.
Browser desktop/mobile/API and secret/whitespace review are recorded in the Phase 5 demo.
Finalization: `feat(runbooks): add controlled N3 operational response workflow`;
annotated local tag `giop-lab-v0.5.0`. Runtime evidence remains excluded. No push was performed at Phase 5 finalization. Details: docs/demo/phase5-operational-runbooks.md.

## Historical Phase 4 implementation and evidence (2026-10-05 local / 2026-10-06 UTC)

One stateless `control-center/` service uses Python/FastAPI/Jinja2 and local
HTML/CSS/vanilla JavaScript. It aggregates Zabbix JSON-RPC reads, GLPI High-Level
API GETs and Integration `/health` plus authenticated `/api/v1/episodes`.
Only authentication/session operations use outbound POST. No business mutations,
SQLite mounts, direct database access, new databases or remediation are implemented.

Pages: `/`, `/infrastructure`, `/incidents`, `/events`. Read endpoints:
`/api/overview`, `/api/infrastructure`, `/api/incidents`, `/api/events`, `/health`.
Source reads run concurrently; memory-only snapshots expire after 15 seconds.
The browser polls every 20 seconds and receives projected fields, never credentials,
upstream errors or raw ticket content. Values are escaped before HTML rendering.

Live reads confirmed all three APIs Healthy, Zabbix 7.0.31, two enabled API-visible
hosts, zero active API-visible Problems and pilot trigger 25228 OK. Bounded GLPI
enumeration returned 128 current/non-deleted Computers, 51 NetworkEquipment and 95 Tickets visible in
entity 0; Computers display all 128 active rows, other tables the first 100 records.
Computer pages use `filter=is_deleted==false`. The unfiltered collection contains
182 Computer objects including 54 soft-deleted recycle-bin records.
127 deterministic seeded Computers + 1 GLPI Agent-discovered Computer = 128 active LAB Computers. These current synthetic LAB counts
are separate from historical seed/read-back evidence, not municipal production totals.
Enumeration must reach an empty page with unique ordered IDs before claiming a
total, with a five-page limit. API metadata alone does not fabricate totals.

Integration returned six episodes: two LIVE recovered awaiting operator validation,
four dry-run. Latest actual correlation: Problem 37 → Ticket 95 → Recovery 38 →
follow-up 2. IDs are dynamic, not permanent dashboard fixtures. Two GIOP-generated
Incidents were visible in the current Ticket window. No lifetime duplicate count
is available or invented.

The Control Center Docker image built/started successfully at `127.0.0.1:8091`.
Application-only networks: `giop-lab-frontend`, `giop-lab-glpi-frontend`,
`giop-lab-integration-webhook`. UID 10002, read-only root filesystem, dropped
capabilities, no-new-privileges and `/tmp` tmpfs. No persistent volumes, database
networks, privileged/host mode or Docker socket.

Validation includes unit/API checks, unchanged Phase 3 tests, Compose config,
actual build/start, live endpoints and isolated headless Chromium checks for all
pages, polling without reload, desktop/mobile rendering and absence of local
credential values in API/DOM. Development Playwright is optional, not shipped
in the image. Screenshots are ignored under `artifacts/control-center/`.
No workload outage, Ticket mutation or integration state write was performed.

Limits: bounded/profile-visible snapshots; asset state does not prove availability;
synthetic infrastructure health uses only the pilot trigger. Logical CI mapping
uses the frozen Phase 3 contract; no native Ticket-CI relation is asserted.
Compose supports separate read identities but falls back to existing LAB credentials;
least privilege is not certified. Aware times display UTC; unknown source timezones
remain labelled. Detections and persisted observations may appear separately on
the timeline. Duplicate, inventory-receipt and service-change history is not invented.

Operation and demo: `docs/demo/phase4-control-center.md`.

Final local results: 18 Control Center tests and six unchanged Phase 3 tests passed;
live/headless browser checks passed, including mobile, polling and partial failure.
Repository review checked 81 tracked/intended files against 13 distinct local
credential values without disclosure; no matches found. `.env`, scoped alert secret,
SQLite, virtualenv/cache and local screenshot artifacts remain ignored. No files
are staged; HEAD still equals the frozen v0.3.0 tag target.

## Frozen Phase 1–3 status

PHASE 1: COMPLETE

PHASE 2: COMPLETE

PHASE 3A: PRESERVED AS FUTURE PRODUCTION-HARDENING DOCUMENTATION

PHASE 3 MVP: AUTOMATIC LIVE VALIDATED; v0.3.0 LOCAL FINALIZATION

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

N3 Operator uses Zabbix for observability of the synthetic workload and GLPI for ITSM/CMDB, deterministic seed and automated inventory. Phase 3 MVP now implements the pilot integration described below; historical Phase 3A evidence remains preserved.

## Phase 3 MVP strategy and implementation (2026-10-05)

Current branch: `phase/3-mvp-integration`. Portfolio MVP supersedes historical
Phase 3A implementation gates, while preserving all its architecture/security files
as future hardening documentation. Finalization is authorized for a local commit and
annotated giop-lab-v0.3.0 tag only; no push or Phase 4.

Implemented: one FastAPI/Python service, one worker, SQLite named volume;
authenticated bounded JSON webhook; explicit pilot host 10683 / trigger 25228 /
canonical GUA-LAB-SRV-WEB-001 / Computer 1 / entity 0 / immutable CI UID.
Default dry-run persists intended decisions without GLPI access. Live mode creates
one type-1 Incident, external_id/content marker and one public Recovery follow-up.
The integration performs no lifecycle transitions, assignment, asset changes or remediation.
Recovery state is RECOVERED_PENDING_OPERATOR_VALIDATION. Event/marker uniqueness,
serialized processing and intent-before-send prevent blind duplicate writes after restart.

Separate integration Compose binds 127.0.0.1:8090; only GLPI frontend and dedicated
webhook application networks. Optional source override attaches Zabbix Server to
the webhook network with a secret-free alert script; the secret is supplied from
ignored .env through scoped .env.zabbix-alert, never stored in Zabbix media parameters. No DB network access,
privileged container, host network or Docker socket. All content is synthetic LAB.

Operator delivery scripts, authenticated JSON state inspection and five-minute
demo: `docs/demo/phase3-mvp-demo.md`. Six automated test functions cover the eight
requested scenarios plus dry-run, bounds, concurrency and ambiguous write handling.
Manual LIVE GLPI writes, deduplication and automatic Action delivery are
operator-validated. Mocked tests do not
certify external_id roundtrip or comprehensive profile grants. Production pagination,
reconciliation, full least privilege, priority matrix and lifecycle semantics remain debt.

## Validated automatic MVP evidence (2026-10-05)

All LAB records are synthetic; these IDs are not municipal production data.
Operator-confirmed Zabbix 7.0.31 and LIVE integration completed this architecture:

Synthetic workload → Zabbix detection → Trigger Action → `giop-alert.sh` →
FastAPI integration → SQLite persistence/deduplication → GLPI Incident →
Zabbix Recovery → GLPI Follow-up → operator validation.

The pilot is restricted to host **10683 AND trigger 25228**. Stopping the synthetic
workload produced Zabbix pilot event **37**. The automatic Action delivered it,
the integration persisted **PROBLEM_OPEN**, and GLPI automatically created
**Ticket #95**, titled **GIOP-LAB Zabbix synthetic event 37**.
After workload restoration, Zabbix detected Recovery and the correlated episode
became **RECOVERED_PENDING_OPERATOR_VALIDATION**, with a GLPI Recovery follow-up.
Neither `Send-GiopSyntheticProblem.ps1` nor `Send-GiopSyntheticRecovery.ps1` was
used in this automatic demonstration. Automatic closure is intentionally disabled.
The Recovery event ID and follow-up ID were not supplied; no values are invented.

Automatic provisioning completed; the second run returned **UNCHANGED for all
managed objects**, confirming operator-observed idempotency. Earlier operator LIVE
checks confirmed duplicate Problem/Recovery suppression. Local mocked tests verify
one ticket/one follow-up after duplicates and restart; these fixtures are separate
from event 37 and Ticket 95.

Zabbix displayed approximately UTC-3 while GLPI displayed UTC for the same event.
This LAB presentation difference is non-blocking MVP technical debt.

## Post-MVP technical debt

These items do not block **v0.3.0**; this local pilot is not certified for production:

- Complete API response reconciliation, including ambiguous write outcomes.
- Exhaustive pagination hardening.
- Native GLPI Ticket-CI relation (current mapping is logical/content/state only).
- Full least-privilege audit.
- TLS outside the local LAB.
- HA.
- Larger event-burst validation.
- Timezone normalization.
- Production Entity/topology mapping.

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

Phase 3 MVP final regression (2026-10-05): PASS. PowerShell parser validated
22 scripts/tests; the repository structure validator passed. Six Python/FastAPI
integration tests passed, covering persistent deduplication across restart,
concurrent repeats, Recovery correlation, dry-run, invalid requests, nonpilot
events and uncertain writes. GLPI is mocked in this suite. Offline Zabbix
provisioning tests passed for WhatIf, create, unchanged rerun, drift update,
preservation, duplicate rejection and pilot-only guards.

Docker Compose config validation passed for base, inventory, integration and
base + integration-source using `.env.example` and synthetic inventory placeholders;
no containers were changed by these checks. Working and staged `git diff --check`
passed. Secret review scanned 67 indexed files and matched 14 local credential
values without disclosure: no matches or credential signatures found. Literal
review found only runtime references, configuration flags and synthetic test values.
`.env` and `.env.zabbix-alert` remain ignored and untracked; runtime SQLite,
virtualenv/cache files and logs are excluded. Pytest reported one upstream AnyIO
deprecation warning. The finalization does not repeat the operator's live outage.

The following earlier static-review paragraph records Phase 2 finalization.

Repository secret review covers tracked and intended untracked files, local credential-value matching without printing values, credential signatures and manual review of runtime references. `.env` remains ignored. No real secret or copied credential-bearing Authorization header was found. The existing Zabbix bootstrap references the public factory default only to replace it with the local configured password; this is not a local secret. No accidental temporary artifacts were found.

Static checks passed: PowerShell parser for all scripts/tests, shell syntax for the Agent entrypoint and Zabbix bootstrap, repository structure validator, JSON counts/uniqueness/logical CI references, both Compose files via `docker compose config --quiet` with placeholders, and `git diff --check`. Compose validates YAML without starting containers. PSScriptAnalyzer and PyYAML were unavailable; no additional lint result is claimed. Runtime results above remain operator evidence; CLI finalization does not claim Docker runtime testing.

## Historical Phase 3A preparation (superseded by the validated MVP)

Branch phase/3a-integration-contract starts exactly at giop-lab-v0.2.0 commit c364e10e4182b7afd09aafafd8dc44f0eba858ea. Tag unchanged. No new commit, push, platform, receiver, integration service/DB, media type/action or business API write.

Read-only live evidence on 2026-10-02 confirms Zabbix Server/Web/Agent 2 all 7.0.31, revision e7da53e for binaries. Exact image references/digests and GLPI OpenAPI canonical hash are in docs/architecture/zabbix-glpi-integration-v0.1.md. GLPI CLI remains 11.0.9; API schema version 2.3.0. Ticket GET/POST/PATCH and follow-up GET/POST are exposed by schema; collection/follow-up and Computer GET were checked without writes. external_id exact RSQL filter accepted with zero-result marker. Positive marker roundtrip and dedicated rights remain unvalidated. No native Ticket-CI write association found. status.id is readOnly in live schema despite Phase 2 seed mutation evidence; no lifecycle mutation is authorized.

Old warning root cause confirmed: default host 10084 has Linux by Zabbix agent and Zabbix server health, passive interface 127.0.0.1:10050. Server-container zabbix_get failed there. Agent 2 is separate and belongs to synthetic host 10683. Proposed operator-only correction: Unlink and clear ONLY Linux by Zabbix agent, retain health template; do not manually close/fabricate recovery. No live change was made. Exact operator steps and consequences are documented.

Pilot contract: immutable CI UID in event-ci-mapping-v0.1.md, host 10683 / trigger 25228 / Computer 1 / entity 0 / synthetic-web-tcp. Computer 182 inventory endpoint is NOT this CI. Mapping status pending operator approval. Allow exactly the controlled TCP trigger. Unknown/multiple mappings fail closed. Proposed pilot impact 1 and configured GLPI priority matrix require operator confirmation.

Dedicated technical identity giop-lab-zabbix-glpi-integration must be created by operator only after scope/grant decisions. Never reuse inventory identity. Existing CLI Automation effective grants are not certified least privilege. Initial proposed rights: own-ticket read/Create, public follow-up read/add to own tickets, Computer Read, root entity 0 nonrecursive only if approved. Update rights deferred until necessary; no state transitions/admin/deletion/asset writes. API grant/ownership and least-privilege acceptance need validation with new identity. Instructions: integration-security-v0.1.md.

Design: one service, SQLite persistent volume, dry-run first, episode and operation unique keys, intent-before-send and external_id reconciliation, no blind retry after lost response. Recovery state RECOVERED_PENDING_OPERATOR_VALIDATION; no solve/close/reopen. No DB access or autonomous remediation.

Documents: zabbix-glpi-integration-v0.1.md, event-ci-mapping-v0.1.md, integration-state-model-v0.1.md, integration-security-v0.1.md under docs/architecture; docs/testing/phase3-test-matrix.md; docs/roadmap.md.

Unresolved operator actions: default-host correction decision; approve immutable identities/pilot/root-entity scope and impact/matrix; custom profile/user/OAuth grant/client configuration; later authorized positive marker/follow-up/write rights and lifecycle-contract tests. No automatic commit while these decisions remain unresolved. Implementation requires a separate dry-run request after preparation review; automatic writes remain disabled.
