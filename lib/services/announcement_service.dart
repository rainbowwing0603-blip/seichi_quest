import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/announcement.dart';

class AnnouncementService {
  AnnouncementService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Announcement>> loadPublished() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    final announcementRows = await _client
        .from('announcements')
        .select(
          'id, title, body, category, priority, event_id, '
          'publish_from, publish_until, show_on_startup',
        )
        .order('priority', ascending: false)
        .order('publish_from', ascending: false);

    final readRows = await _client
        .from('announcement_reads')
        .select('announcement_id')
        .eq('user_id', user.id);

    final readIds = <String>{
      for (final row in readRows)
        if (row['announcement_id'] is String)
          row['announcement_id'] as String,
    };

    return [
      for (final row in announcementRows)
        Announcement.fromMap(
          Map<String, dynamic>.from(row),
          isRead: readIds.contains(row['id']),
        ),
    ];
  }

  Future<List<Announcement>> loadUnreadStartup() async {
    final announcements = await loadPublished();
    return announcements
        .where(
          (announcement) =>
              announcement.showOnStartup && !announcement.isRead,
        )
        .toList(growable: false);
  }

  Future<int> loadUnreadCount() async {
    final announcements = await loadPublished();
    return announcements.where((announcement) => !announcement.isRead).length;
  }

  Future<void> markRead(String announcementId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    await _client.from('announcement_reads').upsert(
      {
        'user_id': user.id,
        'announcement_id': announcementId,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,announcement_id',
    );
  }

  Future<void> markAllRead(Iterable<String> announcementIds) async {
    final ids = announcementIds.toSet();
    if (ids.isEmpty) {
      return;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    final readAt = DateTime.now().toUtc().toIso8601String();

    await _client.from('announcement_reads').upsert(
      [
        for (final announcementId in ids)
          {
            'user_id': user.id,
            'announcement_id': announcementId,
            'read_at': readAt,
          },
      ],
      onConflict: 'user_id,announcement_id',
    );
  }
}
