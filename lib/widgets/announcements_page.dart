import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/announcement_service.dart';
import 'quest_ui.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({
    super.key,
    this.service,
  });

  final AnnouncementService? service;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  late final AnnouncementService _service =
      widget.service ?? AnnouncementService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Announcement> _announcements = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final announcements = await _service.loadPublished();
      if (!mounted) return;

      setState(() {
        _announcements = announcements;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'お知らせを取得できませんでした。';
      });
    }
  }

  Future<void> _openAnnouncement(Announcement announcement) async {
    if (!announcement.isRead) {
      try {
        await _service.markRead(announcement.id);
        if (mounted) {
          setState(() {
            _announcements = [
              for (final item in _announcements)
                if (item.id == announcement.id)
                  item.copyWith(isRead: true)
                else
                  item,
            ];
          });
        }
      } catch (_) {
        // 詳細表示は継続し、既読同期は次回に再試行できる状態を保つ。
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(announcement.title),
          content: SingleChildScrollView(
            child: Text(
              announcement.body,
              style: const TextStyle(height: 1.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuestUiTokens.background,
      appBar: AppBar(
        title: const Text('お知らせ'),
        backgroundColor: QuestUiTokens.background,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _load,
              child: const Text('再読み込み'),
            ),
          ),
        ],
      );
    }

    if (_announcements.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.notifications_none_rounded, size: 44),
          SizedBox(height: 16),
          Text(
            '現在のお知らせはありません。',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: _announcements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final announcement = _announcements[index];

        return QuestGlassCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            leading: Icon(
              announcement.isRead
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_rounded,
              color: announcement.isRead
                  ? QuestUiTokens.mutedInk
                  : QuestUiTokens.primary,
            ),
            title: Text(
              announcement.title,
              style: TextStyle(
                fontWeight:
                    announcement.isRead ? FontWeight.w700 : FontWeight.w900,
                color: QuestUiTokens.ink,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                announcement.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openAnnouncement(announcement),
          ),
        );
      },
    );
  }
}
