import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_service.dart';

/// A preview never writes collection history or grants stamp benefits.
class StoryPreviewService {
  StoryPreviewService({
    Future<DateTime> Function()? serverTime,
    String? Function()? userId,
    Future<SharedPreferences> Function()? preferences,
  }) : _serverTime = serverTime ?? _loadServerTime,
       _userId = userId ?? (() => Supabase.instance.client.auth.currentUser?.id),
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const duration = Duration(hours: 1);
  final Future<DateTime> Function() _serverTime;
  final String? Function() _userId;
  final Future<SharedPreferences> Function() _preferences;

  static Future<DateTime> _loadServerTime() async {
    await SessionService().ensureCloudUser();
    final value = await Supabase.instance.client.rpc('story_preview_server_time');
    return DateTime.parse(value as String).toUtc();
  }

  String? get currentUserId => _userId();

  Future<String> ensureUser() async {
    await _serverTime();
    final user = _userId();
    if (user == null) throw StateError('Preview account unavailable');
    return user;
  }

  String _key(String user, String content) => 'story_preview_v1:$user:$content';

  Future<Duration?> remaining(String contentId) async {
    final elapsed = Stopwatch()..start();
    final now = await _serverTime();
    final user = _userId();
    if (user == null || contentId.isEmpty) return null;
    final prefs = await _preferences();
    final key = _key(user, contentId);
    final expiry = DateTime.tryParse(prefs.getString(key) ?? '');
    if (expiry == null || !expiry.isAfter(now) ||
        expiry.difference(now) > duration) {
      await prefs.remove(key);
      return null;
    }
    // Account changes during an await must never expose another user's preview.
    if (_userId() != user) return null;
    final remaining = expiry.difference(now) - elapsed.elapsed;
    return remaining > Duration.zero ? remaining : null;
  }

  Future<Duration> grant(String contentId, {required String expectedUserId}) async {
    final elapsed = Stopwatch()..start();
    final now = await _serverTime();
    if (contentId.isEmpty || _userId() != expectedUserId) {
      throw StateError('Preview account changed');
    }
    final prefs = await _preferences();
    if (_userId() != expectedUserId) throw StateError('Preview account changed');
    final saved = await prefs.setString(
      _key(expectedUserId, contentId), now.add(duration).toIso8601String(),
    );
    if (!saved) throw StateError('Preview could not be saved');
    return duration - elapsed.elapsed;
  }
}
