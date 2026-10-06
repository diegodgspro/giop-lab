# Zabbix to GLPI integration contract v0.1

Phase 3A: DESIGN / CONTRACT VALIDATION. Automatic writes: NOT ENABLED.
Baseline: giop-lab-v0.2.0, commit c364e10e4182b7afd09aafafd8dc44f0eba858ea. Evidence collected 2026-10-02 from running LAB, without DB access or business writes. Authentication token requests were the only API POSTs.

## Boundary and release gates

Zabbix -> one small integration service (receiver and processor functions together) -> GLPI High-Level API. The same service owns SQLite on a persistent Docker volume. One service instance only. No direct Zabbix or GLPI database access, brokers, new platforms or remediation. This is a design, not a container or executable implementation.

First implementation must use GIOP_INTEGRATION_MODE=dry-run. Authenticate, validate, map CI, evaluate eligibility, map severity, decide deduplication, persist operation and log intended action; never create tickets or follow-ups. Unknown mode fails closed. A future write mode requires separate explicit authorization and acceptance of all unresolved gates.

## Exact Zabbix runtime evidence

Server, Web and Agent 2 are all 7.0.31. Server and Agent revision e7da53e dated 22 September 2026. Server binary and Agent binary --version, and Web include/defines.inc.php independently confirmed versions. Repository tags remain floating; do not infer patch versions from tags.

| Component | Compose image | Observed RepoDigest |
| --- | --- | --- |
| Server | zabbix/zabbix-server-pgsql:alpine-7.0-latest | zabbix/zabbix-server-pgsql@sha256:415452211dea59cd4ea3346f2c2b38403660408273c672ebf91603353ce1073f |
| Web | zabbix/zabbix-web-nginx-pgsql:alpine-7.0-latest | zabbix/zabbix-web-nginx-pgsql@sha256:cd216a9968b62eb6fddd789872b9e8eb4d064539ef40b6356dd2d8c1588a3f91 |
| Agent 2 | zabbix/zabbix-agent2:alpine-7.0-latest | zabbix/zabbix-agent2@sha256:ba55e6d146d0f0bc550da82b29b22134655db6e31d2c9eae9b1d15f659ad86cd |

Docker image IDs matched the digest suffixes above. No images were pulled or changed. Reverify versions/digests after any pull before selecting media type JavaScript, macros, API semantics or recovery operations. Macro substitution and action delivery have NOT been configured/tested. Payload requires original PROBLEM event ID, recovery event ID and stable update identifier; never assume a recovery ID is the PROBLEM ID.

## Old default-host problem: confirmed cause and proposed operator correction

Read-only host.get: Zabbix server hostid 10084, enabled, templates Linux by Zabbix agent (10001) and Zabbix server health (10047), Agent interface 1, IP connection 127.0.0.1:10050. agent.ping and agent.version are passive type 0 items. Inherited trigger 22391, template trigger 22377, Linux: Zabbix agent is not available, value 1. The displayed for-3m problem is the template availability condition.

A read-only zabbix_get from the Server container to 127.0.0.1:10050 failed to connect. The Compose Server container has no configured agent. Agent 2 container has ZBX_HOSTNAME=GUA-LAB-AGENT-001 and server=zabbix-server. Its actual monitored host is 10683, display GUA-LAB-SRV-WEB-001 synthetic monitor, DNS interface zabbix-agent2:10050, no linked templates. It monitors the workload, not the default Server OS. The repository bootstrap only provisions that synthetic host; it never corrects default host 10084. Thus the default Linux template/interface is an inapplicable inherited/default initialization artifact, not a workload failure.

Recommended smallest correction: remove only the inapplicable Linux template linkage/items from default host, retain Zabbix server health. Do NOT point default host to Agent 2: that would mislabel the Agent container OS as the Server OS. If OS monitoring of Server is wanted later, design an agent representing that namespace explicitly.

Manual steps, not executed:
1. In Zabbix 7.0 open Data collection > Hosts; filter exact host Zabbix server, confirm ID 10084.
2. Open Templates and verify both links/IDs above; record only synthetic before evidence.
3. Use Unlink and clear for Linux by Zabbix agent ONLY, keeping Zabbix server health. Plain Unlink retains inherited items and does not remove the invalid checks. Review the removal preview before Update.
4. Save; confirm health template remains and passive Linux items are removed. Do not acknowledge/close the Problem to pretend recovery. Record any historical event effect as configuration removal, not measured recovery.
5. Confirm host 10683 and trigger 25228 are unchanged, then rerun the controlled workload regression when authorized. Rollback is relinking the original Linux template; its invalid-agent warning will recur unless the architecture changes.

No UI change has been made. Operator decision/execution remains unresolved; no automatic commit.

## Live GLPI contract

GLPI CLI reports 11.0.9. Live Swagger /api.php/doc points to /api.php/v2.3.0/doc.json (API version 2.3.0, not GLPI product version). Canonical JSON SHA-256: 4afdd4270d74dd2c1b5fec5bc212665326e2c1e28c1394a49c6f3d7c32ccd580. Schema fetched unauthenticated; business GETs used existing local CLI credentials only. No credentials/schema runtime dump committed.

| Contract | Supported route, relative to /api.php/v2.3.0 | Evidence and boundary |
| --- | --- | --- |
| Search/list | GET /Assistance/Ticket | filter RSQL; start/limit/sort. GET limit=1 returned 206; handle 200 and 206 with pagination |
| Read | GET /Assistance/Ticket/{id} | GET Ticket 1 returned 200, New, Root entity 0. Positive RSQL name==LAB-INCIDENT-001 returned exactly ID 1; collection and follow-up also checked in 3A |
| Create | POST /Assistance/Ticket | Schema 201, id/href and Location response; Ticket body. No 3A POST performed |
| Update | PATCH /Assistance/Ticket/{id} | Schema 200 Ticket; no 3A PATCH performed |
| Follow-up list/create | GET/POST /Assistance/Ticket/{id}/Timeline/Followup | GET Ticket 1 returned 200 empty list; POST schema 201, Followup body; not write-tested |
| Follow-up read | GET /Assistance/Ticket/{id}/Timeline/Followup/{subitem_id} | Schema supported; no existing follow-up ID available for positive read |
| Timeline | GET /Assistance/Ticket/{id}/Timeline | Schema supported, future reconciliation fallback |
| CI read | GET /Assets/Computer/{id}; GET /Assets/NetworkEquipment/{id} | Computer 1 returned 200, Root entity 0; network permission must be checked with dedicated identity |

All relevant routes require OAuth scope api. Entity/Profile headers exist; use fixed approved GLPI-Entity and GLPI-Profile, GLPI-Entity-Recursive=false. Scope api does not grant profile rights or user-scope identity confirmation.

Ticket writable schema includes name, content (HTML), external_id, type (1 Incident/2 Request), urgency/impact/priority 1..5. Create has no schema required list: that does NOT prove business/template defaults permit an arbitrary minimal body. Proposed later body includes type=1, immutable external_id, sanitized title/content, confirmed urgency/impact; priority is matrix-derived and must be checked against GLPI configuration. Do not write historical dates or entity objects; fixed header determines entity.

Status IDs: 1 New, 10 Approval, 2 Processing assigned, 3 Processing planned, 4 Pending, 5 Solved, 6 Closed. Crucially status.id is readOnly in this live schema. Phase 2 seed successfully changed statuses but that does not establish a supported lifecycle write contract for this identity. No automatic transition is needed initially: create with authorized defaults; preserve status thereafter. Status PATCH, solution/closure and reopen remain prohibited/unvalidated. Profile lifecycle matrix must deny them. Solution routes exist but are outside integration allowlist.

No Ticket-Computer/NetworkEquipment/item association route or writable asset collection was found in the complete live Ticket paths/schema or reverse asset paths. Asset statistics are GET reports, not association writes. Preserve logical SQLite/manifest CI mapping; do not use MySQL or legacy API workaround.

## Stable marker and ambiguous outcomes

Use native Ticket.external_id = giop:v1:<zabbix_instance_uid>:problem:<problem_event_id>. Schema field is writable string and search uses filter=external_id==<marker>, URL-encoded. Actual GET filter=external_id==GIOP3A-NONEXISTENT-CONTRACT-MARKER returned 200 and zero records. This confirms parser/filter acceptance, not uniqueness or positive matching after creation. Positive marker persistence/exact search under dedicated rights remains a write-gate test; do not create a test ticket now.

Paginate within fixed entity, compare exact external_id locally and verify CI snapshot/context. No server uniqueness/idempotency guarantee is declared. One match binds existing ID; multiple matches quarantine; zero matches after ambiguous POST is NOT proof safe to retry. Persist intent before send. Reconcile repeated bounded reads and eventual processing; retry create only if transport proves not sent or operator proves absence/outcome safe. Otherwise suspend for human resolution, never blindly POST again.

For follow-ups embed a stable operation marker in sanitized content. Reconcile GET collection/all pages and exact marker comparison. No native follow-up external_id/idempotency guarantee; if evidence remains uncertain, suspend rather than duplicate. Do not edit original ticket content/name to overwrite a human change.

## Severity and recovery policy

Proposed urgency: Zabbix 0 Not classified -> human review, 1 Information -> 1, 2 Warning -> 2, 3 Average -> 3, 4 High -> 4, 5 Disaster -> 5. Disaster is urgency only, not municipal criticality. Pilot trigger priority is 3. Impact is independent confirmed scope: 1 isolated synthetic service; 2 several LAB users/endpoints; 3 several LAB services; 4 broad LAB operation; 5 entire LAB operation. Unknown scope blocks future ticket creation pending human validation. Pilot proposed impact 1 requires operator confirmation.

Priority = approved GLPI urgency x impact matrix. Retrieve/confirm configured matrix with operator; no numeric priority is guessed and no configuration changed. Dry-run logs unresolved priority until matrix approved.

Recovery persists evidence, updates local state RECOVERED_PENDING_OPERATOR_VALIDATION and proposes one follow-up if supported/authorized. Never solve, close or reopen manually closed tickets. A manually closed Zabbix event is not proof of service restoration: record cause/manual closure distinctly and require operator validation. Follow-up to a closed GLPI ticket must not reopen it; if unsupported/denied, retain local evidence and queue operator review.

References: live local OpenAPI is authoritative for these operations. Official explanatory sources: https://help.glpi-project.org/documentation/modules/configuration/general/api/restful-api-v2 ; https://help.glpi-project.org/documentation/modules/administration/profiles/profiles ; https://www.zabbix.com/documentation/7.0/en/manual/quickstart/monitor_linux .
