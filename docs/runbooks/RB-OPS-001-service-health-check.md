# RB-OPS-001 - Service Health Check

Purpose: diagnose the current synthetic LAB without changing business state.
Risk: low. Mode: read only. Operator-local Windows PowerShell 5.1; Docker CLI and
the existing ignored `.env` are required. No runbook is invoked by monitoring.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Invoke-GiopServiceHealthCheck.ps1
```

Checks: fixed workload Docker state/health and HTTP `/healthz` inside that workload;
local Zabbix frontend/API and enabled pilot trigger/item; GLPI frontend/API and
Computer 1; Integration health/episodes; Control Center health. Frontend reachability
does not certify application correctness. Zabbix host 10683 / trigger 25228 is the
approved synthetic pilot; monitored service availability is distinct from agent availability.

Each component reports PASS, DEGRADED, FAIL or UNKNOWN. A stopped/unhealthy workload
or active pilot Problem is DEGRADED; an unsupported/disabled item is FAIL; unavailable
evidence is UNKNOWN. Overall precedence: FAIL, DEGRADED, UNKNOWN, PASS. Exit code is
0 for PASS, 1 otherwise. Read-only checks still use authentication/session POSTs.

Every execution writes `summary.json`, `summary.md` and `diagnostics.txt` under
ignored `artifacts/runbooks/<execution-id>/`. Inspect individual checks rather than
interpreting an overall failure as permission to remediate. No production readiness
or availability history is inferred.
