# Phase 3 MVP automatic Zabbix delivery

Manual LIVE PROBLEM, duplicate PROBLEM, Recovery and duplicate Recovery were validated
by the operator: one Incident, one public follow-up, recovered local state, ticket
still open. Automatic delivery is now also operator-validated, as recorded below.
The remaining procedure is retained as a reproducible LAB runbook.

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

## Applied network and script setup

| Component | Compose service | Running container | Application path |
| --- | --- | --- | --- |
| Zabbix Server | zabbix-server | gua-lab-zabbix-server-001 | giop-lab-integration-webhook |
| GIOP | integration | giop-lab-integration-integration-1 | same webhook network; GLPI frontend |
| GLPI | glpi | gua-lab-glpi-001 | giop-lab-glpi-frontend |

Internal delivery URL: `http://integration:8090/api/v1/zabbix/events`.
Never use localhost inside the Zabbix container to reach GIOP. The existing internal
`giop-lab-integration-webhook` network is the only added Zabbix network. Its existing
monitor/workload networks are retained. Integration does not join either database
network. Host interfaces stay on 127.0.0.1; no proxy, extra service, host networking,
privileged container or Docker socket is introduced.

Reused delivery mechanism: **Zabbix Script media type**, executing
`/usr/lib/zabbix/alertscripts/giop-alert.sh` with one `{ALERT.MESSAGE}` argument.
Zabbix's script mechanism does not guarantee inherited environment, so a scoped
ignored `.env.zabbix-alert` file supplies only the existing shared secret. It is
generated from `.env`, mounted read-only at `/run/giop/alert.env`, never sourced as
shell code, and never committed or printed. Rerun preparation after rotating the
secret. The script passes the header to curl through stdin, accepts only HTTP 202,
and normalizes the dotted Zabbix date to ISO 8601. No FastAPI compatibility change.
See [Zabbix custom alert scripts](https://www.zabbix.com/documentation/7.0/en/manual/config/notifications/media/script).

Preparation was applied and connectivity passed. To reproduce from repository root:

```powershell
# Integration must already be running with its persistent volume and mode live.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Enable-GiopZabbixDelivery.ps1
```

This script writes the ignored scoped file, validates Compose and recreates only
Zabbix Server using `up -d --no-deps`, then provisions the pilot Media Type,
notification group/user/media and Action through JSON-RPC. It causes no outage.
Use the source layer with future base-stack `up` commands to retain the
network and mounts; a base-only `up` may remove them. No secrets go into build args.

## API provisioning (preferred; no manual UI setup required)

The same script now handles all configuration below. Authentication comes only
from ignored `.env`: by default Admin with existing `ZABBIX_ADMIN_PASSWORD`, or
`ZABBIX_API_USERNAME` + `ZABBIX_API_PASSWORD`, or `ZABBIX_API_TOKEN` (takes precedence).
The account/token must have Super admin access and permission to call the listed
methods. Optional `ZABBIX_API_URL` defaults to localhost frontend `api_jsonrpc.php`,
using `ZABBIX_FRONTEND_PORT` (default 8080). Remote URLs are rejected in this LAB.
`GIOP_WEBHOOK_SECRET` is still required. Set `ZABBIX_NOTIFICATION_PASSWORD` to a
locally generated password before the first real run; it is used only for recipient
creation. Reruns never reset that password. Keep every secret in ignored `.env`.

Safe inspection from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Enable-GiopZabbixDelivery.ps1 -WhatIf
```

`-WhatIf` checks live version/pilot, authenticates, queries existing objects and
shows create/update/no-change decisions. Only login/logout and read methods are
allowed; no scoped file write, Docker command, API mutation or webhook delivery.
Missing initial recipient password is reported as required for apply.

Actual provisioning, run by the operator only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Enable-GiopZabbixDelivery.ps1
```

If Docker network/mounts/scoped secret are already prepared and current, append
`-SkipDockerSetup` to provision API objects only. This switch does not prove current
container connectivity; use the harmless health command below. The full command
requires Docker CLI in the operator terminal. The restricted CLI sandbox used for
preparation has no Docker executable; no real provisioning was executed there.

Supported methods: apiinfo.version; user.login/logout; host.get, trigger.get,
hostgroup.get, role.get; mediatype.get/create/update; usergroup.get/create/update;
user.get/create/update; action.get/create/update. The script requires API 7.0.31,
pilot enabled/OK/severity 3, expected host-group membership and existing User role.
It never creates/updates hosts, triggers, roles or host groups. Payload strings are
checked against this document before any writes.

Exact-name queries precede writes and are repeated before create/update. Multiple
matches and unrelated name collisions stop execution. Matching objects are no-ops;
managed drift is updated in place. Additional media templates, recipient groups,
other recipient media and additional existing group rights are preserved. Only the
two pilot message templates, one GIOP media entry, pilot group settings and the
pilot Action settings are managed. An existing differently scoped Action or one
with unrelated operations is rejected instead of overwritten. A local mutex prevents
overlapping runs on the same operator machine. Run from one operator machine;
there is no distributed provisioning lock. Each write is read back; failures are
not retried automatically. If a run fails after partial success, inspect and rerun:
name searches reuse already-created objects. Never delete them to force a rerun.

Read-only inspection on 2026-10-05 confirmed live API 7.0.31, pilot trigger OK,
host group 22 and User role 1. Named GIOP media/group/user/action were absent.
Live `-WhatIf` passed and planned four creates. Offline mocked tests passed for
first creation, unchanged rerun, drift update, preservation, duplicate rejection
and nonpilot collision rejection. Those preparation checks did not prove real writes; subsequent operator
provisioning and unchanged rerun are confirmed above.
The 7.0.31 [Media Type implementation](https://raw.githubusercontent.com/zabbix/zabbix/7.0.31/ui/include/classes/api/services/CMediatype.php)
and [Action API](https://www.zabbix.com/documentation/7.0/en/manual/api/reference/action/object)
were consulted for the writable contract; Zabbix provides JSON-RPC methods rather
than a live OpenAPI schema.

## UI reference (equivalent settings; do not create a second copy)

Use http://localhost:8080 to inspect the provisioned settings. The following manual
steps remain as a fallback/reference. Do not repeat them after successful API setup.
If an exact-name object already exists, inspect/edit it rather than creating another.

### 1. Media type

**Alerts > Media types > Create media type**:

| Field | Value |
| --- | --- |
| Name | GIOP LAB |
| Type | Script |
| Script name | giop-alert.sh |
| Script parameters | exactly ONE row: `{ALERT.MESSAGE}` |
| Enabled | checked |
| Options > Concurrent sessions | One |
| Options > Attempts | 1 |
| Options > Attempt interval | 10s (unused with one attempt) |

On **Message templates**, add **Problem** with subject `GIOP LAB PROBLEM` and the
PROBLEM JSON below; add **Problem recovery** with subject `GIOP LAB RECOVERY` and
the Recovery JSON below. Save. These templates are mandatory even when action
custom messages are used. [Zabbix media type settings](https://www.zabbix.com/documentation/7.0/en/manual/config/notifications/media).

PROBLEM message, one line:

```json
{"kind":"PROBLEM","event_id":"{EVENT.ID}","host_id":"10683","trigger_id":"25228","host":"GUA-LAB-SRV-WEB-001","trigger":"GIOP-LAB: controlled web workload TCP unavailable","severity":{EVENT.NSEVERITY},"event_time":"{EVENT.DATE}T{EVENT.TIME}-03:00"}
```

Recovery message, one line:

```json
{"kind":"RECOVERY","event_id":"{EVENT.RECOVERY.ID}","problem_event_id":"{EVENT.ID}","host_id":"10683","trigger_id":"25228","host":"GUA-LAB-SRV-WEB-001","trigger":"GIOP-LAB: controlled web workload TCP unavailable","severity":{EVENT.NSEVERITY},"event_time":"{EVENT.RECOVERY.DATE}T{EVENT.RECOVERY.TIME}-03:00"}
```

`EVENT.TIMESTAMP` and `EVENT.RECOVERY.TIMESTAMP` must NOT be used for this Zabbix
7.0 setup. These templates use the supported 7.0 ID, numeric severity, DATE and
TIME macros. [Zabbix 7.0 supported macros](https://www.zabbix.com/documentation/7.0/en/manual/appendix/macros/supported_by_location).

| FastAPI field | PROBLEM source | Recovery source |
| --- | --- | --- |
| kind | literal PROBLEM | literal RECOVERY |
| event_id | EVENT.ID | EVENT.RECOVERY.ID |
| problem_event_id | omitted | EVENT.ID (original Problem) |
| host_id / trigger_id | fixed 10683 / 25228 | same fixed pilot IDs |
| host | fixed canonical GUA-LAB-SRV-WEB-001 | same |
| trigger | fixed exact pilot trigger name | same |
| severity | EVENT.NSEVERITY, unquoted integer | same original event severity |
| event_time | EVENT.DATE + EVENT.TIME | EVENT.RECOVERY.DATE + EVENT.RECOVERY.TIME |

Fixed identity strings deliberately avoid the technical host name
`GUA-LAB-AGENT-001` and visible suffix `synthetic monitor`, neither of which matches
the canonical integration allowlist name. Only this pilot Action may use this media.
The timestamp offset is deliberately the LAB's America/Sao_Paulo `-03:00`.
Keep Zabbix frontend default timezone and notification user's timezone set to
**America/Sao_Paulo**; do not reuse the templates in another timezone.
The script changes only `yyyy.mm.ddT` to `yyyy-mm-ddT` in event_time.
Recovery event reference semantics are documented in [Zabbix recovery operations](https://www.zabbix.com/documentation/7.0/en/manual/config/notifications/action/recovery_operations).

### 2. Local delivery user

**Users > User groups**: create `GIOP LAB Notifications` if absent. In **Host
permissions**, add host group `GIOP-LAB Targets` with **Read** permission. Keep
frontend access **Disabled** if this account is used only for notifications.

**Users > Users > Create user**: username `giop-lab-notifications`, member of that
group, user role **User**, timezone **America/Sao_Paulo**. If a password is required,
generate it locally and retain it only in ignored local configuration; no shared
webhook secret goes into the user password. On **Media > Add**:

| Field | Value |
| --- | --- |
| Type | GIOP LAB |
| Send to | giop-lab (non-secret required placeholder; script does not use it) |
| When active | 1-7,00:00-24:00 |
| Use if severity | Average only (pilot severity 3) |
| Status | Enabled |

Save. An existing LAB notification user with the same host Read permission and
timezone can be reused; keep exactly one matching enabled GIOP LAB media entry.

### 3. Pilot Action

**Alerts > Actions > Trigger actions > Create action**:

| Field | Value |
| --- | --- |
| Name | GIOP-LAB - Pilot Event to Incident |
| Enabled | checked |
| Conditions > Host equals | GUA-LAB-SRV-WEB-001 synthetic monitor (hostid 10683) |
| Conditions > Trigger equals | GIOP-LAB: controlled web workload TCP unavailable (triggerid 25228) |
| Type of calculation | And (both conditions required) |

Confirm IDs in Data collection > Hosts / Triggers before selecting them. Leave
pause-for-suppressed-problems enabled; run the demo outside maintenance. Do not add
generic severity or host-group conditions as alternatives to this exact trigger.

**Operations > Add**: operation **Send message**, steps **1–1**, send to users
**giop-lab-notifications** (or the single selected existing user), send to media
type **GIOP LAB**. Leave **Custom message** unchecked so the Problem media template
is used. Add no operation conditions. Keep just this one operation; no escalation,
remote command or repeated notification. Default operation-step duration can remain
1h: step 1 sends immediately and step 1–1 prevents another scheduled step.

**Recovery operations > Add**: operation **Send message**, send to the same user,
send to media type **GIOP LAB**, Custom message unchecked. Keep exactly one Recovery
operation. **Update operations**: empty. Save the Action. Check that no second
pilot GIOP Action sends the same event. Failed delivery is visible in the Action log;
one attempt intentionally avoids retry notifications for this MVP.

Do not use the Media type Test button with a pilot fixture in live mode. Event
macros have no event context there; use the harmless health test below instead.

## Harmless connectivity proof

```powershell
docker exec gua-lab-zabbix-server-001 curl --silent --show-error --fail --max-time 10 http://integration:8090/health
```

Observed response: `status=ok`, `mode=live`, `database=ok`, GLPI reachability
`not_checked`. This GET creates no Incident. Also verified script executable and
config readable as the container's `zabbix` user. A separate nonpilot delivery with
cleared environment returned 202 ignored, proving the scoped-file authentication
path without a ticket. This is connectivity/script evidence, not an automatic-demo pass.

## Final automatic end-to-end demonstration

No `Send-GiopSyntheticProblem.ps1` or `Send-GiopSyntheticRecovery.ps1` in this demo.
Use a fresh real Zabbix event, not a previously persisted manual test ID.

1. Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-GiopIntegrationHealth.ps1 -State`;
   confirm mode live and record existing episodes/tickets as baseline.
2. Verify healthy workload:
   `docker exec gua-lab-srv-web-001 wget -q -O - http://127.0.0.1/healthz`.
   In **Monitoring > Latest data**, select pilot host and check **Synthetic web
   workload TCP reachability = 1**. In **Data collection > Hosts > Triggers**, pilot
   trigger 25228 must be enabled and **OK**. No unrelated problem needs changing.
3. Stop only workload:
   `docker compose --env-file .env -f docker/docker-compose.yml stop web-workload`.
4. Wait for **Monitoring > Problems** to show the exact pilot Problem; record its
   real event ID. The existing item checks every 15s; allow polling/config-cache time.
5. In **Reports > Action log**, filter the GIOP Action/media/user and confirm one
   Problem notification **Sent**. The script marks success only for HTTP 202.
6. Run the health/state script again. Find that exact event_id with
   **PROBLEM_OPEN** and a populated glpi_ticket_id. This proves automatic reception.
7. In GLPI **Assistance > Tickets**, open that ID; confirm exactly one type Incident,
   title `GIOP-LAB Zabbix synthetic event <event_id>`, synthetic marker and Computer
   1/entity 0 mapping. Search the title/marker to confirm one matching ticket.
8. Restore only workload:
   `docker compose --env-file .env -f docker/docker-compose.yml start web-workload`.
9. Wait for pilot item to return 1 and Problem to resolve; record the distinct
   Recovery event ID. In Reports > Action log confirm one Recovery notification Sent.
10. Refresh the same GLPI ticket. Confirm exactly one public follow-up with the
    recovery ID, timestamp, duration, monitored host and original event reference.
11. Run health/state again: same ticket ID, recovery_event_id populated, status
    **RECOVERED_PENDING_OPERATOR_VALIDATION**.
12. Verify the GLPI ticket remains open (neither Solved nor Closed), with no automatic
    assignment/remediation. Operator validates and handles final closure manually.

If delivery fails, restore workload with step 8, inspect Action log and preserved
integration state, then correct setup before repeating with a new actual outage.
Do not delete SQLite state or create a fake recovery. Automatic-demo acceptance is operator-confirmed as recorded above; local commit
and tag are authorized. Do not push or begin Phase 4.
