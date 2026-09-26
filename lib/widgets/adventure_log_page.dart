import 'package:flutter/material.dart';

import '../collection_history_service.dart';
import '../services/app_error_report.dart';
import 'quest_ui.dart';

class AdventureLogPage extends StatefulWidget {
  const AdventureLogPage({super.key});

  @override
  State<AdventureLogPage> createState() => _AdventureLogPageState();
}

class _AdventureLogPageState extends State<AdventureLogPage> {
  final CollectionHistoryService _historyService = CollectionHistoryService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final history = await _historyService.loadCollectionDisplayHistory();

      if (!mounted) {
        return;
      }

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = AppErrorReport.message(
          AppErrorCodes.adventureLog,
          '冒険ログを読み込めませんでした。',
          error: error,
          stackTrace: stackTrace,
        );
      });
    }
  }

  String _formatCollectedAt(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty) {
      return '日時不明';
    }

    final date = DateTime.tryParse(raw)?.toLocal();

    if (date == null) {
      return '日時不明';
    }

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$year/$month/$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuestUiTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '冒険ログ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 60, 18, 32),
        children: [
          QuestGlassCard(
            child: const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  color: QuestUiTokens.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 40, 18, 32),
        children: [
          QuestGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 30,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '冒険ログを取得できませんでした',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    height: 1.5,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
                const SizedBox(height: 20),
                QuestPrimaryButton(
                  label: '再読み込み',
                  icon: Icons.refresh_rounded,
                  onPressed: _loadHistory,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_history.isEmpty) {
      return RefreshIndicator(
        color: QuestUiTokens.primary,
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 36, 18, 32),
          children: [
            QuestGlassCard(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      gradient: QuestUiTokens.primaryGradient,
                      borderRadius: BorderRadius.all(Radius.circular(23)),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 19),
                  const Text(
                    'まだ冒険ログがありません',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: QuestUiTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    '聖地を訪れて札を獲得すると、ここにあなたの旅の記録が刻まれます。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.55,
                      color: QuestUiTokens.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const QuestStatusChip(
                    label: 'READY FOR ADVENTURE',
                    icon: Icons.explore_rounded,
                    accentColor: QuestUiTokens.cyan,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: QuestUiTokens.primary,
      onRefresh: _loadHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        itemCount: _history.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }

          return _buildHistoryCard(_history[index - 1]);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: QuestGlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: QuestUiTokens.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: QuestUiTokens.primary.withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ADVENTURE LOG',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w900,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'これまでの冒険',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: QuestUiTokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                QuestStatusChip(
                  label: '${_history.length}件',
                  icon: Icons.flag_rounded,
                  accentColor: QuestUiTokens.cyan,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: QuestUiTokens.primary.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    size: 18,
                    color: QuestUiTokens.primary,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '獲得した札が、新しい順に冒険の足跡として記録されます',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final card = item['card']?.toString().trim();
    final eventName = item['event_name']?.toString().trim();

    final displayCard = card == null || card.isEmpty ? '?' : card;

    final displayEventName = eventName == null || eventName.isEmpty
        ? '名称未設定のクエスト'
        : eventName;

    final collectedAt = _formatCollectedAt(item['collected_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: QuestUiTokens.cyanGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: QuestUiTokens.cyan.withValues(alpha: 0.22),
                        blurRadius: 9,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          QuestUiTokens.cyan.withValues(alpha: 0.28),
                          QuestUiTokens.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: QuestGlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: QuestUiTokens.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: QuestUiTokens.primary.withValues(alpha: 0.14),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      displayCard,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STAMP GET',
                          style: TextStyle(
                            fontSize: 8,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.cyan,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '「$displayCard」の札を獲得',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              size: 15,
                              color: QuestUiTokens.primary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                displayEventName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: QuestUiTokens.mutedInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: QuestUiTokens.mutedInk,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                collectedAt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: QuestUiTokens.mutedInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
