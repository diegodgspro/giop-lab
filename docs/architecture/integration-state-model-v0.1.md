# Integration state model v0.1

Design only. No runtime service, SQLite DB or volume created. One service instance, receiver and processor functions together; SQLite persistent Docker volume is proportional LAB storage. No broker or additional database.

## Persistent records

| Record | Minimum data and constraints |
| --- | --- |
| received_event | unique instance + stable operation ID/type + episode; sanitized payload/hash, source/receipt UTC, eligibility, validation result |
| episode | unique instance + PROBLEM event ID, recovery ID/cause, immutable CI mapping snapshot, service/trigger, grouping window, local lifecycle, policy/mapping/schema versions |
| operation | unique episode + operation type + stable event/update identifier, intended action/body hash, state, external marker, ticket/follow-up ID, attempts, lease, next retry UTC |
| attempt | operation, start/end UTC, transport outcome, HTTP result, sanitized error class, no token/header/body secrets |
| reconciliation | operation, ambiguous result, searches/pages, candidates, evidence, resolution and operator decision UTC |
| mapping/policy | approved immutable versions, entity and matrix/scope approval evidence |

All timestamps UTC with source and receipt times distinct. IDs stored as strings where platform numeric range may exceed safe language precision. Foreign keys and unique indexes enforce deduplication, not in-memory locks alone. BEGIN IMMEDIATE/transactional upsert serializes concurrent inserts. WAL and bounded busy timeout; integrity/foreign-key checks. Persist event and operation before acknowledge; if storage unavailable return retryable failure and perform no GLPI action. Receiver authentication and schema validation precede durable acceptance. Use short DB transactions; never hold one across network I/O.

Processor claims one pending operation transactionally, persists intent before HTTP. Single instance/single writer plus durable claim fencing prevents parallel sends. After crash, any previously SENDING operation becomes OUTCOME_UNKNOWN and reconciles, never resets to a fresh POST. SQLite transaction and GLPI HTTP cannot be atomic; exactly-once delivery is not claimed.

## State and deduplication

Episode states include OPEN, RECOVERY_ORPHAN, RECOVERED_PENDING_OPERATOR_VALIDATION, QUARANTINED. Operation states include RECEIVED, INELIGIBLE, WAITING_MAPPING, WAITING_IMPACT, DRY_RUN_DECIDED, INTENT_PERSISTED, SENDING, CONFIRMED, OUTCOME_UNKNOWN, RECONCILING, WAITING_OPERATOR, RETRY_WAIT, FAILED_POLICY.

Sequential/concurrent repeat of same operation returns existing decision, no second ticket/follow-up. Relevant update belongs to same episode/ticket. A new PROBLEM event ID is a new episode even within the grouping window. Different triggers or multiple CIs are never automatically merged. Dry-run completion does not become a write instruction when mode changes: replay requires explicit approved plan, keeping original event/decision audit.

Recovery first persists RECOVERY_ORPHAN indexed by original PROBLEM ID; retain it for later correlation. Delayed PROBLEM joins original episode and preserves recovered evidence. Do not create a stale ticket just because delivery is reordered; require operator decision for already-recovered incidents. No recovery linkage -> quarantine, no guessed lookup by name/time.

## Ambiguous writes and retries

Ticket marker: giop:v1:<instance UID>:problem:<PROBLEM ID>. Persist intent/marker and deterministic request snapshot before POST. Response 201 binds ID after read-back verification. Lost response/timeout/5xx after send is ambiguous; reconcile exact external_id via all relevant entity-scoped pages. One verified match binds; multiple matches quarantine; zero matches does not prove non-creation. Retry only on provably unsent request or operator-certified safe outcome. No blind POST retry.

Follow-up operation marker includes episode, operation type and stable source identifier in sanitized content. Search all follow-up pages, exact local marker comparison. Missing result after ambiguous send remains uncertain; operator review rather than duplicate follow-up.

401: refresh once for a demonstrably rejected request, otherwise reconcile; 403: stop and request rights review; 429: honor Retry-After/bounded exponential jitter, reconciling any uncertain write first. GET 5xx can retry boundedly; POST/PATCH 5xx may have committed, so reconcile before retry. Limit attempts and queue/backoff; alert operator instead of storm.

Manual GLPI closure never triggers reopen. Recovery records evidence/local recovered state; a supported follow-up may be proposed without status mutation. Manual Zabbix closure is distinct from measured recovery and requires validation.

## Restore

Use consistent SQLite backup API/checkpoint or stopped-service backup, not raw live WAL-file copying. Preserve DB, policy/mapping versions and instance UIDs. Restore single instance, integrity-check, dry-run first and reconcile all SENDING/unknown intents against GLPI before any writes. Retention cannot delete dedup keys/markers while source redelivery remains possible; archive safely with operator-approved horizon. Disk-full/corruption fails closed.
