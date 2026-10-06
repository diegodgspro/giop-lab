import hmac
import json
import logging
import threading
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Request
from pydantic import ValidationError
from .config import Settings
from .glpi import Glpi
from .models import Store
from .policy import CI_UID, eligible
from .zabbix import Event

log = logging.getLogger('giop')
logging.basicConfig(level=logging.INFO, format='%(levelname)s %(name)s %(message)s')
# Third-party HTTP logs must never emit credential-bearing requests.
logging.getLogger('httpx').setLevel(logging.WARNING)


def create_app(settings=None, glpi=None):
    lock = threading.Lock()

    @asynccontextmanager
    async def lifespan(app):
        app.state.settings = settings or Settings.from_env()
        app.state.settings.validate()
        app.state.store = Store(app.state.settings.database)
        app.state.glpi = glpi or Glpi(app.state.settings)
        yield

    app = FastAPI(title='GIOP Integration MVP', lifespan=lifespan)

    def authenticate(request):
        if not hmac.compare_digest(request.headers.get('X-GIOP-Webhook-Secret', '').encode(),
                                   app.state.settings.secret.encode()):
            raise HTTPException(401, 'Invalid webhook authentication')

    @app.get('/health')
    def health():
        with app.state.store.connect() as db:
            db.execute('SELECT 1')
        return {'status': 'ok', 'mode': app.state.settings.mode, 'database': 'ok',
                'glpi_reachability': 'not_checked'}

    @app.get('/api/v1/episodes')
    def episodes(request: Request):
        authenticate(request)
        with app.state.store.connect() as db:
            return [dict(row) for row in db.execute('SELECT * FROM episodes ORDER BY created_at DESC LIMIT 100')]

    def process(event):
        store = app.state.store
        mode = app.state.settings.mode
        now = datetime.now(timezone.utc).isoformat()
        if not eligible(event):
            log.info('Ignored event outside pilot allowlist')
            return {'decision': 'ignored', 'reason': 'outside_pilot_allowlist'}
        with lock:
            original = event.event_id if event.kind == 'PROBLEM' else event.problem_event_id
            episode = store.get(original)
            if event.kind == 'PROBLEM':
                if episode:
                    return {'decision': 'duplicate', 'episode': episode}
                marker = f'giop:v1:de2ee010-9022-4a17-94e9-e1615289fc86:problem:{original}'
                with store.connect() as db:
                    db.execute('''INSERT INTO episodes
                        (event_id,trigger_id,host_id,ci_uid,external_marker,problem_time,status,mode,created_at,updated_at)
                        VALUES (?,?,?,?,?,?,?,?,?,?)''', (original, event.trigger_id, event.host_id, CI_UID,
                        marker, event.event_time.isoformat(), 'DRY_RUN_PROBLEM' if mode == 'dry-run' else
                        'TICKET_CREATE_PENDING', mode, now, now))
                if mode == 'dry-run':
                    log.info('Dry-run: would create pilot Incident event=%s', original)
                else:
                    try:
                        ticket = app.state.glpi.create_ticket(event, marker)
                        store.update(original, glpi_ticket_id=ticket, status='PROBLEM_OPEN', updated_at=now)
                    except Exception:
                        store.update(original, status='OPERATOR_RECONCILIATION_REQUIRED', updated_at=now)
                        raise HTTPException(502, 'GLPI outcome unconfirmed; operator reconciliation required') from None
            else:
                if not episode:
                    raise HTTPException(409, 'Original PROBLEM not found; deliver PROBLEM first')
                if episode['recovery_event_id']:
                    if episode['recovery_event_id'] != event.event_id:
                        raise HTTPException(409, 'Episode already has a different Recovery')
                    return {'decision': 'duplicate', 'episode': episode}
                if event.event_time < datetime.fromisoformat(episode['problem_time']):
                    raise HTTPException(422, 'Recovery precedes PROBLEM')
                if mode != episode['mode']:
                    raise HTTPException(409, 'Episode mode differs; use a new event for live demonstration')
                if mode == 'live' and episode['status'] != 'PROBLEM_OPEN':
                    raise HTTPException(409, 'Ticket outcome requires operator reconciliation')
                store.update(original, recovery_event_id=event.event_id,
                             recovery_time=event.event_time.isoformat(), status='FOLLOWUP_CREATE_PENDING', updated_at=now)
                if mode == 'dry-run':
                    log.info('Dry-run: would add public Recovery follow-up event=%s', original)
                else:
                    try:
                        followup = app.state.glpi.add_followup(event, episode)
                        store.update(original, followup_id=followup)
                    except Exception:
                        store.update(original, status='OPERATOR_RECONCILIATION_REQUIRED', updated_at=now)
                        raise HTTPException(502, 'GLPI outcome unconfirmed; operator reconciliation required') from None
                store.update(original, status='RECOVERED_PENDING_OPERATOR_VALIDATION', updated_at=now)
            return {'decision': 'processed', 'episode': store.get(original)}

    @app.post('/api/v1/zabbix/events', status_code=202)
    async def receive(request: Request):
        authenticate(request)
        if request.headers.get('content-type', '').split(';')[0].strip().lower() != 'application/json':
            raise HTTPException(415, 'Content-Type must be application/json')
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > 32768:
                raise HTTPException(413, 'Maximum request size is 32 KiB')
        try:
            event = Event.model_validate(json.loads(body))
        except (ValidationError, ValueError, UnicodeDecodeError):
            raise HTTPException(422, 'Malformed event payload') from None
        from starlette.concurrency import run_in_threadpool
        return await run_in_threadpool(process, event)

    return app


app = create_app()
