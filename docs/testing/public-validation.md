# Public release validation

Validated baseline: giop-lab-v0.6.0. All data is SYNTHETIC LAB. Public preparation
changes presentation/review tooling, not runtime behavior.

## Offline regression — 71 tests

Python 3.13; run suites in separate working directories because both FastAPI services
use the Python package name `app`. Example local test environment:

```powershell
python -m venv control-center/.venv
control-center/.venv/Scripts/python -m pip install -r control-center/requirements.txt -r integration/requirements.txt -r ai-assistant/requirements.txt
Push-Location ai-assistant
../control-center/.venv/Scripts/python -m pytest -q
Pop-Location
Push-Location control-center
.venv/Scripts/python -m pytest -q
Pop-Location
Push-Location integration
../control-center/.venv/Scripts/python -m pytest -q
Pop-Location
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-GiopRunbooks.ps1
```

| Suite | Cases | Scope |
| --- | --- | --- |
| AI Assistant | 21 | Sanitization, strict output, references, fixture, mocked Ollama, failures, cache |
| Control Center | 27 | Existing read-only behavior, active inventory, AI context/client/UI contracts |
| Integration / Phase 3 | 6 | Event lifecycle, duplicate suppression, persistence and failures |
| Runbooks / Phase 5 | 17 | Health, diagnostics, audit, fail-closed identity, dry-run and mocked recovery |

Fixture provider tests remain deterministic and require no Ollama. Runbook unit tests
mock Docker/APIs; they do not create outages. Upstream AnyIO deprecation warnings are
non-failing. This matrix is proportional MVP coverage, not production certification.

## Compose and publication checks

Run `docker compose --env-file .env -f <definition> config --quiet` for the base,
inventory and Integration definitions, and combined base+integration-source,
Control Center+AI, and Control Center+AI+fixture layers. Never share expanded Compose
output: interpolation can reveal local credentials.

```powershell
control-center/.venv/Scripts/python tests/Review-GiopPublicRelease.py
git diff --check
git check-ignore .env artifacts/ai-assistant/analysis-97-ollama.json artifacts/control-center/phase6-ai-analysis.png
```

The public scanner checks intended tracked/untracked source plus all reachable Git
blobs for known local credentials/signatures and personal paths. Public The exact four-image public screenshot set and PNG metadata
are checked; visual review is still required. Ignore checks include local Ollama
state and GGUF/safetensors model weights. It cannot prove absence of unknown or
encoded historical secrets. Older phase-specific scanners have frozen branch/HEAD
assertions; use the public scanner for the release branch.

## Browser, diagram and documentation

Public images are reviewed against their capture text and visually for secrets/PII.
The README Mermaid diagram is rendered with the Mermaid API, not merely accepted
as a code fence. Local README links and setup/demo references are checked.
The staged setup is reviewed against scripts/Compose; it is not a fresh-host test.

Historical manual validation: automatic Zabbix → GLPI cycle and duplicate suppression,
persistent episodes, controlled runbook recovery, API-confirmed follow-up, real Ollama
structured inference and one injection-oriented case. Phase 6 browser tests verified
desktop/mobile, AI failure isolation, no automatic inference and no Execute button.
No new outage is necessary to verify documentation edits.
