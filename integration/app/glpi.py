import html
import httpx


class Glpi:
    def __init__(self, settings):
        self.settings = settings

    def post(self, path, body):
        s = self.settings
        # No retry: a lost response may already have created the remote object.
        with httpx.Client(base_url=s.glpi_url, timeout=15, follow_redirects=False) as client:
            auth = client.post('/api.php/token', data={
                'grant_type': 'password', 'scope': 'api', 'username': s.username,
                'password': s.password, 'client_id': s.client_id, 'client_secret': s.client_secret})
            auth.raise_for_status()
            token = auth.json()['access_token']
            response = client.post('/api.php/v2.3.0' + path, json=body, headers={
                'Authorization': 'Bearer ' + token, 'GLPI-Entity': '0',
                'GLPI-Entity-Recursive': 'false'})
            if response.status_code != 201:
                raise ValueError('GLPI create unconfirmed')
            object_id = response.json()['id']
            if isinstance(object_id, bool) or int(object_id) <= 0:
                raise ValueError('GLPI ID unconfirmed')
            return int(object_id)

    def create_ticket(self, event, marker):
        from .policy import CI_UID
        lines = ['SYNTHETIC LAB', f'Zabbix event ID: {event.event_id}', f'Host: {event.host}',
                 f'Trigger: {event.trigger}', f'Severity: {event.severity}',
                 f'Event time: {event.event_time.isoformat()}', f'CI UID: {CI_UID}',
                 'GLPI Computer ID: 1; Entity: 0', marker]
        return self.post('/Assistance/Ticket', {
            'name': f'GIOP-LAB Zabbix synthetic event {event.event_id}', 'type': 1,
            'external_id': marker, 'content': ''.join('<p>' + html.escape(line) + '</p>' for line in lines)})

    def add_followup(self, event, episode):
        from datetime import datetime
        duration = (event.event_time - datetime.fromisoformat(episode['problem_time'])).total_seconds()
        text = (f'SYNTHETIC LAB | Recovery event ID: {event.event_id} | '
                f'Recovery timestamp: {event.event_time.isoformat()} | Duration: {duration:g}s | '
                f'Host: {event.host} | Original event: {episode["event_id"]} | '
                f'{episode["external_marker"]}:recovery:{event.event_id}')
        return self.post(f'/Assistance/Ticket/{episode["glpi_ticket_id"]}/Timeline/Followup',
                         {'content': '<p>' + html.escape(text) + '</p>', 'is_private': False})
