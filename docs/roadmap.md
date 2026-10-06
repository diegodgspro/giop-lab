# GIOP-LAB roadmap

Historical Phase 3A planning artifact: the automatic Phase 3 MVP is now operator-validated.
See PROJECT_STATE.md and docs/demo/phase3-mvp-demo.md for current evidence and scope.
The exhaustive gates below are deferred Post-MVP proposals.

| Stage | Status | Boundary |
| --- | --- | --- |
| Phase 1 observability | COMPLETE | Controlled workload outage/recovery PASS |
| Phase 2 ITSM/CMDB/inventory | COMPLETE | giop-lab-v0.2.0 immutable baseline |
| Phase 3A | DESIGN / CONTRACT VALIDATION | Documents and read-only live investigation only |
| Phase 3 initial implementation | NOT STARTED | Must begin dry-run, separately authorized |
| Phase 3 automatic writes | NOT ENABLED | Dedicated rights, marker reconciliation and all acceptance gates required |

Preparation gates: operator default-host correction decision; approve pilot CI/instance UIDs, root-entity scope and confirmed impact/priority matrix; dedicated identity/profile/OAuth grant configuration; positive marker and follow-up reconciliation tests; resolve live status readOnly discrepancy before any lifecycle expansion. No automatic commit with unresolved manual decisions.

Planned boundary: Zabbix -> one integration service -> GLPI High-Level API, same-service receiver/processor and SQLite persistent volume. CI/severity mapping, durable deduplication, correlation, Recovery evidence, auditability and ticket-storm prevention. No autonomous remediation or additional platform.

Recovery initially stays RECOVERED_PENDING_OPERATOR_VALIDATION with optional authorized follow-up, never auto-solve/close/reopen. First dry-run implementation must prove zero GLPI writes. Test design: docs/testing/phase3-test-matrix.md. Current evidence and resume context: PROJECT_STATE.md.
