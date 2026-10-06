"""Compare known local credentials without disclosing them; verify Phase 5 boundaries."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
names = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).decode().split('\0')
paths = [root / name for name in names if name]
paths += [p for p in (root / 'artifacts/runbooks').rglob('*') if p.is_file() and p.suffix in ('.json', '.md', '.txt')]
secrets = set()
for name in ('.env', '.env.zabbix-alert'):
    path = root / name
    if path.exists():
        for line in path.read_text(encoding='utf-8').splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key, value = line.split('=', 1)
                value = value.strip().strip('"\'')
                if re.search('PASSWORD|SECRET|TOKEN|CLIENT_ID', key) and value and not value.startswith('CHANGE_ME'):
                    secrets.add(value)
for path in paths:
    data = path.read_bytes()
    assert not any(value.encode() in data for value in secrets), f'Credential match: {path.relative_to(root)}'
    assert not re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bAKIA[A-Z0-9]{16}\b', data), f'Credential signature: {path.relative_to(root)}'
baseline = '42e3cbab9758624dfe3be42459f6931ae3519197'
assert subprocess.check_output(['git', 'rev-parse', 'giop-lab-v0.4.0^{}'], cwd=root).decode().strip() == baseline
subprocess.check_call(['git', 'merge-base', '--is-ancestor', baseline, 'HEAD'], cwd=root)
assert subprocess.check_output(['git', 'branch', '--show-current'], cwd=root).decode().strip() == 'phase/5-operational-runbooks'
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
for name in filter(None, tracked):
    assert not (name.startswith('.env') and name != '.env.example'), f'Runtime configuration tracked: {name}'
    assert not name.startswith(('artifacts/runbooks/', 'artifacts/control-center/')), f'Runtime evidence tracked: {name}'
    assert not re.search(r'(^|/)(\.venv|__pycache__|\.pytest_cache)(/|$)|\.(log|sqlite3?|db)(?:-|$)', name), f'Runtime file tracked: {name}'
assert not subprocess.check_output(['git', 'diff', baseline, '--', 'integration', 'docker', 'control-center/app/sources.py'], cwd=root)
for name in ('.env', 'artifacts/runbooks/phase5-live-demo.json'):
    subprocess.check_call(['git', 'check-ignore', '-q', name], cwd=root)
print(f'PASS secret scan: {len(paths)} files, {len(secrets)} distinct local credentials; no values disclosed')
print('PASS frozen v0.4.0 tag/ancestry, Phase 5 branch, unchanged Integration/Compose/aggregation, no tracked runtime configuration/evidence/logs/caches')
