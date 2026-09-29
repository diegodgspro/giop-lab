# ADR-001 — Isolated Docker Compose networks

## Status

Accepted.

## Decision

Use two internal bridge networks: monitor and workload. Publish only Zabbix Web to localhost.

## Rationale

This keeps the synthetic database and monitoring paths off the host network while allowing a precise Agent 2 health probe to the controllable workload.
