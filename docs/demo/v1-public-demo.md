# GIOP public demo — 5–8 minutes, SYNTHETIC LAB

All records are synthetic. Use only the approved `web-workload`, never municipal
production. This is an operator script, not an outage performed during release prep.
Monitoring may take time; do not invent events to satisfy the presentation timing.

## Preflight (before recording)

Complete the [staged setup](../setup/quick-start.md). Confirm LIVE Integration,
automatic Zabbix delivery, frozen pilot identities and a healthy workload.
Keep credentials, raw logs, developer tools, environment files and local personal
paths off-screen. Open Control Center, Zabbix and GLPI in separate browser tabs.
For real AI, confirm local Ollama/provider is configured and reachable first.
Historical 41 / 97 / 42 / 4 is an example; use actual new IDs in a fresh demonstration.

## 0:00–1:00 — show the operational thread

Show http://localhost:8091 and identify source health, active inventory and the pilot.
Explain Zabbix ownership, Integration correlation and GLPI Incident evidence.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Invoke-GiopServiceHealthCheck.ps1
```

## 1:00–2:30 — detect and correlate

The operator deliberately creates one controlled synthetic interruption:

```powershell
docker compose --env-file .env -f docker/docker-compose.yml stop web-workload
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-GiopIntegrationHealth.ps1 -State
```

Wait for Zabbix Problem and automatic GLPI Incident, then show the same pair in
Control Center `/events`. Open that GLPI Ticket; do not manually create or close it.
If automatic correlation is missing, stop the live demo and investigate safely.

## 2:30–4:00 — diagnose and review

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Invoke-GiopServiceHealthCheck.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Collect-GiopIncidentDiagnostics.ps1
```

DEGRADED returns exit code 1 intentionally. Note the RB-OPS-002 execution directory
reported by the command. Review its sanitized summary locally, not unrestricted logs.
Preserve this incident-time diagnostic before recovery. `/runbooks` is a catalog only.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Invoke-GiopControlledRecovery.ps1
```

Read the fixed target/action, preconditions and dry-run result aloud. No action has
executed. Review the evidence before deciding whether recovery is appropriate.

## 4:00–6:00 — approve, recover, validate

The operator explicitly invokes the only permitted recovery:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Invoke-GiopControlledRecovery.ps1 -Execute -WaitSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Invoke-GiopServiceHealthCheck.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-GiopIntegrationHealth.ps1 -State
```

Show actual Zabbix Recovery, same Integration episode, GLPI Recovery follow-up and
Healthy dashboard. The runbook does not write GLPI; existing automation supplies
the follow-up. Ticket remains awaiting human validation. Show the sanitized audit
proving request, target, result and validation. Do not infer success from a restart alone.

## 6:00–8:00 — advisory AI and governance

Use the incident-time RB-OPS-002 file from this demonstration:

```powershell
$diagnosticsFile = Read-Host 'Relative RB-OPS-002 summary.json path for this incident'
control-center/.venv/Scripts/python ai-assistant/prepare_diagnostics.py --diagnostics $diagnosticsFile
```

The existing CLI validates/projections this artifact; it does not modify infrastructure.
In `/events`, select the actual correlated Incident and click **Analyze incident**.
No model is called by ordinary page refresh. Show real provider/model, OBSERVED,
INFERRED, UNKNOWN, confidence, risk, known runbook and **Operator approval required**.
There is no Execute button and AI cannot call the local runbook.

Explain the validated historical result honestly: Ollama 0.35.1 / llama3.2:3b passed
schema validation but did not use the historical workload-state evidence correctly,
partly labeling it UNKNOWN. It recommended RB-OPS-001. A fresh output may differ;
do not substitute the fixture or edit model output to present an ideal answer.
Structured validity does not imply diagnostic correctness; confidence is not
calibrated probability. Human decision remains authoritative.

## If recording is interrupted

Restore only the deliberately stopped LAB target if it is still stopped:

```powershell
docker compose --env-file .env -f docker/docker-compose.yml start web-workload
```

Inspect actual Recovery/follow-up and keep partial evidence. Do not delete episodes,
fabricate recovery or claim that this cleanup was the approved runbook validation.
For a no-outage walkthrough, use the public captures and clearly identify historical
41 → 97 → 42 → 4 evidence. This preparation did not rerun the live outage cycle.
