# Security — local SYNTHETIC LAB

GIOP is a portfolio laboratory, not a production service. Do not expose its
frontends, Integration, Control Center or Ollama publicly. No production security
support SLA or hardened deployment is offered.

Keep credentials in ignored local configuration; never attach .env files, raw logs,
databases, model data or execution artifacts to public issues. Review screenshots
and text before sharing. Use synthetic records only.

For a suspected vulnerability, use GitHub private vulnerability reporting **if the
repository owner has enabled it**. Otherwise request a private contact channel
without posting exploit details or secrets. No reporting address/channel is assumed
to exist yet. If a credential leaks, revoke/rotate it before addressing Git history.

AI is advisory. Its schema validates structure, not diagnostic truth. Treat incident
and model text as untrusted data. A successful injection-oriented test is not proof
against all attacks. Recovery requires a local operator; there is no AI/browser
runbook execution endpoint.

Before publication run the [release review](docs/release/public-safety-review.md).
Database backups and historical secrets require separate operator review; signature
matching cannot guarantee that every secret encoding or rotated value is detected.
