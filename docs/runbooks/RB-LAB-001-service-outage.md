# RB-LAB-001 — Controlled synthetic web service outage

## Purpose

Validate monitor → detect → alert/event → recover using only synthetic `GUA-LAB-SRV-WEB-001`.

## Preconditions

The lab has been started with `./scripts/lab-up.ps1`, the smoke test passes, and bootstrap exits with code 0 in `docker compose --env-file .env -f docker/docker-compose.yml ps`.

## Failure injection

Run `docker compose --env-file .env -f docker/docker-compose.yml stop web-workload`. Wait at least 30 seconds; the polling interval is 15 seconds. This affects only the local lab.

## Expected monitoring result

Zabbix Monitoring → Problems displays `GIOP-LAB: controlled web workload TCP unavailable`. Latest data for `Synthetic web workload TCP reachability` is `0`.

## Recovery procedure

Run `docker compose --env-file .env -f docker/docker-compose.yml start web-workload`, then `./scripts/lab-smoke-test.ps1`. Wait at least 30 seconds. The problem resolves and the item returns `1`.

## Validation and evidence to capture

Capture synthetic-only output for Compose state before/during/after, Zabbix Problems showing event and recovery, and Zabbix Latest data. Do not place real information in this repository.
