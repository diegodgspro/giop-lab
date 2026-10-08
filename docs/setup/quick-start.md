# Staged local setup — SYNTHETIC LAB

This is not a one-command integrated installation. Runtime databases, credentials,
Ollama models and historical evidence are intentionally not distributed. A new clone
does not contain Ticket 97. The full governed demo depends on operator provisioning
and matching the fixed approved pilot identities.

## Prerequisites

Windows PowerShell, Git and Docker Desktop with Linux containers/Compose v2.
Use Python 3.13 for tests and diagnostic projection. Ollama is optional; the real
provider was validated with operator-installed Ollama 0.35.1 / llama3.2:3b.
Third-party installation/downloads are operator choices, not automated setup steps.
Run commands from the repository root. Ports below are the defaults.

## 1. Core LAB

```powershell
Copy-Item .env.example .env
# Edit only your local ignored .env; replace every CHANGE_ME with local values.
./scripts/lab-up.ps1
./scripts/lab-smoke-test.ps1
./scripts/glpi-smoke-test.ps1
```

Configure local database passwords and Zabbix administrator credentials first.
`lab-up.ps1` rejects any remaining `CHANGE_ME` text, even in example comments or
optional/later-stage keys. Remove unused placeholder entries and example comments
from the local .env until only configured core settings remain; add dedicated GLPI
integration/client/notification settings when their later stages are ready. Do not
invent usable OAuth IDs before creating the client, or start Integration with dummy
credentials. Do not print or commit the filled environment. If policy blocks scripts,
use a process-only invocation such as
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lab-up.ps1`.
The base stack provisions the synthetic Zabbix TCP check; never substitute a real host.

| Component | Default endpoint | Exposure |
| --- | --- | --- |
| Zabbix | http://localhost:8080 | Host loopback |
| GLPI | http://localhost:8081 | Host loopback |
| Integration health (stage 3) | http://localhost:8090/health | Host loopback |
| Control Center (stage 4) | http://localhost:8091 | Host loopback |

PostgreSQL and MySQL have no published host ports. Docker-internal listener addresses
are not invitations to expose the apps publicly.

## 2. GLPI initialization, seed and identity

Finish GLPI's local installation/setup in its frontend and replace default account
credentials. Create the appropriate local OAuth API client/user/profile through GLPI;
do not infer least privilege from a name or the `api` scope alone.

The seed/probe scripts additionally consume these existing keys in ignored .env:
`GLPI_API_BASE_URL=http://localhost:8081`, `GLPI_API_USERNAME`, `GLPI_API_PASSWORD`,
`GLPI_OAUTH_CLIENT_ID`, `GLPI_OAUTH_CLIENT_SECRET`. They are not all in .env.example;
add them locally with credentials from your configured client. No secrets belong
in command-line examples. The seed uses the validated password grant and `api` scope.

```powershell
./scripts/glpi-api-probe.ps1
./scripts/seed-glpi-phase2.ps1
./scripts/seed-glpi-phase2.ps1 -ValidateOnly
```

Seeding is an intentional synthetic GLPI API write. Review the deterministic plan
in `data/glpi-phase2-seed.json` first; do not run it against a real instance.
The older `bootstrap-glpi-phase2.ps1` attempts Entity creation rejected in the
validated LAB; it is historical, not a substitute for this current seed path.
Separate optional GLPI Agent inventory is documented in the [Phase 2 snapshot](../architecture/lab-v0.2.md).
It is not required to demonstrate the web-service pilot.

## 3. Integration and automatic Zabbix delivery

Configure the existing `GLPI_INTEGRATION_*` keys and `GIOP_WEBHOOK_SECRET` with
the dedicated synthetic integration identity. See the [identity/security design](../architecture/integration-security-v0.1.md)
and [current delivery procedure](../demo/phase3-automatic-delivery.md).
Default `GIOP_INTEGRATION_MODE=dry-run` must be retained during initial read-back:

```powershell
docker compose --env-file .env -f docker/docker-compose.integration.yml up -d --build
./scripts/Test-GiopIntegrationHealth.ps1 -State
./scripts/Test-GlpiIntegrationContract.ps1
./scripts/Enable-GiopZabbixDelivery.ps1 -WhatIf
```

Verify approved Zabbix host 10683 / trigger 25228 and GLPI Computer 1,
`GUA-LAB-SRV-WEB-001`, root entity 0, with the frozen logical CI identity.
**Fresh instances can allocate different IDs. Stop if they do not match.**
The MVP is not a portable discovery/provisioning system. Do not weaken fail-closed
checks, fabricate IDs or change production identities to force the demo.

Only after validating the dedicated identity, supported API writes and synthetic
mapping, explicitly choose `GIOP_INTEGRATION_MODE=live` in ignored .env and recreate
Integration with the same command. Then provision the approved delivery:

```powershell
./scripts/Enable-GiopZabbixDelivery.ps1
```

This operator action writes scoped ignored `.env.zabbix-alert`, configures the
Zabbix media/action and attaches its application network. It does not cause an outage.
Subsequent base-stack operations must preserve `docker/docker-compose.integration-source.yml`
as described in the delivery procedure; a plain base-only recreate can lose that layer.
Do not use manual synthetic event senders for an automatic delivery demonstration.

## 4. Control Center

With all source APIs and application networks ready:

```powershell
docker compose --env-file .env -f docker/docker-compose.control-center.yml up -d --build
```

Open http://localhost:8091. Source failures remain visibly Unavailable.
Optional `CONTROL_CENTER_*` keys provide separate read identities; existing LAB
credentials are fallbacks, not a completed least-privilege deployment claim.

## 5. Optional local AI

If Ollama/model are already installed, verify locally with `ollama --version` and
`ollama list`. Set these existing non-secret keys in ignored .env:

```dotenv
AI_PROVIDER=ollama
OLLAMA_MODEL=llama3.2:3b
OLLAMA_URL=http://host.docker.internal:11434
```

```powershell
docker compose --env-file .env -f docker/docker-compose.control-center.yml -f docker/docker-compose.ai-assistant.yml up -d --build
```

Verify container access to the local API before analyzing. It worked on the validated
Docker Desktop host without binding/firewall changes. Do not expose Ollama publicly.
AI Assistant has no public port; only Control Center proxies computation.
No model is automatically installed/downloaded and no fixture fallback is automatic.

For deterministic UI validation only, add `-f docker/docker-compose.ai-fixture.yml`
to that command. The UI labels fixture as NOT a language model.
Evidence projection and the operator demo are in [v1 public demo](../demo/v1-public-demo.md).

## Reset and persistence

`lab-down.ps1` stops the core LAB while retaining volumes. Do not delete volumes or
SQLite episodes to reset screenshots. Other Compose projects need their own stop
commands. Do not run outages during unit tests. This guide was checked against the
current scripts/configuration; a complete fresh-host installation was not re-executed
during public release preparation.
