"""Operator-local publication review. Never prints matched credential values.

Scans proposed public files and all Git-reachable blobs against local credentials
and common key signatures. This complements manual review; it is not a guarantee
against unknown, encoded or previously rotated credentials.
"""
import re
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


secrets = set()
for filename in ('.env', '.env.zabbix-alert'):
    path = ROOT / filename
    if path.exists():
        for line in path.read_text(encoding='utf-8').splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key, value = line.split('=', 1)
                value = value.strip().strip('\"\'')
                if re.search('PASSWORD|SECRET|TOKEN|CLIENT_ID', key) and value and not value.startswith('CHANGE_ME'):
                    secrets.add(value)

signatures = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bAKIA[A-Z0-9]{16}\b')


def review(data, label):
    assert not any(s.encode() in data or s.encode('utf-16-le') in data for s in secrets), f'Credential match in {label}; values withheld'
    assert not signatures.search(data), f'Credential signature in {label}'
    assert not re.search(rb'(?i)[a-z]:[\\/]Users[\\/][^\s"\']+', data), f'Personal filesystem path in {label}'


names = [n for n in git('ls-files', '-z', '--cached', '--others', '--exclude-standard').decode().split('\0') if n]
for name in names:
    assert not (name.startswith('.env') and name != '.env.example'), f'Local configuration included: {name}'
    assert not name.startswith(('artifacts/runbooks/', 'artifacts/ai-assistant/', 'artifacts/control-center/')), f'Runtime evidence included: {name}'
    assert not re.search(r'(^|/)(\.venv|__pycache__|\.pytest_cache|node_modules|\.ollama)(/|$)|\.(log|sqlite3?|db|gguf|safetensors)(?:-|$)', name), f'Runtime/model file included: {name}'
    review((ROOT / name).read_bytes(), name)

# Include historical blobs, even ones removed from the current checkout.
objects = git('rev-list', '--objects', '--all').decode().splitlines()
blobs = 0
for line in objects:
    oid, _, label = line.partition(' ')
    if git('cat-file', '-t', oid).strip() == b'blob':
        assert not (label.startswith('.env') and label != '.env.example'), f'Historical local configuration: {label}'
        assert not label.startswith(('artifacts/runbooks/', 'artifacts/ai-assistant/', 'artifacts/control-center/')), f'Historical runtime evidence: {label}'
        assert not re.search(r'(^|/)(\.venv|__pycache__|\.pytest_cache|node_modules|\.ollama)(/|$)|\.(log|sqlite3?|db|gguf|safetensors)(?:-|$)', label), f'Historical runtime/model file: {label}'
        review(git('cat-file', 'blob', oid), 'historical ' + label)
        blobs += 1

for name in ('.env', 'artifacts/runbooks/phase5-live-demo.json', 'artifacts/ai-assistant/analysis-97-ollama.json', 'artifacts/control-center/phase6-ai-analysis.png', '.ollama/models/blobs/example', 'ollama/models/blobs/example', 'data/ollama/models/example', 'models/example.gguf', 'models/example.safetensors'):
    subprocess.check_call(['git', 'check-ignore', '-q', name], cwd=ROOT)

images = list((ROOT / 'docs/assets').glob('*.png'))
expected_images = {'control-center-overview.png', 'incident-correlation.png', 'operational-runbooks.png', 'ai-analysis-ollama.png'}
public_images = {name for name in names if Path(name).suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp', '.gif'}}
assert public_images == {'docs/assets/' + name for name in expected_images}, 'Unexpected public screenshot set'
for path in images:
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    offset = 8
    while offset < len(data):
        size = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        assert kind not in (b'eXIf', b'tEXt', b'zTXt', b'iTXt'), f'Unexpected public image metadata: {path.name}'
        offset += size + 12

assert git('rev-parse', 'giop-lab-v0.6.0^{}').decode().strip() == '0f9186c9082aa16472d2d086cc49950e6d20e09f'
print(f'PASS public review: {len(names)} proposed files, {blobs} historical blobs, {len(secrets)} local credentials checked without disclosure')
print(f'PASS ignore policy and {len(images)} metadata-free public PNGs; visual content requires separate human review')
print('LIMIT: signature/known-value matching cannot prove absence of every unknown historical secret')
