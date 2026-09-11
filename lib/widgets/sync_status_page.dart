import 'package:flutter/material.dart';

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
        _errorMessage =
            '同期に失敗しました。通信状態を確認してもう一度お試しください。';
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
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('同期状態'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _pendingCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }

    final hasPending = _pendingCount > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: hasPending
                      ? Colors.orange.withValues(alpha: 0.10)
                      : Colors.green.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasPending
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done_outlined,
                  size: 36,
                  color: hasPending
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasPending
                    ? '保留中 $_pendingCount件'
                    : '同期済み',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasPending
                    ? '通信できなかった訪問データがこの端末に保存されています。'
                    : 'この端末に保留中の訪問データはありません。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          _buildMessage(
            _message!,
            isError: false,
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildMessage(
            _errorMessage!,
            isError: true,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _isSyncing || !hasPending
                    ? null
                    : _syncNow,
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(
              _isSyncing
                  ? '同期中...'
                  : '今すぐ同期',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _isSyncing ? null : _loadStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('状態を更新'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '訪問時に通信できなかった場合でも、データは端末に保留され、後から再送されます。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(
    String text, {
    required bool isError,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.07)
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isError
              ? Colors.red.shade700
              : Colors.green.shade800,
        ),
      ),
    );
  }
}