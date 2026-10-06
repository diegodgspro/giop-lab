# Event and CI mapping v0.1

Phase 3A design only; writes NOT ENABLED. Exactly one pilot CI is selected: the seeded synthetic web workload, not the Agent inventory endpoint.

```json
{
  "environment": "giop-lab",
  "ci_uid": "urn:uuid:9e68f0af-8b55-4b0e-95e4-07dc02a7f6cb",
  "zabbix_instance_uid": "urn:uuid:de2ee010-9022-4a17-94e9-e1615289fc86",
  "zabbix_hostid": "10683",
  "glpi_instance_uid": "urn:uuid:6b3d9c0a-5fbc-4a28-a737-fbf1fb062f0f",
  "glpi_itemtype": "Computer",
  "glpi_items_id": 1,
  "glpi_entity_id": 0,
  "service_key": "synthetic-web-tcp",
  "mapping_version": 1,
  "mapping_status": "VALIDATED_READBACK_PENDING_OPERATOR_APPROVAL"
}
```

UIDs are newly assigned immutable synthetic contract identities, not discovered platform IDs. Persist/retain them in future config/state and backups; never regenerate on restart. Recreated independent instances need new instance UIDs. Host/item IDs are instance-scoped references, never global identity. Mapping may become ACTIVE only after operator approves these identities, entity scope and impact. Snapshot version for every episode; a later mapping change must not redirect an existing ticket.

Evidence: live Zabbix host.get shows host 10683 technical GUA-LAB-AGENT-001, display GUA-LAB-SRV-WEB-001 synthetic monitor, DNS interface zabbix-agent2:10050. Trigger 25228 has description GIOP-LAB: controlled web workload TCP unavailable, severity 3. Live GLPI GET /Assets/Computer/1 returned name GUA-LAB-SRV-WEB-001 and entity 0 Root entity. Manifest also records Computer 1. GUA-LAB-INVENTORY-001 is separate Computer 182 and must never be substituted.

Names/IPs/MACs are attributes only. Enforce unique active source (instance, host, service, trigger) and target mapping for this pilot. Duplicate/unknown mapping, deleted CI, wrong entity, disabled mapping or inconsistent read-back quarantines event; never auto-create a CI.

## Allowlist

Allow only environment giop-lab, assigned instance UID, hostid 10683, triggerid 25228, exact trigger name above, service synthetic-web-tcp. Accept PROBLEM, relevant stable UPDATE and correlated RECOVERY for this episode only. Recovery must reference the original PROBLEM event ID. Names are additional assertions, not primary identity. All other triggers, including default-host availability, are ineligible and logged/persisted minimally without GLPI action. Fail closed on multi-host events, unknown instance/source or identity mismatch. Never use generic all-problems-create-tickets.

## Payload proposal

Schema version 1 requires environment, instance UID, original problem_event_id, operation type, stable operation identifier, hostid, triggerid, service key, numeric severity, source event timestamp UTC and event closure cause where relevant. Recovery additionally requires recovery_event_id and original problem_event_id; update requires stable source update ID. IDs are decimal strings with explicit length bounds, not floating-point numbers. Request receipt timestamp is independent from source time. Do not derive identity from mutable title/time/body hashes. Reject payload URLs, unsupported fields/types and ambiguous correlation rather than guessing.

Operational grouping key: environment + ci_uid + service_key + triggerid + explicit 300-second LAB window. This supports human grouping only: new PROBLEM IDs always create distinct episodes; window never silently merges tickets, different triggers or multiple CIs. Flapping is annotated and rate-limited, not assumed a common root cause.

See zabbix-glpi-integration-v0.1.md for independent urgency/impact/priority and pending impact/matrix approval.
