# Public release review — v1.0 preparation

Baseline: giop-lab-v0.6.0 / 0f9186c9082aa16472d2d086cc49950e6d20e09f.
Branch: release/1.0-public-portfolio. Review includes the current source tree,
intended new files and all reachable historical commits. Final preparation adds one
release commit and a local annotated v1.0 tag. No history rewrite, existing-tag change,
push, publication or silent document deletion is performed.

## Findings and public representation

| Category | Finding / treatment |
| --- | --- |
| Known local secrets | No match in proposed public files or reachable historical blobs; values are never printed |
| Credential signatures | No private-key/GitHub-token/AWS-key signature found by the scoped scanner |
| Local configuration | .env and scoped .env.zabbix-alert remain ignored; .env.example contains placeholders/non-secret provider guidance |
| Runtime state | Integration SQLite lives in local volume; execution evidence, logs/caches and AI results are excluded |
| Historical read-back | artifacts/glpi-phase2-created.json is an intentionally retained non-secret synthetic seed manifest, not a runtime runbook/AI execution artifact |
| Network/topology | File review found loopback/listener addresses, Docker service DNS and synthetic LAB identities, not real municipal internal IP/topology |
| Personal paths/usernames | No personal filesystem paths found in published source; Git attribution is the existing GitHub handle/noreply address, retained as ordinary authorship |
| Source context | docs/source/README.md declares no real-infrastructure source material; LAB topology/distribution is synthetic, not a municipal site claim |
| Screenshots | Four selected views copied/captured into docs/assets, checked visually and for embedded metadata; no credentials/account chrome/personal paths |
| Model data | Ollama/model files are not part of the repository; real inference evidence remains local and ignored |
| License | Owner selected MIT; canonical text and 2026 owner attribution are in LICENSE |

The bootstrap's public Zabbix factory credential is used for local initialization/
replacement; it is not a disclosed local runtime secret. Environment variable names,
OAuth flows and technical LAB identities are useful public engineering context and
are retained without credential values or real operational details.

No document required sensitive-detail removal based on this review. If later review
finds private operational material, replace its public representation with a synthetic
role/service name, relative path and bounded summary; preserve provenance in a private
record rather than silently erasing historical engineering evidence. Never publish a
real map merely because its IPs or names have been cosmetically changed.

## Reproducible checks and limits

```powershell
control-center/.venv/Scripts/python tests/Review-GiopPublicRelease.py
git diff --check
```

The scanner reads known local credentials without disclosing them, reviews reachable
Git blobs as well as proposed files, denies runtime/model/cache inclusion and checks
PNG metadata. Visual inspection confirms the selected captures show only SYNTHETIC
LAB evidence; the real AI image preserves its semantic error instead of hiding it.
Known-value/signature matching cannot rule out unknown, encoded or previously rotated
secrets. Ordinary Git author metadata is part of public attribution, not anonymized.

Tests/Compose/link/Mermaid validation are described in [validation](../testing/public-validation.md).
Final checks passed: 71 regression cases (21 AI / 27 Control Center / 6 Phase 3 /
17 Phase 5), mocked Zabbix provisioning and repository-structure checks, seven Compose
combinations, local documentation/image links, and final Mermaid 11.17.2 parse/render.
All four public screenshots were inspected visually; their capture/AI source text
matched no known local credentials or personal paths. Whitespace review passed.
Fresh-host setup was not rerun and no new outage was caused for documentation.
The release branch does not change runtime services, recovery policy, upstream writes
or AI architecture. Historical Phase 3/4/5/6 documents remain snapshots, not current
production deployment instructions.

## Publication decisions

No detected secret/topology issue requires a history rewrite. The owner selected
the [MIT License](../../LICENSE), included in the final release preparation. Private GitHub vulnerability reporting should be enabled if desired; it is
not assumed configured. Public pushing/release publication is not authorized here.

Production deployment remains out of scope: local non-HA pilot, fixed identities,
logical CI relations, incomplete least-privilege/TLS/auth/egress hardening and limited
AI semantic/injection evaluation. These are documented limitations, not hidden claims.
