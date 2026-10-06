import os
from dataclasses import dataclass


@dataclass
class Settings:
    mode: str = 'dry-run'
    database: str = '/data/integration.sqlite3'
    secret: str = ''
    glpi_url: str = 'http://glpi'
    username: str = ''
    password: str = ''
    client_id: str = ''
    client_secret: str = ''

    @classmethod
    def from_env(cls):
        return cls(**{field: os.getenv(key, default) for field, key, default in [
            ('mode', 'GIOP_INTEGRATION_MODE', 'dry-run'),
            ('database', 'GIOP_SQLITE_PATH', '/data/integration.sqlite3'),
            ('secret', 'GIOP_WEBHOOK_SECRET', ''),
            ('glpi_url', 'GIOP_GLPI_URL', 'http://glpi'),
            ('username', 'GLPI_INTEGRATION_USERNAME', ''),
            ('password', 'GLPI_INTEGRATION_PASSWORD', ''),
            ('client_id', 'GLPI_INTEGRATION_OAUTH_CLIENT_ID', ''),
            ('client_secret', 'GLPI_INTEGRATION_OAUTH_CLIENT_SECRET', '')]})

    def validate(self):
        if self.mode not in ('dry-run', 'live') or len(self.secret) < 32:
            raise ValueError('Invalid mode or webhook secret (minimum 32 characters)')
        if self.mode == 'live' and not all((self.username, self.password, self.client_id, self.client_secret)):
            raise ValueError('Dedicated GLPI credentials required for live mode')
