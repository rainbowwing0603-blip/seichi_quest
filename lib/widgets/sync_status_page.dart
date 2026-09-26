import 'package:flutter/material.dart';

import 'quest_ui.dart';

class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({
    super.key,
    required this.loadPendingCount,
    required this.syncNow,
  });

  final Future<int> Function() loadPendingCount;
  final Future<int> Function() syncNow;

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  bool _isLoading = true;
  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _errorMessage;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final count = await widget.loadPendingCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingCount = count;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '同期状態を確認できませんでした。';
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _message = null;
      _errorMessage = null;
    });

    try {
      final remaining = await widget.syncNow();

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingCount = remaining;
        _message = remaining == 0
            ? '保留中の訪問データをすべて送信しました。'
            : '一部の訪問データはまだ保留中です。';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '同期に失敗しました。通信状態を確認してもう一度お試しください。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
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
          '同期状態',
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
      return const Center(
        child: CircularProgressIndicator(color: QuestUiTokens.primary),
      );
    }

    if (_errorMessage != null && _pendingCount == 0) {
      return _buildInitialError();
    }

    final hasPending = _pendingCount > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        _buildHeroCard(hasPending),
        const SizedBox(height: 18),
        _buildStatusCard(hasPending),
        if (_message != null) ...[
          const SizedBox(height: 14),
          _buildMessage(_message!, isError: false),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildMessage(_errorMessage!, isError: true),
        ],
        const SizedBox(height: 18),
        QuestPrimaryButton(
          label: _isSyncing ? '同期中...' : '今すぐ同期',
          icon: _isSyncing ? null : Icons.sync_rounded,
          onPressed: _isSyncing || !hasPending ? null : _syncNow,
        ),
        if (_isSyncing) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              minHeight: 4,
              color: QuestUiTokens.primary,
              backgroundColor: Color(0xFFE6EAF2),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _buildRefreshButton(),
        const SizedBox(height: 18),
        _buildOfflineInfo(),
      ],
    );
  }

  Widget _buildInitialError() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        QuestGlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 34,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '同期状態を取得できません',
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
                  fontSize: 12,
                  height: 1.5,
                  color: QuestUiTokens.mutedInk,
                ),
              ),
              const SizedBox(height: 20),
              QuestPrimaryButton(
                label: '再読み込み',
                icon: Icons.refresh_rounded,
                onPressed: _loadStatus,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(bool hasPending) {
    return QuestGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: hasPending
                  ? QuestUiTokens.cyanGradient
                  : QuestUiTokens.primaryGradient,
              borderRadius: BorderRadius.circular(19),
              boxShadow: [
                BoxShadow(
                  color:
                      (hasPending ? QuestUiTokens.cyan : QuestUiTokens.primary)
                          .withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              hasPending
                  ? Icons.cloud_upload_outlined
                  : Icons.cloud_done_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYNC STATUS',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPending ? '冒険データを送信しよう' : '冒険データは同期済み',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  hasPending
                      ? '通信できなかった訪問記録が、この端末で送信を待っています。'
                      : '現在、この端末で送信待ちになっている訪問記録はありません。',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool hasPending) {
    return QuestGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEVICE QUEUE',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasPending ? '保留中 $_pendingCount件' : '同期済み',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
              QuestStatusChip(
                label: hasPending ? '送信待ち' : '最新',
                icon: hasPending
                    ? Icons.schedule_rounded
                    : Icons.check_circle_outline_rounded,
                accentColor: hasPending
                    ? QuestUiTokens.cyan
                    : QuestUiTokens.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (hasPending ? QuestUiTokens.cyan : QuestUiTokens.primary)
                  .withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasPending
                      ? Icons.cloud_queue_rounded
                      : Icons.verified_outlined,
                  size: 20,
                  color: hasPending
                      ? QuestUiTokens.cyan
                      : QuestUiTokens.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasPending
                        ? '通信できなかった訪問データがこの端末に保存されています。'
                        : 'この端末に保留中の訪問データはありません。',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: QuestUiTokens.mutedInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _isSyncing ? null : _loadStatus,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text(
          '状態を更新',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: TextButton.styleFrom(
          foregroundColor: QuestUiTokens.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildOfflineInfo() {
    return QuestGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: QuestUiTokens.cyan.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.offline_bolt_outlined,
              color: QuestUiTokens.cyan,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'オフラインでも記録',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '訪問時に通信できなかった場合でも、データは端末に保留され、後から再送されます。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String text, {required bool isError}) {
    final accent = isError ? Colors.redAccent : QuestUiTokens.cyan;

    return QuestGlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: isError ? Colors.red.shade700 : QuestUiTokens.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
