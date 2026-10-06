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
| v0.6 / Phase 6 | COMPLETE, LOCALLY VALIDATED: giop-lab-v0.6.0 | Read-only AI assistance: sanitized evidence, structured inference, known runbooks and human decision |

Phase 5 branches from `giop-lab-v0.4.0` at
`42e3cbab9758624dfe3be42459f6931ae3519197`. Phase 5 is finalized with a local commit
and annotated `giop-lab-v0.5.0` tag. Phase 6 branches from that tag at
`385ef17cca4abdbd38e3e3aa24bcbfef2c12ff3a`; finalized with local commit and annotated giop-lab-v0.6.0 tag, no push.
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

Ansible, remote desktop, automatic/generic remediation, RAG, autonomous AI, Grafana, NetBox, advanced
topology, authentication portal and production deployment remain outside this MVP.
Evidence: PROJECT_STATE.md. Demos: docs/demo/phase4-control-center.md and docs/demo/phase5-operational-runbooks.md.

Phase 6 adds one optional AI Assistant service and explicit analysis in Control Center.
Fixture validation is disclosed; real local Ollama remains optional and now passed
with operator-installed Ollama 0.35.1 / llama3.2:3b.
No model installation, tools, automatic actions or database. See
[Phase 6 demo](demo/phase6-ai-incident-analysis.md) and
[trust boundary](architecture/ai-incident-analysis-v0.1.md).


Structured validity does not guarantee diagnostic correctness. Real llama3.2:3b
inference passed strict schema validation without output repair, but was not fully
operationally accurate: historical workload state was supplied and partly reported
as UNKNOWN. It recommended RB-OPS-001 (Service Health Check), not RB-OPS-003.
Model confidence values (40% overall, 60% inferred cause) are not calibrated
probabilities. AI output is advisory; operator review and human decision remain
authoritative. One injection-oriented check is not a general security guarantee.
