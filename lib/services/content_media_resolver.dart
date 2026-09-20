import 'package:supabase_flutter/supabase_flutter.dart';

class ContentMediaResolver {
  ContentMediaResolver({
    SupabaseClient? client,
    this.defaultBucket = 'event-card-images',
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final String defaultBucket;

  String? resolve(String? mediaPath) {
    final normalizedPath = mediaPath?.trim();

    if (normalizedPath == null || normalizedPath.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalizedPath);

    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return normalizedPath;
    }

    final normalizedBucket = defaultBucket.trim();

    if (normalizedBucket.isEmpty) {
      return null;
    }

    return _client.storage.from(normalizedBucket).getPublicUrl(normalizedPath);
  }
}
