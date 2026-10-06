from datetime import datetime, timezone, timedelta
from concurrent.futures import ThreadPoolExecutor
from fastapi.testclient import TestClient
from app.config import Settings
from app.main import create_app
from app.policy import HOST, TRIGGER

SECRET = 'test-only-shared-secret-32-characters'
HEADERS = {'X-GIOP-Webhook-Secret': SECRET}


class FakeGlpi:
    def __init__(self):
        self.tickets = 0
        self.followups = 0

    def create_ticket(self, event, marker):
        self.tickets += 1
        return 123

    def add_followup(self, event, episode):
        self.followups += 1
        assert episode['glpi_ticket_id'] == 123
        return 456


def payload(kind='PROBLEM'):
    data = dict(kind=kind, event_id='900001', host_id='10683', trigger_id='25228',
                host=HOST, trigger=TRIGGER, severity=3,
                event_time=datetime.now(timezone.utc).isoformat())
    if kind == 'RECOVERY':
        data.update(event_id='900002', problem_event_id='900001',
                    event_time=(datetime.now(timezone.utc) + timedelta(seconds=60)).isoformat())
    return data


def client(path, mode='live', glpi=None):
    return TestClient(create_app(Settings(mode=mode, database=str(path), secret=SECRET,
                                         username='dedicated', password='test', client_id='test', client_secret='test'), glpi))


def send(c, data):
    return c.post('/api/v1/zabbix/events', json=data, headers=HEADERS)


def test_problem_duplicate_recovery_duplicate_restart(tmp_path):
    api = FakeGlpi()
    path = tmp_path / 'state.sqlite3'
    with client(path, glpi=api) as c:
        first = send(c, payload())
        assert first.status_code == 202
        assert first.json()['episode']['glpi_ticket_id'] == 123
        assert send(c, payload()).json()['decision'] == 'duplicate'
        assert send(c, payload('RECOVERY')).json()['episode']['status'] == 'RECOVERED_PENDING_OPERATOR_VALIDATION'
        assert send(c, payload('RECOVERY')).json()['decision'] == 'duplicate'
    with client(path, glpi=api) as c:
        assert send(c, payload()).json()['decision'] == 'duplicate'
        assert send(c, payload('RECOVERY')).json()['decision'] == 'duplicate'
    assert (api.tickets, api.followups) == (1, 1)


def test_unknown_malformed_auth_size_content_type(tmp_path):
    api = FakeGlpi()
    with client(tmp_path / 'state', glpi=api) as c:
        unknown = payload(); unknown['trigger_id'] = '999'
        assert send(c, unknown).json()['decision'] == 'ignored'
        assert send(c, {}).status_code == 422
        assert c.post('/api/v1/zabbix/events', json=payload()).status_code == 401
        assert c.post('/api/v1/zabbix/events', content='{}', headers=HEADERS).status_code == 415
        assert c.post('/api/v1/zabbix/events', content='x' * 32769,
                      headers={**HEADERS, 'Content-Type': 'application/json'}).status_code == 413
    assert api.tickets == 0


def test_dry_run_never_writes(tmp_path):
    api = FakeGlpi()
    with client(tmp_path / 'state', mode='dry-run', glpi=api) as c:
        assert send(c, payload()).json()['episode']['status'] == 'DRY_RUN_PROBLEM'
        assert send(c, payload('RECOVERY')).status_code == 202
        assert c.get('/health').json()['database'] == 'ok'
    assert (api.tickets, api.followups) == (0, 0)


def test_uncertain_write_never_retries(tmp_path):
    class LostResponse(FakeGlpi):
        def create_ticket(self, event, marker):
            self.tickets += 1
            raise TimeoutError()
    api = LostResponse()
    with client(tmp_path / 'state', glpi=api) as c:
        assert send(c, payload()).status_code == 502
        assert send(c, payload()).json()['episode']['status'] == 'OPERATOR_RECONCILIATION_REQUIRED'
    assert api.tickets == 1


def test_concurrent_duplicate(tmp_path):
    api = FakeGlpi()
    with client(tmp_path / 'state', glpi=api) as c:
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: send(c, payload()), range(8)))
        assert all(r.status_code == 202 for r in results)
    assert api.tickets == 1


def test_recovery_before_problem(tmp_path):
    with client(tmp_path / 'state', glpi=FakeGlpi()) as c:
        assert send(c, payload('RECOVERY')).status_code == 409
