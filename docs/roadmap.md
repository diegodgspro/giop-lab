# GIOP-LAB roadmap

All LAB data is synthetic. Source-document municipal context is separate from the
demonstration environment and is not a dashboard data source.

| Stage | State | Portfolio capability |
| --- | --- | --- |
| v0.1 / Phase 1 | COMPLETE | Observability: synthetic workload detection / Recovery |
| v0.2 / Phase 2 | COMPLETE | ITSM / CMDB: GLPI synthetic seed and agent inventory |
| v0.3 / Phase 3 | COMPLETE AND FROZEN | Automated event-to-Incident workflow, persistent deduplication, Recovery follow-up and human validation |
| v0.4 / Phase 4 | COMPLETE AND FROZEN: giop-lab-v0.4.0 | N3 Control Center: current API data, correlation, source status and inventory |
| v0.5 / Phase 5 | COMPLETE, LOCALLY VALIDATED: giop-lab-v0.5.0 | Operator-local runbooks: diagnose, evidence, explicit approval, fixed LAB recovery, validation and audit |

Phase 5 branches from `giop-lab-v0.4.0` at
`42e3cbab9758624dfe3be42459f6931ae3519197`. Phase 5 is finalized with a local commit
and annotated `giop-lab-v0.5.0` tag. No push or Phase 6 is authorized.
One additional stateless presentation service joins application networks only.
It does not modify Zabbix, GLPI, CMDB or Integration persistence.

Phase 3A architecture and test-matrix documents remain historical future-hardening
proposals. Complete API response reconciliation, exhaustive pagination hardening,
native Ticket-CI relations, least-privilege audit, TLS outside LAB, HA, event-burst
validation, timezone normalization and production Entity/topology mapping remain
Post-MVP debt. Phase 4 bounded read scans do not certify production pagination.

Phase 5 permits only explicitly invoked local restoration of the approved synthetic
web-workload; default mode is plan only. `/runbooks` is a read-only catalog.
Actual evidence: Problem 41 → Ticket 97 → Recovery 42 → Follow-up 4.
Monitoring alone is not operations: evidence and human governance connect diagnosis
to a controlled response. This is not autonomous remediation or production readiness.

Ansible, remote desktop, automatic/generic remediation, AI/RAG/Ollama, Grafana, NetBox, advanced
topology, authentication portal and production deployment remain outside this MVP.
Evidence: PROJECT_STATE.md. Demos: docs/demo/phase4-control-center.md and docs/demo/phase5-operational-runbooks.md.
