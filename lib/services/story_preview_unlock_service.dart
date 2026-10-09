import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'story_preview_access_policy.dart';

/// Stores a per-content preview expiry locally, but compares it against
/// Supabase server time so changing the device clock does not extend access.
class StoryPreviewUnlockService {
  StoryPreviewUnlockService({
    SupabaseClient? client,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _client = client ?? Supabase.instance.client,
       _preferencesLoader =
           preferencesLoader ?? SharedPreferences.getInstance;

  final SupabaseClient _client;
  final Future<SharedPreferences> Function() _preferencesLoader;

  String _keyFor(String contentId) {
    final userId = _client.auth.currentUser?.id ?? 'signed-out';
    return 'story_preview_expiry_${userId}_${contentId.trim()}';
  }

  Future<Duration?> remainingAccess(String contentId) async {
    final normalizedId = contentId.trim();
    if (normalizedId.isEmpty || _client.auth.currentUser == null) {
      return null;
    }

    final preferences = await _preferencesLoader();
    final key = _keyFor(normalizedId);
    final rawExpiry = preferences.getString(key);
    if (rawExpiry == null) {
      return null;
    }

    final expiry = DateTime.tryParse(rawExpiry);
    if (expiry == null) {
      await preferences.remove(key);
      return null;
    }

    final serverNow = await _serverNow();
    if (!StoryPreviewAccessPolicy.isActive(
      expiresAt: expiry,
      serverNow: serverNow,
    )) {
      await preferences.remove(key);
      return null;
    }

    return expiry.toUtc().difference(serverNow);
  }

  Future<DateTime> grantOneHour(String contentId) async {
    final normalizedId = contentId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(contentId, 'contentId', 'Must not be empty.');
    }
    if (_client.auth.currentUser == null) {
      throw StateError('Authentication is required to unlock a story preview.');
    }

    final expiry = StoryPreviewAccessPolicy.expiresAt(await _serverNow());
    final preferences = await _preferencesLoader();
    final saved = await preferences.setString(
      _keyFor(normalizedId),
      expiry.toIso8601String(),
    );
    if (!saved) {
      throw StateError('Could not save the story preview expiry.');
    }
    return expiry;
  }

  Future<DateTime> _serverNow() async {
    final value = await _client.rpc('story_preview_server_time');
    final parsed = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw const FormatException('Supabase returned an invalid server time.');
    }
    return parsed.toUtc();
  }
}
