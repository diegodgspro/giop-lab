# RB-OPS-003 - Controlled LAB Recovery

Purpose: operator-approved restoration of exactly `web-workload` /
`gua-lab-srv-web-001`. Risk: controlled local write. Environment: SYNTHETIC LAB.
There is no automatic remediation, generic command engine or browser execution.

Default, with no workload mutation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Invoke-GiopControlledRecovery.ps1
```

After reviewing diagnostics and the printed target/action/environment, explicitly apply:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runbooks/Invoke-GiopControlledRecovery.ps1 -Execute -WaitSeconds 180
```

`-Execute` is the operator's explicit approval of this fixed action, not a general
confirmation bypass. There is no Force, arbitrary command, container, service,
host or Compose-file parameter. PowerShell `ExecutionPolicy Bypass` above is
process-local script loading, not runbook approval; it cannot replace `-Execute`.

Preconditions fail closed:

- Repository root is this checkout, HEAD descends from v0.4.0 commit
  `42e3cbab9758624dfe3be42459f6931ae3519197`, and the v0.4.0 tag still points there.
- `docker/docker-compose.yml` matches the frozen tag's approved file (normalized line endings).
- Existing container has Compose project `giop-lab`, service `web-workload`, and known state.
- Integration health is available and mode LIVE; unknown/dry-run mode blocks recovery.
- Exactly one enabled host 10683 has technical name `GUA-LAB-AGENT-001` and approved display name.
- Exactly one enabled trigger 25228 has the approved description, host and expanded expression.
- The enabled/supported item targets `net.tcp.service[http,gua-lab-srv-web-001,80]`.
- GLPI Computer 1 matches `GUA-LAB-SRV-WEB-001`.
- An active Problem has its matching LIVE PROBLEM_OPEN episode, mapped CI UID and
  API-read Ticket ID/title/external marker for that event.

The approved Compose service is started if stopped, restarted if already running.
Identity/state is read again immediately before action. A local named mutex prevents
concurrent apply runs on this operator workstation. No mutation retries, DB access,
Zabbix changes or GLPI writes are made by the runbook.

Post-action polling has a configurable 15-300 second window (default 180), plus at
most one in-flight read cycle; HTTP requests time out individually after five seconds.
It requires running/healthy workload and a successful HTTP health check, a fresh
Zabbix item=1 and trigger=OK. For an active Problem, the original actual Zabbix event
must point to the episode's Recovery event; that same episode/Ticket must become
RECOVERED_PENDING_OPERATOR_VALIDATION with a confirmed GLPI follow-up containing
the original Problem and Recovery references. The existing Phase 3 path owns these writes.

If invoked while healthy, fresh post-action OK is checked; historical Recovery is
not presented as a new event, and Incident/follow-up checks are not applicable.
PASS means validation completed; DEGRADED means action completed but validation
timed out; FAIL means blocked/error/unconfirmed action. Exit 0 only for PASS.
All outcomes create an ignored audit record, including requested action, execution
result, Recovery observed boolean, Integration state and GLPI Ticket reference.
Do not rerun automatically after an unconfirmed action; inspect state and evidence.

Human review and final Ticket closure remain manual. This is not production orchestration.
