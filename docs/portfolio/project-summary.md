# GIOP portfolio text

## A. Two-line GitHub summary

GIOP is a synthetic infrastructure-operations LAB connecting Zabbix, GLPI and a read-only N3 dashboard.
It demonstrates persistent incident correlation, operator-approved runbooks and advisory local AI with explicit safety boundaries.

## B. CV / resume

Built a local infrastructure-operations portfolio LAB integrating Zabbix observability
with GLPI ITSM/CMDB through FastAPI and persistent SQLite correlation. Delivered a
responsive read-only Control Center, audited PowerShell diagnostics/fixed-target
recovery, and structured Ollama incident analysis; validated 71 regression cases
and a synthetic Problem → Incident → Recovery workflow. Human approval remains
mandatory; no autonomous remediation or production deployment is claimed.

## C. LinkedIn project description

GIOP — Guaratinguetá Infrastructure Operations Platform — LAB explores the gap
between monitoring and governed operations. The project connects a synthetic Zabbix
alarm to a GLPI Incident, keeps correlation across restarts, and exposes evidence in
an N3 Control Center. Operator-local runbooks diagnose, collect sanitized artifacts
and restore only one approved LAB workload after an explicit decision.

An optional local Ollama assistant provides schema-validated advisory analysis,
separating observations, inference and unknown information. A real model test also
exposed a semantic mistake despite valid structure, reinforcing the need for operator
review. This is a synthetic portfolio implementation, not the municipality's live
production environment or an autonomous AIOps platform.

## D. Interview explanation

### 30 seconds

GIOP is a synthetic operations LAB that turns a Zabbix Problem into a correlated
GLPI Incident and brings it into a read-only N3 dashboard. The operator diagnoses
with PowerShell runbooks, reviews a plan, explicitly approves recovery of one fixed
workload, and validates the Recovery follow-up. Local AI can analyze evidence but
cannot execute anything. It demonstrates operational ownership and governance,
without pretending to be a production municipal system.

### 2 minutes

I wanted to demonstrate the complete operational thread rather than four unrelated
tools. Zabbix owns detection; GLPI owns ITSM and CMDB; a small FastAPI Integration
owns translation, persistent correlation and duplicate suppression. SQLite is
proportional to the single-instance LAB. The integration uses supported application
APIs, not direct Zabbix or GLPI database writes.

Control Center is a read-only view of current APIs and episode state. Recovery adds
evidence without automatically closing the Ticket. Three local PowerShell runbooks
cover health checks, sanitized diagnostics and fixed-target recovery. Recovery is a
plan by default, checks identity before acting, requires explicit -Execute, and
validates the actual monitoring/ITSM result afterward. It is not a generic command engine.

Phase 6 adds optional AI assistance with deliberately bounded context and strict
structured output. The fixture is deterministic test support; real Ollama 0.35.1
with llama3.2:3b was also validated. The real response was structurally valid but
partly labeled known workload state UNKNOWN and recommended a health runbook.
That result matters: schema correctness is not diagnostic correctness, and model
confidence is not calibrated probability. Human decision remains authoritative.

The regression suite has 71 cases, supplemented by historical synthetic end-to-end
evidence and browser checks. The remaining work is production hardening and broader
semantic evaluation, not a claim of autonomous remediation or municipal deployment.

## E. Key engineering achievements

- Connected detection, Incident, Recovery and human validation with persistent correlation.
- Kept monitoring/ITSM ownership separate from the presentation and AI layers.
- Made recovery fail closed on ambiguous identity and constrained it to one LAB target.
- Collected bounded sanitized diagnostics and execution audit without publishing runtime data.
- Built responsive operator visibility and optional AI failure isolation.
- Preserved a real model limitation instead of presenting a scripted ideal response.
- Documented release boundaries, reproducibility limits and proportional test coverage.
