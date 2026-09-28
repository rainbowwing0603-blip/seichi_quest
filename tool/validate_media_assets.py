"""Offline validation of the canonical media manifest (mirrors the Dart gate)."""
from collections import Counter
import json
from pathlib import Path
from urllib.parse import urlparse

m = json.loads(Path('media_assets/manifest.json').read_text())
i = m['canonical_event_inventory']
keys = i['spot_keys']
assert i['event_slug'] == 'jomo-karuta-gunma' and len(keys) == len(set(keys)) == len(i['items']) == 44
assert len({row['card'] for row in i['items']}) == 44
assert all(row['display_order'] == n for n, row in enumerate(i['items'], 1))
assert all(alias not in keys and target in keys for alias, target in m['spot_key_aliases'].items())
counts, onsite, pages = Counter(), Counter(), set()
for a in m['assets']:
    key = a['spot_key']
    assert key in keys and a['event_slug'] == i['event_slug'], a['file_page']
    row = i['items'][keys.index(key)]
    assert (a['spot_name'], a['canonical_card'], a['canonical_display_order']) == (row['title'], row['card'], row['display_order']), a['file_page']
    assert a['asset_role'] in ('onsite', 'supporting', 'regional') and 'notes' in a
    if a['status'] != 'verified_candidate':
        continue
    assert a['file_page'] not in pages, a['file_page']
    pages.add(a['file_page'])
    assert all(a.get(k) for k in ('source', 'file_page', 'author', 'license', 'license_url', 'source_verified_at', 'download_url', 'cache_path', 'source_file_bytes'))
    assert a['width'] > 0 and a['height'] > 0 and a['source_file_bytes'] > 0
    assert a['embedded_watermark'] is False and a['commercial_use'] is True and a['modification_allowed'] is True and a['reuse_requires_application'] is False
    license = a['license'].upper()
    assert not any(x in license for x in (' NC', ' ND')) and license.startswith(('CC0', 'CC BY ', 'CC BY-SA ', 'PUBLIC DOMAIN', 'PD-')), a['file_page']
    assert a['share_alike_required'] == license.startswith('CC BY-SA ')
    assert not license.startswith('CC BY') or a.get('credit_text')
    assert urlparse(a['file_page']).scheme == 'https' and urlparse(a['download_url']).hostname == 'upload.wikimedia.org'
    assert a['cache_path'].startswith(f'media_assets/cache/{key}/') and '..' not in a['cache_path']
    counts[key] += 1
    if a['asset_role'] == 'onsite':
        onsite[key] += 1
assert set(m['spot_readiness']) == set(keys)
for key in keys:
    assert m['spot_readiness'][key] == {'verified_images': counts[key], 'onsite_images': onsite[key], 'ready': counts[key] >= 3 and onsite[key] >= 1}, key
print(f'Manifest OK: {sum(row["ready"] for row in m["spot_readiness"].values())}/44 READY; {len(pages)} verified assets')
