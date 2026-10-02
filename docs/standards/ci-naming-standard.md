# CI Naming Standard v0.1

Seeded assets use GUA-LAB-<TYPE>-<NNN>; servers include role: GUA-LAB-SRV-<ROLE>-<NNN>. Examples: GUA-LAB-SRV-WEB-001, GUA-LAB-PC-001, GUA-LAB-SW-001, GUA-LAB-AP-001, GUA-LAB-RTR-001, GUA-LAB-FW-001, GUA-LAB-CPE-001. Three-digit sequences are unique within type/role. Native LAB-* Locations store location separately. Optional site tokens are a future convention; preserve existing names and IDs.

The inventory endpoint uses GUA-LAB-INVENTORY-001. Phase 1 workload CI is GUA-LAB-SRV-WEB-001; Zabbix display name is GUA-LAB-SRV-WEB-001 synthetic monitor and technical bootstrap host is GUA-LAB-AGENT-001. Future CI mapping must account for this distinction.


PHASE 1: COMPLETE. PHASE 2: COMPLETE. PHASE 3: NOT STARTED.

No real municipal operational dataset is represented by the synthetic LAB. Actual physical municipal site count: TO VALIDATE.

Validated seed: 41 Locations, 127 Computers (11 servers and 116 workstations), 51 NetworkEquipment, 93 Tickets. Configuration: data/glpi-phase2-seed.json. Non-secret read-back/logical mappings: artifacts/glpi-phase2-created.json.

Separate automated inventory: GLPI Agent 1.20, GUA-LAB-INVENTORY-001, GLPI Computer ID 182, last inventory 2026-10-01T14:27:15+00:00. OAuth Client Credentials scope inventory. Protocol detection, Inventory task and submission succeeded, exit code 0. 127 seeded + 1 discovered = 128 conceptual LAB Computers. Never add this endpoint to seed JSON. Persistence lab-down/lab-up: PASS, ID 182 retained.

Debian 12/bookworm, x86_64, kernel, processor/components, software, automatic inventory and Agent metadata, timestamp and contact/IP metadata were discovered. Memory details were incomplete and native NetworkPort objects absent on this isolated Docker/WSL2 endpoint. No fields are fabricated; no general production limitation is claimed.

Entity creation was rejected under current High-Level API authorization; native Locations were used instead. The GIOP-LAB Entity label is a convention, not a created Entity claim. No supported native Ticket-Item association route was exposed by the inspected API. Manifest mappings are logical only. Historical ticket timestamps were not manipulated.

GLPI 11.0.9: frontend HTTP 200, schema OK; API scope api, token acquisition SUCCESS, OAuth HTTP 200 and API read HTTP 200. IDENTITY_CONFIRMATION=REQUIRES_USER_SCOPE is expected.

Phase 1 regression: PASS. GUA-LAB-SRV-WEB-001 synthetic monitor opened GIOP-LAB: controlled web workload TCP unavailable on 2026-10-02 at 19:42:31 local operator time; recovery 19:44:26, duration 1m55s, final RESOLVED. Healthy -> outage -> detection -> Problem -> restore -> Recovery -> resolved -> lab.web.status [s|1]. Smoke PASS.

Older unrelated Zabbix server problem: Linux: Zabbix agent is not available (for 3m). It predates the regression and remains LAB configuration/noise to review. No recovery was fabricated.

No Zabbix -> GLPI incident automation exists. Proposed Phase 3 design only: CI/severity mapping, deduplication, correlation, recovery, auditability, no ticket storm and no autonomous remediation. Runtime evidence above is operator-supplied; finalization CLI checks are static.
