"""Optional isolated headless-browser smoke check against the running local LAB.

Run from control-center after installing playwright and its Chromium test browser.
This is a development check, not a runtime dashboard dependency.
"""
from pathlib import Path
import re
from playwright.sync_api import sync_playwright, expect

root = Path(__file__).resolve().parents[2]
out = root / 'artifacts' / 'control-center'
out.mkdir(parents=True, exist_ok=True)
secrets = []
for name in ('.env', '.env.zabbix-alert'):
    path = root / name
    if path.exists():
        for line in path.read_text(encoding='utf-8').splitlines():
            if '=' not in line or line.lstrip().startswith('#'):
                continue
            key, value = line.split('=', 1)
            value = value.strip().strip('"\'')
            if re.search('PASSWORD|TOKEN|SECRET|CLIENT_ID', key) and len(value) >= 8 and not value.startswith('CHANGE_ME'):
                secrets.append(value)

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={'width': 1440, 'height': 1120}, device_scale_factor=1)
    errors = []
    navigations = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('framenavigated', lambda frame: navigations.append(frame.url))
    for route in ('/', '/infrastructure', '/incidents', '/events'):
        response = page.goto('http://127.0.0.1:8091' + route)
        assert response.status == 200
        expect(page.locator('#updated')).to_contain_text('Last updated:', timeout=30000)
        assert not page.locator('#fetch-warning').is_visible()
        assert 'SYNTHETIC LAB' in page.inner_text('body')
        for secret in secrets:
            assert secret not in page.content(), 'Local credential exposed in DOM'
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
        print('PASS desktop:', route)
        if route == '/infrastructure':
            computers = page.request.get('http://127.0.0.1:8091/api/infrastructure').json()['glpi']['computers']
            assert computers['total'] == computers['returned'] == len(computers['items']) == 128
            assert computers['pages_checked'] == 3
            assert page.locator('#detail-body table').nth(1).locator('tbody tr').count() == 128
            print('PASS Infrastructure: 128 active Computers rendered')
        if route == '/':
            live = page.request.get('http://127.0.0.1:8091/api/overview').json()
            assert live['glpi']['computers']['total'] == 128
            assert live['glpi']['network']['total'] == 51
            assert live['glpi']['tickets']['total'] == 95
            e = live['latest_episode']
            assert (str(e['event_id']), e['glpi_ticket_id'], str(e['recovery_event_id']), e['followup_id']) == ('37', 95, '38', 2)
            expect(page.locator('.metric').nth(2).locator('.metric-value')).to_have_text('128')
            print('PASS live KPI/counts and Event 37 -> Ticket 95 -> Recovery 38 -> Follow-up 2')
            page.screenshot(path=str(out / 'phase4-overview.png'), full_page=True)
            before = page.locator('#updated').inner_text()
            navigation_count = len(navigations)
            expect(page.locator('#updated')).not_to_have_text(before, timeout=45000)
            assert len(navigations) == navigation_count
            print('PASS auto-refresh without full page navigation')
    for endpoint in ('/health', '/api/overview', '/api/infrastructure', '/api/incidents', '/api/events'):
        response = page.request.get('http://127.0.0.1:8091' + endpoint)
        assert response.status == 200
        for secret in secrets:
            assert secret not in response.text(), 'Local credential exposed in API'
        print('PASS live endpoint and secret check:', endpoint)
    for width in (320, 390, 540, 768):
        page.set_viewport_size({'width': width, 'height': 844})
        page.goto('http://127.0.0.1:8091/')
        expect(page.locator('#updated')).to_contain_text('Last updated:', timeout=30000)
        assert not page.locator('.sidebar').is_visible()
        assert page.locator('.mobile-menu').is_visible()
        assert page.locator('.correlation-row').count() == 6
        columns = page.locator('.metric-grid').evaluate('e => getComputedStyle(e).gridTemplateColumns.split(" ").length')
        assert columns == (1 if width < 460 else 2)
        identifier = page.locator('.technical-id').first
        assert identifier.get_attribute('title') == identifier.get_attribute('aria-label')
        assert chr(8230) in identifier.inner_text()
        assert identifier.evaluate('e => e.scrollWidth <= e.clientWidth || e.getBoundingClientRect().right <= window.innerWidth')
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
        page.locator('.mobile-menu summary').click()
        for label, route in [('Overview', '/'), ('Infrastructure', '/infrastructure'), ('Incidents', '/incidents'), ('Event correlation', '/events')]:
            link = page.locator('.mobile-menu nav').get_by_role('link', name=label, exact=True)
            expect(link).to_be_visible()
            assert link.get_attribute('href') == route
        page.locator('.mobile-menu nav').get_by_role('link', name='Infrastructure', exact=True).click()
        expect(page.locator('#updated')).to_contain_text('Last updated:', timeout=30000)
        assert page.locator('#page-title').inner_text() == 'Infrastructure inventory'
        assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
        print('PASS responsive navigation, KPI layout and correlation:', width)
    page.set_viewport_size({'width': 390, 'height': 844})
    page.goto('http://127.0.0.1:8091/')
    expect(page.locator('#updated')).to_contain_text('Last updated:', timeout=30000)
    assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
    page.screenshot(path=str(out / 'phase4-mobile.png'), full_page=True)
    print('PASS mobile overview: 390px; no horizontal overflow')
    # Browser-only fixture injection exercises partial failure without stopping
    # a live LAB dependency or supplying any fixture to the actual service.
    data = page.request.get('http://127.0.0.1:8091/api/overview').json()
    data['zabbix'] = {'status': 'Unavailable'}
    data['synthetic_infrastructure'] = {'status': 'Unavailable'}
    page.route('**/api/overview', lambda route: route.fulfill(json=data))
    page.locator('#refresh').click()
    expect(page.locator('.metric').nth(0)).to_contain_text('Unavailable')
    expect(page.locator('.metric').nth(1)).to_contain_text('Unavailable')
    expect(page.locator('.source-status').nth(1)).to_contain_text(data['glpi']['status'])
    assert not page.locator('#fetch-warning').is_visible()
    print('PASS browser partial dependency failure; no fabricated zero')
    assert not errors, 'Browser JavaScript errors found'
    print('PASS JavaScript execution; screenshots:', out)
    browser.close()
