import sqlite3
from pathlib import Path


class Store:
    def __init__(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.path = path
        with self.connect() as db:
            db.executescript('''
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS episodes (
                    event_id TEXT PRIMARY KEY, trigger_id TEXT NOT NULL,
                    host_id TEXT NOT NULL, ci_uid TEXT NOT NULL,
                    glpi_ticket_id INTEGER, external_marker TEXT NOT NULL UNIQUE,
                    problem_time TEXT NOT NULL, recovery_event_id TEXT UNIQUE,
                    recovery_time TEXT, status TEXT NOT NULL, mode TEXT NOT NULL,
                    followup_id INTEGER, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
                );
            ''')

    def connect(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        return db

    def get(self, event_id):
        with self.connect() as db:
            row = db.execute('SELECT * FROM episodes WHERE event_id=?', (event_id,)).fetchone()
            return dict(row) if row else None

    def update(self, event_id, **values):
        with self.connect() as db:
            db.execute('UPDATE episodes SET ' + ','.join(f'{key}=?' for key in values) + ' WHERE event_id=?',
                       (*values.values(), event_id))
