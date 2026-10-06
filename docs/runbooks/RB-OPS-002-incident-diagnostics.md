# RB-OPS-002 - Collect Incident Diagnostics

Purpose: assemble evidence for the approved synthetic web pilot before deciding
whether to recover. Risk: low. Mode: read only; no action/target/command parameters.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Collect-GiopIncidentDiagnostics.ps1
```

The shared collector reads UTC timestamp, current pilot host/trigger/item and Problem,
up to eight actual Zabbix events, current matching Integration episode, mapped GLPI
Computer and Ticket, confirmed Recovery follow-up reference when available, fixed
application-container state and local frontend/API/workload connectivity.
The active actual Problem takes precedence over historical episodes and large
synthetic manual event IDs. Episode fallback uses timestamp chronology.

Artifacts in `artifacts/runbooks/<execution-id>/`:

- `summary.json`: structured execution audit with projected diagnostic observations.
- `summary.md`: component results, pilot references, action and validation summary.
- `diagnostics.txt`: sanitized structured details for operator review.

Credentials stay in memory. No complete `.env`, container environment, Docker
inspect payload, HTTP headers, raw exceptions, ticket content or unrestricted logs
are written. Log excerpts are intentionally omitted from this MVP: state, API
references and connectivity suffice for this pilot, and avoid incidental secret
disclosure. Known local credential values are additionally redacted before persistence.
Runtime artifacts are ignored by Git; there is no committed live evidence fixture.

Exit code 0 means evidence was collected (including a useful DEGRADED snapshot);
FAIL/UNKNOWN returns 1 and still records available evidence. Unknown data remains
unknown. Review the timestamp and individual source status before approving recovery.
