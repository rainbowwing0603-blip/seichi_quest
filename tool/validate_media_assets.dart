import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final root = jsonDecode(await File('media_assets/manifest.json').readAsString()) as Map<String, dynamic>;
  final assets = (root['assets'] as List<dynamic>).cast<Map<String, dynamic>>();
  var usable = 0;
  for (final asset in assets) {
    if (asset['status'] != 'verified_candidate') continue;
    if (asset['embedded_watermark'] == true) throw StateError('Verified asset unexpectedly has watermark');
    for (final key in ['file_page', 'author', 'license', 'license_url']) {
      if ((asset[key]?.toString().trim() ?? '').isEmpty) throw StateError('Missing required media metadata');
    }
    usable++;
  }
  stdout.writeln('Manifest OK: $usable verified candidate(s).');
}
