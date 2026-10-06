"""Operator-only projection of one RB-OPS-002 artifact; no API or .env access."""
import argparse
import hashlib
import json
from pathlib import Path
from giop_ai_contract import Diagnostics, Evidence


def project(raw):
    if raw.get('runbook_id') != 'RB-OPS-002' or raw.get('environment') != 'SYNTHETIC LAB' or raw.get('mode') != 'read-only':
        raise ValueError('Only synthetic RB-OPS-002 records are accepted')
    observation = raw['results']['observation']
    episode = observation['episode']
    z = observation['zabbix']
    if episode['host_id'] != '10683' or episode['trigger_id'] != '25228' or episode['ci_uid'] != 'urn:uuid:9e68f0af-8b55-4b0e-95e4-07dc02a7f6cb':
        raise ValueError('Only approved pilot diagnostics are accepted')
    # Free text, credentials, logs, Ticket content and unknown fields are discarded.
    evidence = []
    timestamp = raw['started_at']
    def fact(identity, value):
        evidence.append(Evidence(id=identity, value=value, source='RB-OPS-002', window='historical incident', observed_at=timestamp))
    item = z.get('items', [])
    if len(item) == 1 and item[0].get('key_') == 'net.tcp.service[http,gua-lab-srv-web-001,80]' and item[0].get('state') == '0':
        if item[0].get('lastvalue') in ('0', '1'):
            fact('pilot_tcp', 'failed' if item[0]['lastvalue'] == '0' else 'passed')
    workload = observation.get('containers', {}).get('gua-lab-srv-web-001', {})
    if workload.get('service') == 'web-workload' and workload.get('project') == 'giop-lab':
        if workload.get('status') in ('exited', 'created', 'running'):
            fact('workload_state', 'running' if workload['status'] == 'running' else 'stopped')
    health = raw['results'].get('health', {})
    checked = ('zabbix_frontend', 'zabbix_api', 'glpi_frontend', 'glpi_api', 'integration', 'control_center')
    fact('platform_health', 'healthy' if all(health.get(key) == 'PASS' for key in checked) else 'unknown')
    return Diagnostics(execution_id=raw['execution_id'], collected_at=timestamp,
                       ticket_id=episode['glpi_ticket_id'], event_id=episode['event_id'], evidence=evidence)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--diagnostics', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, default=Path('artifacts/ai-assistant/evidence'))
    args = parser.parse_args()
    try:
        data = args.diagnostics.read_bytes()
        if len(data) > 262144:
            raise ValueError('Artifact too large')
        normalized = project(json.loads(data.decode('utf-8-sig')))
        args.output_dir.mkdir(parents=True, exist_ok=True)
        target = args.output_dir / f'{normalized.ticket_id}.json'
        target.write_text(normalized.model_dump_json(indent=2), encoding='utf-8')
        print(f'Prepared bounded synthetic diagnostics: Ticket {normalized.ticket_id}; source SHA256 {hashlib.sha256(data).hexdigest()}')
        print(f'Output: {target}')
    except Exception:
        raise SystemExit('Diagnostics rejected; no raw contents or errors disclosed.')
