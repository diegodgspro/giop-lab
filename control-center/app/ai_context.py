"""Explicit, sanitized projection. Infrastructure credentials stay in Control Center."""
import os
from pathlib import Path
from giop_ai_contract import IncidentAnalysisContext, Diagnostics, Evidence, RUNBOOKS, sanitize_text


def normalized_label(value, secrets):
    if isinstance(value, dict):
        value = value.get('name') or value.get('id') or 'UNKNOWN'
    return sanitize_text(value, secrets)


def build_context(snapshot, ticket_id, evidence_dir=None):
    secrets = [value for key, value in os.environ.items() if any(part in key.upper() for part in ('PASSWORD', 'SECRET', 'TOKEN', 'CLIENT_ID'))]
    e = next((e for e in snapshot['integration'].get('episodes', []) if e.get('glpi_ticket_id') == ticket_id), None)
    ticket = next((t for t in (snapshot['glpi'].get('tickets') or {}).get('items', []) if t['id'] == ticket_id), None)
    if not e or not ticket or (str(e.get('host_id')), str(e.get('trigger_id')), e.get('ci_uid')) != ('10683', '25228', 'urn:uuid:9e68f0af-8b55-4b0e-95e4-07dc02a7f6cb'):
        raise ValueError('Approved correlated pilot evidence required')
    if not str(ticket.get('external_id') or '').startswith('giop:v1:') or not str(ticket['external_id']).endswith(':problem:' + str(e['event_id'])):
        raise ValueError('Synthetic Ticket marker required')
    diagnostics = None
    path = Path(evidence_dir or os.getenv('CC_AI_EVIDENCE_DIR', '/evidence')) / f'{ticket_id}.json'
    try:
        if path.exists():
            data = path.read_bytes()
            if len(data) <= 16384:
                candidate = Diagnostics.model_validate_json(data)
                if (candidate.ticket_id, candidate.event_id) == (ticket_id, str(e['event_id'])):
                    diagnostics = candidate
    except Exception:
        pass  # Unreadable/invalid/unrelated artifacts never become incident evidence.
    evidence = []
    events = snapshot['zabbix'].get('events', [])
    problem = next((v for v in events if str(v.get('eventid')) == str(e['event_id']) and str(v.get('value')) == '1'), None)
    if problem:
        evidence.append(Evidence(id='zabbix_problem', value='problem', source='Zabbix', window='historical incident', observed_at=e.get('problem_time')))
    pilot = snapshot['zabbix'].get('pilot')
    if pilot and str(pilot.get('triggerid')) == '25228' and str(pilot.get('status')) == '0':
        evidence.append(Evidence(id='current_pilot', value='passed' if str(pilot.get('value')) == '0' else 'failed', source='Zabbix', window='current snapshot'))
    if e.get('recovery_event_id'):
        evidence.append(Evidence(id='recovery', value='recovered', source='Integration', window='historical incident', observed_at=e.get('recovery_time')))
    if e.get('followup_id'):
        evidence.append(Evidence(id='followup', value='confirmed', source='Integration', window='historical incident', observed_at=e.get('recovery_time')))
    computer = next((c for c in (snapshot['glpi'].get('computers') or {}).get('items', []) if c['id'] == 1), {})
    return IncidentAnalysisContext(
        environment='SYNTHETIC LAB',
        incident={'ticket_id': ticket_id, 'title': normalized_label(ticket.get('name'), secrets), 'status': normalized_label(ticket.get('status'), secrets), 'priority': normalized_label(ticket.get('priority'), secrets), 'synthetic': True},
        zabbix={'problem_event_id': str(e['event_id']), 'recovery_event_id': e.get('recovery_event_id'), 'host_id': '10683', 'host': 'GUA-LAB-SRV-WEB-001', 'trigger_id': '25228', 'trigger': normalized_label(pilot.get('description') if pilot else 'UNKNOWN', secrets), 'severity': int(problem['severity']) if problem and str(problem.get('severity')).isdigit() else None, 'problem_time': normalized_label(e.get('problem_time'), secrets), 'recovery_time': e.get('recovery_time')},
        ci={'ci_uid': e['ci_uid'], 'computer_id': 1, 'asset_name': 'GUA-LAB-SRV-WEB-001', 'location': normalized_label(computer.get('location'), secrets) if computer.get('location') else None},
        integration={'state': e['status'], 'mode': e['mode'], 'event_id': str(e['event_id']), 'ticket_id': ticket_id, 'recovery_event_id': e.get('recovery_event_id'), 'followup_id': e.get('followup_id')},
        diagnostics=diagnostics, evidence=evidence, runbooks=RUNBOOKS)
