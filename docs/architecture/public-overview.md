# GIOP architecture and engineering decisions

All components, assets and operational records demonstrated here are SYNTHETIC LAB.
Municipal production topology is not represented. The [README diagram](../../README.md#architecture)
is the current high-level view; older phase documents are historical snapshots.

## Ownership and boundaries

| Component | Owns | Deliberate boundary |
| --- | --- | --- |
| Zabbix | Observability, Problem and Recovery detection | Monitoring does not invoke remediation |
| GLPI | ITSM / CMDB, Incident and follow-up records | Recovery never automatically solves/closes the Ticket |
| Integration | Event translation, CI mapping, correlation, deduplication | Only approved pilot events; application APIs, no upstream DB access |
| SQLite | Persistent Integration episodes and operation state | Proportional single-instance LAB storage, not an HA architecture |
| Control Center | Source aggregation, operator visibility, analysis proxy | Read-only source access and catalog; no command console |
| PowerShell runbooks | Operator-local diagnostics and constrained recovery | Only RB-OPS-003 writes; exact workload, explicit -Execute |
| AI Assistant / Ollama | Structured advisory analysis | Sanitized context only; no tools, credentials or infrastructure actions |
| Human operator | Approval, evidence review and final validation | Authoritative decision; manual Ticket closure |

Zabbix's scoped script webhook sends Problem/Recovery events to Integration.
Integration persists correlation in its own SQLite volume and performs supported
GLPI API writes. It never joins the Zabbix/GLPI database networks. Credentials stay
server-side. Control Center reads current API state rather than inventing dashboard
totals. Computers exclude logical deletions; the historical collection had 182
objects including 54 recycle-bin records, versus 128 active Computers.

RB-OPS-001 checks platform/pilot health without changes. RB-OPS-002 creates sanitized
local evidence. RB-OPS-003 checks repository, Compose and frozen pilot identities;
its plan is the default. Explicit operator execution can only start/restart
`web-workload` / `gua-lab-srv-web-001`. Post-action evidence arrives through the
existing Zabbix → Integration → GLPI path; the runbook never edits the Ticket.
The Control Center catalog has no Execute button or remote runbook API.

AI analysis is a separate explicit computation request, not part of page polling.
Backend-normalized context and optional projected diagnostics reach the AI service.
The model output must pass strict Pydantic/schema and supplied-catalog/reference checks.
OBSERVED statements are reconstructed from supplied enum facts; causes are INFERRED;
missing information is UNKNOWN. A context/prompt/provider hash keys an in-memory cache.
AI failure leaves monitoring/incident pages available.

## Why keep it small?

One pilot makes failure modes and ownership reviewable. FastAPI, SQLite, vanilla UI
and local PowerShell are sufficient to demonstrate the workflow without a broker,
orchestrator, vector store or agent framework. This is an engineering tradeoff for
a local portfolio, not evidence that the same stack is production-ready.

## Real AI result and honest limits

Ollama 0.35.1 with llama3.2:3b produced a valid response without repair. It selected
RB-OPS-001 and partially marked already-supplied historical workload state UNKNOWN.
Structured validity does not guarantee diagnostic correctness. Model confidence
(40% overall, 60% cause in this example) is not calibrated probability. Operator
review remains authoritative; no action followed the recommendation.

The deterministic fixture is NOT an LLM. One real injection-oriented check preserved
the advisory contract, not a general guarantee of prompt-injection resistance.
Production authentication/TLS, egress enforcement, broader semantic evaluation,
least-privilege audit, write reconciliation and HA remain technical debt.

## Read further

- [Persistent state model](integration-state-model-v0.1.md)
- [CI identity mapping and original design](event-ci-mapping-v0.1.md)
- [Compose isolation decision](../decisions/ADR-001-compose-isolation.md)
- [AI contract and trust boundary](ai-incident-analysis-v0.1.md)
- [Runbook recovery controls](../runbooks/RB-OPS-003-controlled-lab-recovery.md)
- [Validated phase history](../../PROJECT_STATE.md)
