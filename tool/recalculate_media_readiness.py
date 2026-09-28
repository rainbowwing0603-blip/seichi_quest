"""Recalculate readiness strictly from the 44 production event inventory items."""
import collections
import json
from pathlib import Path

manifest_path = Path('media_assets/manifest.json')
manifest = json.loads(manifest_path.read_text())
inventory = manifest['canonical_event_inventory']
keys = inventory['spot_keys']
assert len(inventory['items']) == len(keys) == len(set(keys)) == 44
counts = collections.Counter(a['spot_key'] for a in manifest['assets'] if a['status'] == 'verified_candidate')
onsite = collections.Counter(a['spot_key'] for a in manifest['assets'] if a['status'] == 'verified_candidate' and a['asset_role'] == 'onsite')
manifest['spot_readiness'] = {
    key: {'verified_images': counts[key], 'onsite_images': onsite[key], 'ready': counts[key] >= 3 and onsite[key] >= 1}
    for key in keys
}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print('READY:', sum(v['ready'] for v in manifest['spot_readiness'].values()), '/44')
for key in keys:
    if not manifest['spot_readiness'][key]['ready']:
        idx = keys.index(key)
        print(inventory['items'][idx]['card'], inventory['items'][idx]['title'], counts[key], 'onsite', onsite[key])
