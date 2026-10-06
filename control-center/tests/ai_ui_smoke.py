"""Deterministic browser validation against the explicitly enabled fixture service."""
from pathlib import Path
import copy
import json
import re
from playwright.sync_api import sync_playwright, expect

root = Path(__file__).resolve().parents[2]
out = root / 'artifacts/control-center'
out.mkdir(parents=True, exist_ok=True)
secrets = []
for name in ('.env', '.env.zabbix-alert'):
    path = root / name
    if path.exists():
        for line in path.read_text(encoding='utf-8').splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key, value = line.split('=', 1)
                value = value.strip().strip('"\'')
                if re.search('PASSWORD|TOKEN|SECRET|CLIENT_ID', key) and len(value) >= 8 and not value.startswith('CHANGE_ME'):
                    secrets.append(value)

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={'width': 1440, 'height': 1120}, device_scale_factor=1)
    calls, errors = [], []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('request', lambda request: calls.append(request) if request.url.endswith('/api/ai/analyze') else None)
    page.goto('http://127.0.0.1:8091/')
    expect(page.locator('#updated')).to_contain_text('Last updated:', timeout=30000)
    assert not calls
    page.locator('#ai-ticket').select_option('97')
    with page.expect_response('**/api/ai/analyze', timeout=60000) as received:
        page.locator('#ai-analyze').click()
    result = received.value.json()
    assert result['status'] == 'SUCCESS' and result['fixture'] is True
    expect(page.locator('.ai-fixture')).to_contain_text('not a language model')
    expect(page.locator('.ai-confidence')).to_have_text('88%')
    expect(page.locator('.ai-runbook')).to_contain_text('RB-OPS-003')
    expect(page.locator('.ai-risk')).to_contain_text('low')
    expect(page.locator('.ai-approval')).to_contain_text('Operator approval required')
    assert page.locator('.ai-observed li').count() == 7
    assert 'historical incident' in page.locator('#ai-result').inner_text()
    assert 'current snapshot' in page.locator('#ai-result').inner_text()
    assert 'INFERRED' in page.locator('#ai-result').inner_text() and 'UNKNOWN' in page.locator('#ai-result').inner_text()
    assert not page.get_by_role('button', name='Execute', exact=True).count()
    assert not page.locator('#fetch-warning').is_visible()
    for request in calls:
        assert set(request.post_data_json) == {'ticket_id'} and request.post_data_json['ticket_id'] == 97
    for secret in secrets:
        assert secret not in page.content() and secret not in json.dumps(result)
    out_ai = root / 'artifacts/ai-assistant'
    out_ai.mkdir(parents=True, exist_ok=True)
    (out_ai / 'analysis-97.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    page.locator('#ai-panel').screenshot(path=str(out / 'phase6-ai-analysis.png'))
    page.screenshot(path=str(out / 'phase6-overview.png'), full_page=True)
    print('PASS historical synthetic Ticket 97: observed/inferred/unknown, 88%, RB-OPS-003, low risk, explicit approval, fixture disclosure')
    with page.expect_response('**/api/ai/analyze', timeout=60000) as repeated:
        page.locator('#ai-analyze').click()
    assert repeated.value.json()['cached'] is True
    count = len(calls)
    page.reload()
    expect(page.locator('#updated')).to_contain_text('Last updated:', timeout=30000)
    assert len(calls) == count
    print('PASS stable analysis cache; page reload does not invoke AI')
    for status, label in [('AI_UNAVAILABLE', 'Unavailable'), ('AI_ANALYSIS_INVALID', 'AI analysis invalid'), ('INSUFFICIENT_EVIDENCE', 'Insufficient evidence')]:
        page.route('**/api/ai/analyze', lambda route: route.fulfill(json={'status': status}))
        page.locator('#ai-analyze').click()
        expect(page.locator('.ai-unavailable strong')).to_have_text(label)
        assert not page.locator('#fetch-warning').is_visible()
        expect(page.locator('.metric').nth(2).locator('.metric-value')).to_have_text('128')
        page.unroute('**/api/ai/analyze')
        print('PASS isolated AI failure rendering:', status)
    hostile = copy.deepcopy(result)
    hostile['analysis']['summary'] = '<img id="injected" src="x" onerror="alert(1)"> Untrusted text'
    page.route('**/api/ai/analyze', lambda route: route.fulfill(json=hostile))
    page.locator('#ai-analyze').click()
    expect(page.locator('.ai-summary')).to_contain_text('Untrusted text')
    assert not page.locator('#injected').count()
    page.unroute('**/api/ai/analyze')
    print('PASS untrusted model prose rendered as escaped text')
    for width in (320, 390, 540, 768):
        page.set_viewport_size({'width': width, 'height': 844})
        with page.expect_response('**/api/ai/analyze', timeout=60000):
            page.locator('#ai-analyze').click()
        expect(page.locator('.ai-approval')).to_contain_text('Operator approval required')
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
        for secret in secrets:
            assert secret not in page.content()
        if width == 390:
            page.locator('#ai-panel').screenshot(path=str(out / 'phase6-ai-analysis-mobile.png'))
        print('PASS responsive AI component:', width)
    assert not errors, 'JavaScript errors occurred'
    browser.close()
    print('PASS advisory-only UI; screenshots:', out)
