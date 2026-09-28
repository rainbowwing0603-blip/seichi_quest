import 'dart:convert';
import 'dart:io';

/// Validates the media manifest before a downloader is allowed to use it.
///
/// Network download is intentionally kept out of the production app. This
/// script is developer tooling and should be extended to resolve the original
/// file URL from each verified source page/API while preserving provenance.
Future<void> main() async {
  final file = File('media_assets/manifest.json');
  final root = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final assets = (root['assets'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  var usable = 0;
  for (final asset in assets) {
    if (asset['status'] != 'verified_candidate') continue;
    if (asset['embedded_watermark'] == true) {
      throw StateError('Verified asset unexpectedly has watermark: ${asset['file_page']}');
    }
    for (final key in ['file_page', 'author', 'license', 'license_url']) {
      if ((asset[key]?.toString().trim() ?? '').isEmpty) {
        throw StateError('Missing $key: ${asset['spot_name']}');
      }
    }
    usable++;
  }

  stdout.writeln('Manifest OK: $usable verified candidate(s).');
  stdout.writeln('No production data was modified.');
}
