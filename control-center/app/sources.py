"""Explicit outbound read allowlists; authentication POSTs are the sole exceptions."""
import os
from datetime import datetime, timezone
import httpx


def stamp():
    return datetime.now(timezone.utc).isoformat()


def label(value):
    if isinstance(value, dict):
        return value.get('name') or value.get('id')
    return value


class Sources:
    def __init__(self):
        self.zurl = os.getenv('CC_ZABBIX_URL', 'http://zabbix-web:8080/api_jsonrpc.php')
        self.gurl = os.getenv('CC_GLPI_URL', 'http://glpi')
        self.iurl = os.getenv('CC_INTEGRATION_URL', 'http://integration:8090')

    def zabbix(self):
        with httpx.Client(timeout=5, follow_redirects=False) as client:
            token = os.getenv('CC_ZABBIX_TOKEN', '')
            def rpc(method, params):
                if method not in ('apiinfo.version', 'user.login', 'user.logout', 'host.get', 'problem.get', 'trigger.get', 'event.get'):
                    raise ValueError('Read-only method required')
                body = dict(jsonrpc='2.0', id=1, method=method, params=params)
                if token and method not in ('apiinfo.version', 'user.login'):
                    body['auth'] = token
                response = client.post(self.zurl, json=body)
                response.raise_for_status()
                data = response.json()
                if 'error' in data or 'result' not in data:
                    raise ValueError('Zabbix read failed')
                return data['result']
            version = rpc('apiinfo.version', {})
            logged_in = not token
            if logged_in:
                token = rpc('user.login', {'username': os.getenv('CC_ZABBIX_USERNAME', 'Admin'),
                                          'password': os.getenv('CC_ZABBIX_PASSWORD', '')})
            try:
                hosts = rpc('host.get', {'output': ['hostid', 'host', 'name', 'status', 'active_available'],
                                        'filter': {'status': '0'}, 'sortfield': 'hostid', 'limit': 100})
                count = int(rpc('host.get', {'countOutput': True, 'filter': {'status': '0'}}))
                problems = int(rpc('problem.get', {'countOutput': True, 'source': 0, 'object': 0,
                                                  'recent': False}))
                triggers = rpc('trigger.get', {'triggerids': ['25228'], 'output': ['triggerid', 'description', 'value', 'status', 'lastchange', 'priority']})
                events = rpc('event.get', {'source': 0, 'object': 0, 'objectids': ['25228'],
                                          'output': ['eventid', 'clock', 'name', 'value', 'severity'],
                                          'sortfield': 'eventid', 'sortorder': 'DESC', 'limit': 8})
                return {'status': 'Healthy', 'checked_at': stamp(), 'version': version,
                        'monitored_hosts': count, 'active_problems': problems, 'hosts': hosts,
                        'pilot': triggers[0] if triggers else None, 'events': events,
                        'scope': 'API-visible hosts/problems; host listing capped at 100'}
            finally:
                if logged_in:
                    try:
                        rpc('user.logout', {})
                    except Exception:
                        pass

    def glpi(self):
        with httpx.Client(base_url=self.gurl, timeout=5, follow_redirects=False) as client:
            response = client.post('/api.php/token', data={
                'grant_type': 'password', 'scope': 'api',
                'username': os.getenv('CC_GLPI_USERNAME', ''), 'password': os.getenv('CC_GLPI_PASSWORD', ''),
                'client_id': os.getenv('CC_GLPI_CLIENT_ID', ''), 'client_secret': os.getenv('CC_GLPI_CLIENT_SECRET', '')})
            response.raise_for_status()
            headers = {'Authorization': 'Bearer ' + response.json()['access_token'],
                       'GLPI-Entity': '0', 'GLPI-Entity-Recursive': 'false'}
            result = {'status': 'Healthy', 'checked_at': stamp(), 'scope': 'API-visible entity 0; non-deleted Computers; other listings capped at 100'}
            for key, path in [('computers', '/Assets/Computer'), ('network', '/Assets/NetworkEquipment'),
                              ('tickets', '/Assistance/Ticket')]:
                try:
                    data = self.collection(client, path, headers)
                    result[key] = data
                except Exception:
                    result[key] = None
                    result['status'] = 'Degraded'
            return result

    @staticmethod
    def collection(client, path, headers):
        if path not in ('/Assets/Computer', '/Assets/NetworkEquipment', '/Assistance/Ticket'):
            raise ValueError('Read-only resource required')
        seen = set()
        all_rows = []
        total = None
        pages = 0
        # Do not trust Content-Range alone as a proven count. A bounded scan must reach an empty
        # page with strictly descending, unique IDs before claiming a total.
        params = {'limit': 100, 'sort': 'id:desc'}
        if path == '/Assets/Computer':
            params['filter'] = 'is_deleted==false'
        for page in range(5):
            response = client.get('/api.php/v2.3.0' + path, headers=headers,
                                  params={**params, 'start': len(all_rows)})
            response.raise_for_status()
            rows = response.json()
            if isinstance(rows, dict):
                containers = [rows[k] for k in ('items', 'collection', 'results') if k in rows]
                if len(containers) != 1:
                    raise ValueError('Unknown collection shape')
                rows = containers[0]
            if not isinstance(rows, list) or len(rows) > 100 or any(not isinstance(r, dict) or not r.get('id') for r in rows):
                raise ValueError('Unknown collection shape')
            pages += 1
            if not rows:
                total = len(all_rows)
                break
            previous = int(all_rows[-1]['id']) if all_rows else None
            for record in rows:
                identity = int(record['id'])
                if identity in seen or (previous is not None and identity >= previous):
                    raise ValueError('Collection repeated, overlapping or out of order')
                seen.add(identity)
                previous = identity
            all_rows.extend(rows)
        fields = ('id', 'name', 'status', 'priority', 'location', 'date_creation', 'date_mod', 'external_id')
        display_limit = 500 if path == '/Assets/Computer' else 100
        displayed = all_rows[:display_limit]
        return {'items': [{k: label(r.get(k)) for k in fields} for r in displayed],
                'total': total, 'returned': len(displayed), 'limit': display_limit, 'pages_checked': pages,
                'count_label': ('Non-deleted API-visible enumerated total' if path == '/Assets/Computer' else 'API-visible enumerated total') if total is not None else f'Records shown (up to {display_limit}; scan incomplete)'}

    def integration(self):
        with httpx.Client(base_url=self.iurl, timeout=5, follow_redirects=False) as client:
            health = client.get('/health')
            health.raise_for_status()
            data = health.json()
            response = client.get('/api/v1/episodes', headers={'X-GIOP-Webhook-Secret': os.getenv('CC_WEBHOOK_SECRET', '')})
            response.raise_for_status()
            episodes = response.json()
            if not isinstance(episodes, list):
                raise ValueError('Unknown episode shape')
            fields = ('event_id', 'trigger_id', 'host_id', 'ci_uid', 'glpi_ticket_id', 'problem_time',
                      'recovery_event_id', 'recovery_time', 'status', 'mode', 'followup_id', 'created_at', 'updated_at')
            return {'status': 'Healthy' if data.get('status') == 'ok' and data.get('database') == 'ok' else 'Degraded',
                    'checked_at': stamp(), 'mode': data.get('mode'),
                    'episodes': [{k: e.get(k) for k in fields} for e in episodes],
                    'scope': 'Latest 100 persisted episodes; window counts, not lifetime totals', 'limit': 100}
