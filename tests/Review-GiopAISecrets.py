"""Operator-local Phase 6 review; never part of the AI execution pipeline."""
import ast
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
names = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).decode().split('\0')
paths = [root / name for name in names if name]
for folder in ('artifacts/runbooks', 'artifacts/ai-assistant'):
    paths.extend(p for p in (root / folder).rglob('*') if p.is_file() and p.suffix in ('.json', '.md', '.txt'))
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
    assert not any(value.encode() in data or value.encode('utf-16-le') in data for value in secrets), f'Credential match: {path.relative_to(root)}'
    assert not re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bAKIA[A-Z0-9]{16}\b', data), f'Credential signature: {path.relative_to(root)}'
baseline = '385ef17cca4abdbd38e3e3aa24bcbfef2c12ff3a'
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root).decode().strip() == baseline
assert subprocess.check_output(['git', 'rev-parse', 'giop-lab-v0.5.0^{}'], cwd=root).decode().strip() == baseline
assert subprocess.check_output(['git', 'rev-parse', 'giop-lab-v0.4.0^{}'], cwd=root).decode().strip() == '42e3cbab9758624dfe3be42459f6931ae3519197'
assert subprocess.check_output(['git', 'branch', '--show-current'], cwd=root).decode().strip() == 'phase/6-ai-incident-analysis'
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=root)
assert not subprocess.check_output(['git', 'diff', baseline, '--', 'integration', 'scripts/lib', 'scripts/runbooks', 'docker/docker-compose.yml', 'control-center/app/sources.py'], cwd=root)
for name in filter(None, names):
    assert not (name.startswith('.env') and name != '.env.example'), f'Runtime config included: {name}'
    assert not name.startswith(('artifacts/runbooks/', 'artifacts/ai-assistant/', 'artifacts/control-center/')), f'Runtime evidence included: {name}'
    assert not re.search(r'(^|/)(\.venv|__pycache__|\.pytest_cache)(/|$)|\.(log|sqlite3?|db)(?:-|$)', name), f'Runtime file included: {name}'
for name in ('.env', 'artifacts/ai-assistant/evidence/97.json', 'artifacts/runbooks/phase5-live-demo.json'):
    subprocess.check_call(['git', 'check-ignore', '-q', name], cwd=root)
for path in (root / 'ai-assistant/app').glob('*.py'):
    tree = ast.parse(path.read_text(encoding='utf-8'))
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            modules = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or '']
            assert not any(m.split('.')[0] in ('subprocess', 'docker', 'socket', 'paramiko') for m in modules), 'Execution/host-control module in AI runtime'
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            assert node.func.id not in ('eval', 'exec'), 'Dynamic execution in AI runtime'
container = json.loads(subprocess.check_output(['docker', 'inspect', 'giop-lab-control-center-ai-assistant-1'], cwd=root))[0]
environment = container['Config']['Env']
assert not any(value in '\n'.join(environment) for value in secrets), 'AI container received infrastructure credential'
assert not any(re.search('PASSWORD|TOKEN|SECRET|CLIENT_ID', setting.split('=', 1)[0]) for setting in environment), 'Credential environment key in AI container'
assert set(container['NetworkSettings']['Networks']) == {'giop-lab-ai-analysis'}
assert not container['HostConfig']['Privileged'] and container['HostConfig']['ReadonlyRootfs']
assert not container['HostConfig']['PortBindings'] and not container['Mounts']
assert container['Config']['User'] == '10003'
print(f'PASS secret review: {len(paths)} files, {len(secrets)} known credentials; no values disclosed')
print('PASS frozen baseline/tags, unchanged infrastructure/runbooks/aggregation, no staged/runtime files, ignored evidence')
print('PASS AI runtime: no execution imports, credentials, infrastructure networks, host mounts, public ports or privilege')
