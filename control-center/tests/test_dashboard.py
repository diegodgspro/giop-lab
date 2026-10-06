import json
import httpx
import pytest
from fastapi.testclient import TestClient
from app.main import create_app
from app.sources import Sources

SECRET = 'synthetic-private-credential-for-test'


class FakeSources:
    def __init__(self, failed=None):
        self.failed = failed

    def check(self, source):
        if source == self.failed:
            raise RuntimeError(SECRET)

    def zabbix(self):
        self.check('zabbix')
        return {'status': 'Healthy', 'monitored_hosts': 2, 'active_problems': 0,
                'hosts': [], 'events': [], 'pilot': {'value': '0', 'status': '0'}}

    def glpi(self):
        self.check('glpi')
        return {'status': 'Healthy', 'computers': {'items': [], 'returned': 0, 'total': None},
                'tickets': {'items': [{'id': 73, 'name': 'GIOP-LAB Zabbix synthetic event 61', 'status': 'New'}]}}

    def integration(self):
        self.check('integration')
        return {'status': 'Healthy', 'mode': 'live', 'episodes': [
            {'event_id': '61', 'host_id': '10683', 'trigger_id': '25228', 'glpi_ticket_id': 73,
             'status': 'RECOVERED_PENDING_OPERATOR_VALIDATION', 'mode': 'live',
             'problem_time': '2026-10-05T18:00:00+00:00', 'recovery_time': '2026-10-05T18:02:00+00:00'}]}


def client(failed=None):
    return TestClient(create_app(FakeSources(failed), ttl=0))


def test_health_is_local_and_read_only():
    assert client().get('/health').json()['read_only'] is True


def test_healthy_overview_correlates_actual_fixture_ids():
    data = client().get('/api/overview').json()
    assert all(data[s]['status'] == 'Healthy' for s in ('zabbix', 'glpi', 'integration'))
    assert data['zabbix']['active_problems'] == 0
    assert data['latest_episode']['event_id'] == '61'
    assert data['incidents'][0]['episode']['glpi_ticket_id'] == 73
    assert data['episode_metrics']['awaiting_validation'] == 1


@pytest.mark.parametrize('source', ['zabbix', 'glpi', 'integration'])
def test_partial_failure_never_fabricates_zero_or_exposes_exception(source):
    response = client(source).get('/api/overview')
    data = response.json()
    assert response.status_code == 200
    assert data[source]['status'] == 'Unavailable'
    assert SECRET not in response.text
    if source == 'zabbix':
        assert 'active_problems' not in data[source]
        assert data['synthetic_infrastructure']['status'] == 'Unavailable'
    if source == 'glpi':
        assert data['incidents'] is None
        assert 'computers' not in data[source]
    if source == 'integration':
        assert data['episode_metrics'] is None
        assert data['latest_episode'] is None
    for other in {'zabbix', 'glpi', 'integration'} - {source}:
        assert data[other]['status'] == 'Healthy'


def test_events_endpoint_and_missing_source():
    assert client().get('/api/events').json()['episodes'][0]['event_id'] == '61'
    failed = client('integration').get('/api/events').json()
    assert 'episodes' not in failed


def test_incidents_endpoint_and_missing_source():
    assert client().get('/api/incidents').json()['items'][0]['id'] == 73
    assert client('glpi').get('/api/incidents').json()['items'] is None


@pytest.mark.parametrize('path', ['/', '/infrastructure', '/incidents', '/events'])
def test_html_pages_render_without_credentials(path):
    response = client().get(path)
    assert response.status_code == 200
    assert 'SYNTHETIC LAB' in response.text
    assert 'Infrastructure Operations Center' in response.text
    assert SECRET not in response.text
    assert "script-src 'self'" in response.headers['content-security-policy']


def test_no_mutating_inbound_endpoints():
    c = client()
    for path in ('/api/events', '/api/incidents', '/api/overview', '/api/infrastructure'):
        assert c.post(path, json={}).status_code == 405


def test_glpi_read_adapter_projects_fields_and_verifies_total():
    calls = []
    def handler(request):
        calls.append(request)
        rows = [{'id': 128, 'name': 'Synthetic asset', 'password': SECRET, 'content': SECRET}] if request.url.params['start'] == '0' else []
        return httpx.Response(200, headers={'Content-Range': '0-99/128'}, json=rows)
    with httpx.Client(base_url='http://fixture', transport=httpx.MockTransport(handler)) as transport:
        result = Sources.collection(transport, '/Assets/Computer', {})
    assert result['total'] == 1  # metadata alone is not trusted
    assert result['returned'] == 1
    assert SECRET not in json.dumps(result)
    assert calls[0].method == 'GET'
    assert calls[0].url.params['limit'] == '100'


def test_repeated_page_does_not_become_a_fabricated_global_total():
    with httpx.Client(base_url='http://fixture', transport=httpx.MockTransport(
            lambda r: httpx.Response(200, json=[{'id': 1, 'name': 'LAB'}]))) as transport:
        with pytest.raises(ValueError, match='repeated'):
            Sources.collection(transport, '/Assistance/Ticket', {})
        with pytest.raises(ValueError):
            Sources.collection(transport, '/Administration/User', {})


def test_bounded_scan_does_not_claim_total_when_more_pages_may_exist():
    def handler(request):
        start = int(request.url.params['start'])
        return httpx.Response(200, json=[{'id': 1000 - start - n, 'name': 'Synthetic'} for n in range(100)])
    with httpx.Client(base_url='http://fixture', transport=httpx.MockTransport(handler)) as transport:
        result = Sources.collection(transport, '/Assets/Computer', {})
    assert result['total'] is None
    assert result['pages_checked'] == 5
    assert result['returned'] == 500
    assert 'incomplete' in result['count_label']


def test_soft_deleted_computers_are_excluded_across_pages_and_routes():
    rows = [{'id': n, 'name': f'Synthetic LAB {n}', 'is_deleted': n <= 54}
            for n in range(182, 0, -1)]
    calls = []
    def handler(request):
        calls.append(request)
        selected = rows
        if request.url.params.get('filter') == 'is_deleted==false':
            selected = [r for r in rows if not r['is_deleted']]
        start = int(request.url.params['start'])
        return httpx.Response(200, json=selected[start:start + 100])
    with httpx.Client(base_url='http://fixture', transport=httpx.MockTransport(handler)) as transport:
        result = Sources.collection(transport, '/Assets/Computer', {})
    assert result['total'] == result['returned'] == 128
    assert result['pages_checked'] == 3
    assert [int(r.url.params['start']) for r in calls] == [0, 100, 128]
    assert all(r.url.params['filter'] == 'is_deleted==false' for r in calls)
    assert all(r.url.params['limit'] == '100' and r.url.params['sort'] == 'id:desc' for r in calls)
    assert {r['id'] for r in result['items']} == set(range(55, 183))
    class InventorySources(FakeSources):
        def glpi(self):
            return {**super().glpi(), 'computers': result}
    c = TestClient(create_app(InventorySources(), ttl=0))
    for route in ('/api/overview', '/api/infrastructure'):
        computers = c.get(route).json()['glpi']['computers']
        assert computers['total'] == len(computers['items']) == 128
        assert all(r['id'] > 54 for r in computers['items'])


@pytest.mark.parametrize('path', ['/Assets/NetworkEquipment', '/Assistance/Ticket'])
def test_other_collections_keep_existing_query(path):
    calls = []
    def handler(request):
        calls.append(request)
        return httpx.Response(200, json=[])
    with httpx.Client(base_url='http://fixture', transport=httpx.MockTransport(handler)) as transport:
        Sources.collection(transport, path, {})
    assert dict(calls[0].url.params) == {'start': '0', 'limit': '100', 'sort': 'id:desc'}
