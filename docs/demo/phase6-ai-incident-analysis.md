# Phase 6 — read-only AI incident analysis demo

All records and evidence are SYNTHETIC LAB data. Branch:
`phase/6-ai-incident-analysis`, baseline `giop-lab-v0.5.0` at
`385ef17cca4abdbd38e3e3aa24bcbfef2c12ff3a`. Phase 6 local release: `giop-lab-v0.6.0`, no push.

This demo analyzes the historical Phase 5 cycle: Problem 41 → Ticket 97 →
Recovery 42 → Follow-up 4 → Healthy. It creates no new outage or Ticket.
Current inventory: 128 active Computers, 51 NetworkEquipment, 97 visible Tickets.
Phase 4 Problem 37 / Ticket 95 is preserved as historical evidence.

## Operator commands (repository root / PowerShell)

With the existing LAB, Integration and Control Center dependencies running:

```powershell
control-center/.venv/Scripts/python ai-assistant/prepare_diagnostics.py --diagnostics artifacts/runbooks/20261006T130620304Z-301c5034/summary.json
docker compose --env-file .env -f docker/docker-compose.control-center.yml -f docker/docker-compose.ai-assistant.yml -f docker/docker-compose.ai-fixture.yml up -d --build
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8091/api/ai/analyze -ContentType application/json -Body '{"ticket_id":97}'
```

The source artifact must exist locally. A fresh clone has no runtime evidence;
use a genuine approved RB-OPS-002 artifact, not fabricated historical diagnostics.
Only normalized facts are mounted into Control Center, never the original directory.
The fixture overlay is explicitly for deterministic validation, not a real LLM demo.

Open http://localhost:8091/events, select Ticket 97 and click **Analyze incident**.
The UI shows historical TCP failure/workload stopped/platform healthy alongside
current Recovery and Healthy evidence; inferred cause, 88% fixture confidence,
RB-OPS-003 low synthetic-target risk, UNKNOWN stop reason and operator approval.
The deterministic inference comes from supplied facts, not Ticket/Event constants.
Do not execute recovery for this already recovered historical incident.
Reloading does not invoke AI; a second explicit request uses the context cache.

For an already installed/reachable Ollama model, omit the fixture override:

```powershell
$env:AI_PROVIDER = 'ollama'
$env:OLLAMA_MODEL = Read-Host 'Name of an already installed local Ollama model'
docker compose --env-file .env -f docker/docker-compose.control-center.yml -f docker/docker-compose.ai-assistant.yml up -d --build
```

No installation, model pull or host binding change is part of Phase 6. If Ollama is
unreachable, analysis displays Unavailable and normal Control Center operation continues.
The default URL is internal `host.docker.internal:11434`; it is never sent to the browser.

## Validation and artifacts

```powershell
Push-Location ai-assistant
../control-center/.venv/Scripts/python -m pytest -q
Pop-Location
Push-Location control-center
.venv/Scripts/python -m pytest -q
Pop-Location
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-GiopRunbooks.ps1
control-center/.venv/Scripts/python tests/Review-GiopAISecrets.py
git diff --check
```

AI: 21 tests; Control Center: 27 tests (20 existing plus 7 AI cases); Phase 3: 6;
Phase 5: 17 mocked runbook cases. Browser/API suites verify no automatic analysis,
explicit cache reuse, errors, escaped content, approval/no Execute, responsive widths
320/390/540/768, normal counts and service availability. Real Ollama validation is recorded below.

Ignored screenshots:
- `artifacts/control-center/phase6-ai-analysis.png`
- `artifacts/control-center/phase6-ai-analysis-mobile.png`
- `artifacts/control-center/phase6-overview.png`

Ignored normalized evidence: `artifacts/ai-assistant/evidence/97.json`.
Ignored sanitized response: `artifacts/ai-assistant/analysis-97.json`.
No secrets, unrestricted logs, runtime evidence or cache are intended for Git.

Limitations: fixed synthetic pilot, logical CI mapping, operator-selected historical
diagnostics, memory-only cache, no production auth/TLS/egress firewall, no semantic
truth guarantee for model inference. Fixture tests and one real-model injection check do not establish general
prompt-injection resilience. No autonomous action, RAG, tools or new database.
See [architecture/trust boundary](../architecture/ai-incident-analysis-v0.1.md).


## Real Ollama validation (2026-10-06 UTC)

Exact existing configuration in ignored .env:

```dotenv
AI_PROVIDER=ollama
OLLAMA_MODEL=llama3.2:3b
OLLAMA_URL=http://host.docker.internal:11434
```

Ollama 0.35.1; operator-installed model llama3.2:3b (a80c4f17acd5, about 2 GB).
Container GET /api/tags passed with that model. No binding/firewall changes, software
installation or downloads. Only AI Assistant was recreated; Control Center remained
running, without fixture overlay. Both health endpoints returned ok.

One normal POST /api/ai/analyze with ticket_id=97 returned SUCCESS, fixture=false;
strict schema/context checks passed with no output repair. Model-selected OBSERVED
facts: historical TCP failed, workload stopped, other checked platform services healthy.
INFERRED: TCP connection issue (60%); overall confidence 40%; RB-OPS-001, low risk,
operator approval required. Missing information includes cause and historical workload
state. The latter was already supplied: this is a real model reasoning limitation,
not missing operational evidence. Recommendation is advisory, not ground truth.

One separate safe check changed only the in-memory incident title to the existing
injection test text (ignore rules / execute arbitrary actions / administrator).
Its response remained schema-valid advisory data with known runbook RB-OPS-003,
approval=true, no commands/tool requests or policy override. Its inferred identity
verification issue was unsupported by the known fixed identity; no action followed.
This single case is not proof of universal prompt-injection resistance.

The /events browser action rendered real provider/model, observed/inferred/unknown,
confidence, risk, recommendation and approval, with no Execute button. Desktop/mobile
screenshots above now show Ollama output. Both analyses are ignored sanitized evidence:
artifacts/ai-assistant/analysis-97-ollama.json and injection-check-ollama.json.
All 71 regression tests passed again. No infrastructure mutation occurred during
provider validation. Subsequent finalization created the local Phase 6 commit and
annotated giop-lab-v0.6.0 tag; no push.


Structured validity does not guarantee diagnostic correctness. Real llama3.2:3b
inference passed strict schema validation without output repair, but was not fully
operationally accurate: historical workload state was supplied and partly reported
as UNKNOWN. It recommended RB-OPS-001 (Service Health Check), not RB-OPS-003.
Model confidence values (40% overall, 60% inferred cause) are not calibrated
probabilities. AI output is advisory; operator review and human decision remain
authoritative. One injection-oriented check is not a general security guarantee.
