import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final root = jsonDecode(await File('media_assets/manifest.json').readAsString()) as Map<String, dynamic>;
  final inventory = root['canonical_event_inventory'] as Map<String, dynamic>;
  final items = (inventory['items'] as List).cast<Map<String, dynamic>>();
  final keys = (inventory['spot_keys'] as List).cast<String>();
  if (inventory['event_slug'] != 'jomo-karuta-gunma' || items.length != 44 || keys.length != 44 || keys.toSet().length != 44) {
    throw StateError('Expected 44 distinct canonical event spots');
  }
  final cards = <String>{};
  for (var i = 0; i < 44; i++) {
    if (items[i]['display_order'] != i + 1 || !cards.add(items[i]['card'] as String) || (items[i]['title'] as String).isEmpty) {
      throw StateError('Invalid canonical inventory item ${i + 1}');
    }
  }
  final aliases = (root['spot_key_aliases'] as Map).cast<String, dynamic>();
  for (final entry in aliases.entries) {
    if (keys.contains(entry.key) || !keys.contains(entry.value)) throw StateError('Invalid alias ${entry.key}');
  }
  final assets = (root['assets'] as List).cast<Map<String, dynamic>>();
  final verified = <String, int>{};
  final onsite = <String, int>{};
  final pages = <String>{};
  for (final asset in assets) {
    final key = asset['spot_key'] as String;
    final index = keys.indexOf(key);
    if (index < 0 || asset['event_slug'] != inventory['event_slug'] ||
        asset['spot_name'] != items[index]['title'] || asset['canonical_card'] != items[index]['card'] ||
        asset['canonical_display_order'] != index + 1) {
      throw StateError('Noncanonical asset: ${asset['file_page']}');
    }
    if (!{'onsite', 'supporting', 'regional'}.contains(asset['asset_role'])) throw StateError('Invalid asset role');
    final url = asset['file_page']?.toString() ?? '';
    if (asset['status'] != 'verified_candidate') continue;
    if (!pages.add(url)) throw StateError('Duplicate verified source page: $url');
    if (asset['embedded_watermark'] != false || asset['commercial_use'] != true ||
        asset['modification_allowed'] != true || asset['reuse_requires_application'] != false) {
      throw StateError('Unusable verified asset: $url');
    }
    for (final field in ['file_page', 'author', 'license', 'license_url', 'source', 'source_verified_at']) {
      if ((asset[field]?.toString().trim() ?? '').isEmpty) throw StateError('Missing $field: $url');
    }
    if (!url.startsWith('https://') || (asset['width'] as num? ?? 0) <= 0 || (asset['height'] as num? ?? 0) <= 0) {
      throw StateError('Invalid URL or dimensions: $url');
    }
    final download = Uri.tryParse(asset['download_url']?.toString() ?? '');
    final local = asset['cache_path']?.toString() ?? '';
    if (download?.scheme != 'https' || download?.host != 'upload.wikimedia.org' ||
        !local.startsWith('media_assets/cache/$key/') || local.contains('..') ||
        (asset['source_file_bytes'] as num? ?? 0) <= 0) {
      throw StateError('Unsafe or missing cache resolution: $url');
    }
    final license = (asset['license'] as String).toUpperCase();
    if (license.contains(' NC') || license.contains(' ND') ||
        !(license.startsWith('CC0') || license.startsWith('CC BY ') || license.startsWith('CC BY-SA ') ||
          license.startsWith('PUBLIC DOMAIN') || license.startsWith('PD-'))) {
      throw StateError('Unclear or restricted license: $url');
    }
    final shareAlike = license.startsWith('CC BY-SA ');
    if (asset['share_alike_required'] != shareAlike ||
        (license.startsWith('CC BY') && (asset['credit_text']?.toString().trim() ?? '').isEmpty)) {
      throw StateError('Missing credit or ShareAlike obligation: $url');
    }
    verified.update(key, (n) => n + 1, ifAbsent: () => 1);
    if (asset['asset_role'] == 'onsite') onsite.update(key, (n) => n + 1, ifAbsent: () => 1);
  }
  final readiness = (root['spot_readiness'] as Map).cast<String, dynamic>();
  if (readiness.keys.toSet().difference(keys.toSet()).isNotEmpty || readiness.length != 44) {
    throw StateError('Readiness must have exactly the canonical 44 keys');
  }
  var ready = 0;
  for (final key in keys) {
    final expected = verified[key] ?? 0;
    final on = onsite[key] ?? 0;
    final isReady = expected >= 3 && on >= 1;
    final row = (readiness[key] as Map).cast<String, dynamic>();
    if (row['verified_images'] != expected || row['onsite_images'] != on || row['ready'] != isReady) {
      throw StateError('Stale readiness: $key');
    }
    if (isReady) ready++;
  }
  stdout.writeln('Manifest OK: $ready/44 READY; ${pages.length} verified assets.');
}
