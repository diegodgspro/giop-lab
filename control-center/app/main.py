import logging
import re
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from .sources import Sources, stamp
from .ai_context import build_context
from .ai_client import AIClient

logging.getLogger('httpx').setLevel(logging.WARNING)
ROOT = Path(__file__).parent


class Aggregator:
    def __init__(self, sources=None, ttl=15):
        self.sources = sources or Sources()
        self.ttl = ttl
        self.lock = threading.Lock()
        self.saved = None
        self.expiry = 0

    def snapshot(self):
        with self.lock:
            if self.saved is not None and time.monotonic() < self.expiry:
                return self.saved
            def fetch(name):
                try:
                    return getattr(self.sources, name)()
                except Exception:
                    # Never return upstream bodies, URLs, exception strings or credentials.
                    return {'status': 'Unavailable', 'checked_at': stamp(), 'message': 'Source read unavailable'}
            with ThreadPoolExecutor(max_workers=3) as pool:
                results = list(pool.map(fetch, ('zabbix', 'glpi', 'integration')))
            data = dict(zip(('zabbix', 'glpi', 'integration'), results))
            data['updated_at'] = stamp()
            data['synthetic'] = True
            data['refresh_seconds'] = 20
            self.saved = data
            self.expiry = time.monotonic() + self.ttl
            return data


def derive(data):
    z, g, i = (data[k] for k in ('zabbix', 'glpi', 'integration'))
    episodes = i.get('episodes')
    latest = episodes[0] if episodes else None
    if latest:
        # Frozen Phase 3 pilot mapping, not discovered topology or a native GLPI
        # Ticket-CI association. Event/Ticket/Recovery IDs always come from API.
        pilot_mapping = (str(latest.get('host_id')), str(latest.get('trigger_id')), latest.get('ci_uid')) == (
            '10683', '25228', 'urn:uuid:9e68f0af-8b55-4b0e-95e4-07dc02a7f6cb')
        latest = {**latest, 'mapping': {'host_name': 'GUA-LAB-SRV-WEB-001', 'computer_id': 1, 'entity_id': 0,
                                      'basis': 'Validated Phase 3 logical pilot mapping'} if pilot_mapping else None}
    pilot = z.get('pilot')
    state = 'Unavailable' if not pilot else ('Degraded' if str(pilot.get('status')) != '0' or str(pilot.get('value')) != '0' else 'Healthy')
    incidents = None
    if g.get('tickets') is not None:
        by_ticket = {str(e['glpi_ticket_id']): e for e in episodes or [] if e.get('glpi_ticket_id')}
        incidents = []
        for ticket in g['tickets']['items']:
            episode = by_ticket.get(str(ticket['id']))
            if episode or str(ticket.get('name') or '').startswith('GIOP-LAB Zabbix synthetic event ') or str(ticket.get('external_id') or '').startswith('giop:v1:'):
                incidents.append({**ticket, 'episode': episode})
    timeline = []
    for event in z.get('events', []):
        timeline.append({'timestamp': str(event.get('clock')), 'unix': True, 'source': 'Zabbix',
                         'event': 'Problem detected' if str(event.get('value')) == '1' else 'Recovery detected',
                         'reference': 'Event ' + str(event.get('eventid')), 'status': 'Severity ' + str(event.get('severity', '')), 'host': 'Pilot trigger 25228'})
    for e in episodes or []:
        timeline.append({'timestamp': e.get('problem_time'), 'source': 'Integration',
                         'event': 'Persisted Problem episode' + (' (dry-run)' if e.get('mode') == 'dry-run' else ''), 'reference': 'Event ' + str(e.get('event_id')),
                         'status': e.get('status'), 'host': 'Host ' + str(e.get('host_id')),
                         'ticket': e.get('glpi_ticket_id')})
        if e.get('recovery_time'):
            timeline.append({'timestamp': e['recovery_time'], 'source': 'Integration',
                             'event': 'Correlated Recovery' + (' (dry-run)' if e.get('mode') == 'dry-run' else ''), 'reference': 'Event ' + str(e.get('recovery_event_id')),
                             'status': e.get('status'), 'ticket': e.get('glpi_ticket_id'), 'host': 'Host ' + str(e.get('host_id'))})
        if e.get('mode') == 'live' and e.get('followup_id') and e.get('updated_at'):
            timeline.append({'timestamp': e['updated_at'], 'source': 'Integration',
                             'event': 'Recovered state persisted · Follow-up confirmed',
                             'reference': 'Follow-up ' + str(e['followup_id']),
                             'status': e.get('status'), 'ticket': e.get('glpi_ticket_id'), 'host': 'Host ' + str(e.get('host_id'))})
    for t in incidents or []:
        if t.get('date_creation'):
            timeline.append({'timestamp': t['date_creation'], 'source': 'GLPI', 'event': 'Incident created',
                             'reference': 'Ticket ' + str(t['id']), 'ticket': t['id'], 'status': t.get('status'),
                             'host': 'Synthetic LAB', 'timezone_unknown': not bool(re.search(r'Z$|[+-]\d\d:\d\d$', t['date_creation']))})
    # Ordering is performed in the browser after timestamp normalization; GLPI naive times remain explicitly labelled.
    return {**data, 'synthetic_infrastructure': {'status': state, 'basis': 'Zabbix pilot trigger only'},
            'incidents': incidents, 'timeline': timeline,
            'episode_metrics': None if episodes is None else {
                'returned': len(episodes), 'open': sum(e['status'] == 'PROBLEM_OPEN' for e in episodes),
                'awaiting_validation': sum(e['status'] == 'RECOVERED_PENDING_OPERATOR_VALIDATION' and e['mode'] == 'live' for e in episodes),
                'dry_run': sum(e['mode'] == 'dry-run' for e in episodes)},
            'latest_episode': latest}


def create_app(sources=None, ttl=15, ai_client=None, evidence_dir=None):
    app = FastAPI(title='GIOP N3 Control Center', docs_url=None, redoc_url=None)
    aggregation = Aggregator(sources, ttl)
    assistant = ai_client or AIClient()
    templates = Jinja2Templates(directory=str(ROOT / 'templates'))
    app.mount('/static', StaticFiles(directory=str(ROOT / 'static')), name='static')

    @app.exception_handler(RequestValidationError)
    async def invalid_analysis_request(request, exc):
        return JSONResponse(status_code=422, content={'status': 'AI_CONTEXT_INVALID'})

    @app.middleware('http')
    async def security_headers(request, call_next):
        response = await call_next(request)
        response.headers['Cache-Control'] = 'no-store'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'"
        return response

    @app.get('/health')
    def health():
        return {'status': 'ok', 'service': 'GIOP Control Center', 'read_only': True, 'synthetic': True}

    @app.get('/api/overview')
    def overview():
        return derive(aggregation.snapshot())

    @app.get('/api/infrastructure')
    def infrastructure():
        d = aggregation.snapshot()
        return {'updated_at': d['updated_at'], 'synthetic': True, 'zabbix': d['zabbix'],
                'glpi': {k: v for k, v in d['glpi'].items() if k != 'tickets'}}

    @app.get('/api/incidents')
    def incidents():
        d = derive(aggregation.snapshot())
        return {'updated_at': d['updated_at'], 'synthetic': True, 'status': d['glpi']['status'],
                'items': d['incidents'], 'scope': 'Integration-linked or GIOP-marked tickets in latest 100 API-visible tickets'}

    @app.get('/api/events')
    def events():
        d = aggregation.snapshot()
        return {'updated_at': d['updated_at'], 'synthetic': True, **d['integration']}

    class AnalysisRequest(BaseModel):
        model_config = ConfigDict(extra='forbid')
        ticket_id: int = Field(gt=0, strict=True)

    @app.post('/api/ai/analyze')
    def analyze_incident(request: AnalysisRequest):
        try:
            context = build_context(aggregation.snapshot(), request.ticket_id, evidence_dir)
        except Exception:
            return {'status': 'INSUFFICIENT_EVIDENCE'}
        try:
            return assistant.analyze(context)
        except Exception:
            return {'status': 'AI_UNAVAILABLE'}

    @app.get('/')
    @app.get('/infrastructure')
    @app.get('/incidents')
    @app.get('/events')
    @app.get('/runbooks')
    def page(request: Request):
        return templates.TemplateResponse(request=request, name='dashboard.html', context={'page': request.url.path.strip('/') or 'overview'})

    return app


app = create_app()
