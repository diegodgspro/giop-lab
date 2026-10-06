# GIOP-LAB roadmap

All LAB data is synthetic. Source-document municipal context is separate from the
demonstration environment and is not a dashboard data source.

| Stage | State | Portfolio capability |
| --- | --- | --- |
| v0.1 / Phase 1 | COMPLETE | Observability: synthetic workload detection / Recovery |
| v0.2 / Phase 2 | COMPLETE | ITSM / CMDB: GLPI synthetic seed and agent inventory |
| v0.3 / Phase 3 | COMPLETE AND FROZEN | Automated event-to-Incident workflow, persistent deduplication, Recovery follow-up and human validation |
| v0.4 / Phase 4 | MVP IMPLEMENTED, LOCALLY VALIDATED; UNCOMMITTED | N3 Control Center: current API data, correlation, source status and inventory |

Phase 4 branches from `giop-lab-v0.3.0` at
`ef0299027098dc95fb519ad0a1cbed2f440df902`. No Phase 4 commit, push or tag is authorized.
One additional stateless presentation service joins application networks only.
It does not modify Zabbix, GLPI, CMDB or Integration persistence.

Phase 3A architecture and test-matrix documents remain historical future-hardening
proposals. Complete API response reconciliation, exhaustive pagination hardening,
native Ticket-CI relations, least-privilege audit, TLS outside LAB, HA, event-burst
validation, timezone normalization and production Entity/topology mapping remain
Post-MVP debt. Phase 4 bounded read scans do not certify production pagination.

Ansible, remote desktop, remediation, AI/RAG/Ollama, Grafana, NetBox, advanced
topology, authentication portal and production deployment remain outside this MVP.
Evidence: PROJECT_STATE.md. Demo: docs/demo/phase4-control-center.md.
