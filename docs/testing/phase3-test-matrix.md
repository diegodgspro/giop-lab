# Phase 3 test matrix

Historical Phase 3A planning artifact: the automatic Phase 3 MVP is now operator-validated.
See PROJECT_STATE.md and docs/demo/phase3-mvp-demo.md for current evidence and scope.
The exhaustive gates below are deferred Post-MVP proposals.

DESIGN ONLY. Tests are not executed integration results. No receiver/service/DB exists. Initial implementation dry-run must prove zero GLPI mutations using outbound allowlist/spy and before/after counts. Ambiguous-write tests use a simulator first; real mutation tests require later explicit authorization. Store secret-free operation, state, HTTP and decision evidence for each row, with UTC and policy/mapping versions.

| Case | Expected acceptance criterion |
| --- | --- |
| Normal PROBLEM | Eligible mapped event persisted; one dry-run create intent; zero GLPI writes |
| Normal Recovery | Original episode matched; RECOVERED_PENDING_OPERATOR_VALIDATION; proposed follow-up, no status change |
| Sequential resend | Same durable operation and decision; no second intent/ticket |
| Concurrent resend | Unique constraint/transaction wins once; all callers reuse same operation |
| Restart before processing | Durable received event survives; resume decision; never lose accepted event |
| GLPI unavailable | Persist pending/retry evidence; bounded backoff; dry-run no write dependency |
| Ticket created, response lost | Future fault-injected write test only: reconcile external_id; no blind POST; uncertain zero results wait for operator |
| Follow-up accepted, response lost | Future fault-injected write test only: reconcile operation marker; no duplicate follow-up |
| OAuth 401 | Rejected request refresh once; otherwise reconcile uncertain result; secrets absent from logs |
| Authorization 403 | Stop operation for rights review; no privilege expansion |
| HTTP 429 | Respect Retry-After and bounded jitter; reconcile uncertain writes first |
| HTTP 5xx | Bounded GET retry; uncertain mutation reconciled, never blind POST |
| Recovery before PROBLEM | Durable orphan keyed by original PROBLEM ID; no guessed CI/ticket |
| Delayed PROBLEM after Recovery | Join original episode; preserve recovered state; no stale automatic ticket |
| Unknown CI | Quarantine; no ticket or auto-created asset |
| Duplicate CI mapping | Reject ambiguous active mappings; no arbitrary first match |
| Wrong GLPI entity | Fail closed on read-back/header mismatch; no cross-entity action |
| Flapping | Distinct PROBLEM IDs remain distinct episodes; group advisory only; rate control |
| Event burst | Bounded queue/rate, durable rejection/retry; Recovery not silently lost |
| Manually closed GLPI Ticket | No reopen/solve/close; recovery local evidence, follow-up only if supported without reopen |
| Manually closed Zabbix event | Mark manual closure distinctly; never claim measured service recovery |
| Invalid webhook payload | Reject schema/type/size/URL/unknown instance; no outbound action |
| Unauthenticated webhook | Reject before durable business processing; no secrets in log |
| Storage unavailable | 503 before acknowledge; no GLPI action, no accepted event loss |
| Persistence restore | Consistent backup, integrity checks, original UIDs; dry-run and reconciliation before writes |
| Phase 1 regression | Controlled outage and natural recovery; trigger/host unchanged; lab.web.status returns 1 |
| Phase 2 regression | GLPI/schema/API read healthy; seed 41/127/51/93; inventory ID182 distinct/persistent |
| External marker positive/negative | Future authorized fixture: exact external_id roundtrip, paging, zero/one/multiple candidates; filter acceptance alone insufficient |
| Dedicated identity restrictions | Own ticket search/read, follow-up visibility; denied unrelated entity/assets/admin/state mutation |
| GLPI lifecycle schema conflict | No status PATCH until supported contract/profile matrix reconciled; no unauthorized transition |
| Priority matrix/unknown impact | Human-approved scope and configured matrix required; unknown impact blocks writes |
| Mode change | Unknown mode fails closed; dry-run history never automatically replayed into writes |
| Version/instance drift | Digest/schema/mapping mismatch disables write gate and requires revalidation |

Read-only 3A evidence is in zabbix-glpi-integration-v0.1.md. Operator runtime Phase 1/2 evidence remains in PROJECT_STATE.md. No tests here may fabricate recovery or native Ticket-CI association.
