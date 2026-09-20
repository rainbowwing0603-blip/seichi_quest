import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/event.dart';
import '../models/seichi.dart';
import 'quest_item_content_section.dart';
import 'quest_ui.dart';
import '../services/app_logger.dart';
import '../services/seichi_service.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    this.currentPosition,
    this.collectedCount,
    this.totalCount,
    this.participationLabel = '選択中',
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onSelectAnotherEvent,
    this.currentNextSeichiId,
    this.onSetNextDestination,
    this.onShowOnMap,
    this.onStartRecommendedRoute,
  });

  final Event event;
  final Position? currentPosition;

  final int? collectedCount;
  final int? totalCount;

  final String participationLabel;

  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;

  final Future<void> Function()? onSelectAnotherEvent;

  final String? currentNextSeichiId;
  final ValueChanged<Seichi>? onSetNextDestination;
  final ValueChanged<Seichi>? onShowOnMap;
  final ValueChanged<List<Seichi>>? onStartRecommendedRoute;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isActionRunning = false;

  bool _isLoadingSeichi = true;
  String? _seichiErrorMessage;

  List<Seichi> _seichiList = [];

  final Set<String> _collectedSeichiIds = <String>{};

  String _galleryFilter = 'すべて';

  bool _isLoadingSocialStats = true;
  bool _isFavoriteUpdating = false;
  int? _participantCount;
  int? _favoriteCount;
  bool _isFavorited = false;

  final SeichiService _seichiService = SeichiService();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSeichiList();
    _loadSocialStats();
  }

  Future<void> _loadSeichiList() async {
    try {
      final list = await _seichiService.loadActiveSeichi(widget.event.id);

      final collectedIds = <String>{};
      final user = _client.auth.currentUser;

      if (user != null) {
        try {
          final historyData = await _client
              .from('collection_history')
              .select('seichi_id')
              .eq('user_id', user.id)
              .eq('event_id', widget.event.id);

          for (final row in List<Map<String, dynamic>>.from(historyData)) {
            final seichiId = row['seichi_id']?.toString() ?? '';

            if (seichiId.isNotEmpty) {
              collectedIds.add(seichiId);
            }
          }
        } catch (error, stackTrace) {
          appDebugPrint(
            '[EVENT_DETAIL] collection history load failed: $error',
          );
          appDebugPrint(
            '[EVENT_DETAIL] collection history stackTrace: $stackTrace',
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _seichiList = list;

        _collectedSeichiIds
          ..clear()
          ..addAll(collectedIds);

        _isLoadingSeichi = false;
        _seichiErrorMessage = null;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT_DETAIL] seichi load failed: $error');
      appDebugPrint('[EVENT_DETAIL] seichi load stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSeichi = false;
        _seichiErrorMessage = '札情報を読み込めませんでした。';
      });
    }
  }

  Future<void> _loadSocialStats() async {
    try {
      final data = await _client.rpc(
        'get_event_social_stats',
        params: {'p_event_id': widget.event.id},
      );

      final rows = data is List
          ? List<Map<String, dynamic>>.from(data)
          : <Map<String, dynamic>>[];

      final row = rows.isNotEmpty ? rows.first : <String, dynamic>{};

      final participantCount = _toIntOrZero(row['participant_count']);

      final favoriteCount = _toIntOrZero(row['favorite_count']);

      final isFavorited = row['is_favorited'] == true;

      if (!mounted) {
        return;
      }

      setState(() {
        _participantCount = participantCount;

        _favoriteCount = favoriteCount;

        _isFavorited = isFavorited;

        _isLoadingSocialStats = false;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT_DETAIL] social stats load failed: $error');

      appDebugPrint('[EVENT_DETAIL] social stats stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSocialStats = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteUpdating) {
      return;
    }

    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    final wasFavorited = _isFavorited;

    setState(() {
      _isFavoriteUpdating = true;
    });

    try {
      if (wasFavorited) {
        await _client
            .from('user_event_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('event_id', widget.event.id);
      } else {
        await _client.from('user_event_favorites').insert({
          'user_id': user.id,
          'event_id': widget.event.id,
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isFavorited = !wasFavorited;

        final currentCount = _favoriteCount ?? 0;

        _favoriteCount = wasFavorited
            ? (currentCount > 0 ? currentCount - 1 : 0)
            : currentCount + 1;

        _isFavoriteUpdating = false;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[EVENT_DETAIL] favorite toggle failed: $error');

      appDebugPrint('[EVENT_DETAIL] favorite toggle stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isFavoriteUpdating = false;
      });

      QuestSnackBar.show(
        context,
        message: 'お気に入りの更新に失敗しました。',
        type: QuestNoticeType.error,
      );
    }
  }

  int _toIntOrZero(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Seichi? get _nearestUncollectedSeichi {
    final position = widget.currentPosition;

    if (position == null) {
      return null;
    }

    Seichi? nearest;
    double? nearestDistance;

    for (final seichi in _seichiList) {
      if (_collectedSeichiIds.contains(seichi.id)) {
        continue;
      }

      if (seichi.latitude == 0.0 && seichi.longitude == 0.0) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        seichi.latitude,
        seichi.longitude,
      );

      if (nearestDistance == null || distance < nearestDistance) {
        nearest = seichi;
        nearestDistance = distance;
      }
    }

    return nearest;
  }

  double? _distanceFromCurrentPosition(Seichi seichi) {
    final position = widget.currentPosition;

    if (position == null) {
      return null;
    }

    if (seichi.latitude == 0.0 && seichi.longitude == 0.0) {
      return null;
    }

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      seichi.latitude,
      seichi.longitude,
    );
  }

  List<Seichi> get _filteredSeichiList {
    switch (_galleryFilter) {
      case '獲得済み':
        return _seichiList
            .where((seichi) => _collectedSeichiIds.contains(seichi.id))
            .toList(growable: false);

      case '未獲得':
        return _seichiList
            .where((seichi) => !_collectedSeichiIds.contains(seichi.id))
            .toList(growable: false);

      default:
        return _seichiList;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '未設定';
    }

    final local = value.toLocal();

    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  String _periodText() {
    if (widget.event.startAt == null && widget.event.endAt == null) {
      return '開催期間の設定なし';
    }

    if (widget.event.startAt != null && widget.event.endAt != null) {
      return '${_formatDate(widget.event.startAt)}'
          ' 〜 '
          '${_formatDate(widget.event.endAt)}';
    }

    if (widget.event.startAt != null) {
      return '${_formatDate(widget.event.startAt)} 〜';
    }

    return '〜 ${_formatDate(widget.event.endAt)}';
  }

  String _eventStatusText() {
    return widget.event.eventStatusText();
  }

  Color _participationColor() {
    switch (widget.participationLabel) {
      case '選択中':
        return Colors.deepPurple;

      case '参加中':
        return Colors.green;

      case '過去に参加':
        return Colors.orange;

      case '未参加':
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  bool get _hasProgress {
    return widget.collectedCount != null && widget.totalCount != null;
  }

  double get _progress {
    final collected = widget.collectedCount;
    final total = widget.totalCount;

    if (collected == null || total == null || total <= 0) {
      return 0;
    }

    return (collected / total).clamp(0.0, 1.0);
  }

  int get _progressPercent {
    return (_progress * 100).round();
  }

  Future<void> _runPrimaryAction() async {
    final action = widget.onPrimaryAction;

    if (action == null || _isActionRunning) {
      return;
    }

    setState(() {
      _isActionRunning = true;
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isActionRunning = false;
      });
    }
  }

  void _showSeichiDetail(Seichi seichi) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F8FC),
      builder: (sheetContext) {
        final collected = _collectedSeichiIds.contains(seichi.id);
        final isNext = widget.currentNextSeichiId == seichi.id;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuestGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: QuestUiTokens.primaryGradient,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              seichi.card,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SPOT DETAIL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w900,
                                    color: QuestUiTokens.mutedInk,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  seichi.name,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: QuestUiTokens.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (collected)
                            const QuestStatusChip(
                              label: '獲得済み',
                              icon: Icons.check_circle,
                              accentColor: Colors.green,
                            ),
                          if (isNext && !collected)
                            const QuestStatusChip(
                              label: 'NEXT',
                              icon: Icons.navigation_rounded,
                            ),
                          QuestStatusChip(
                            label: '獲得範囲 ${seichi.stampRadiusMeters}m',
                            icon: Icons.place_outlined,
                            accentColor: QuestUiTokens.cyan,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                QuestItemContentSection(item: seichi),
                if (widget.onShowOnMap != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        widget.onShowOnMap!(seichi);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: QuestUiTokens.primary,
                        side: BorderSide(
                          color: QuestUiTokens.primary.withValues(alpha: 0.20),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            QuestUiTokens.controlRadius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text(
                        'この地点を地図で見る',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
                if (widget.onSetNextDestination != null && !collected) ...[
                  const SizedBox(height: 10),
                  QuestPrimaryButton(
                    label: isNext ? '次の目的地に設定済み' : '次の目的地に設定',
                    icon: isNext ? Icons.flag : Icons.navigation_outlined,
                    onPressed: isNext
                        ? null
                        : () {
                            widget.onSetNextDestination!(seichi);
                            Navigator.of(sheetContext).pop();
                          },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareEvent(BuildContext shareButtonContext) async {
    final eventName = widget.event.name.trim();
    final prefecture = widget.event.prefecture?.trim();
    final slug = widget.event.slug.trim();

    final buffer = StringBuffer()
      ..writeln('聖地クエスト')
      ..writeln()
      ..writeln('「$eventName」に挑戦しよう！');

    if (prefecture != null && prefecture.isNotEmpty) {
      buffer.writeln('エリア: $prefecture');
    }

    if (slug.isNotEmpty) {
      buffer.writeln('クエスト: $slug');
    }

    buffer
      ..writeln()
      ..write('聖地を巡って、スタンプを集めよう！');

    final renderBox = shareButtonContext.findRenderObject() as RenderBox?;

    final sharePositionOrigin = renderBox != null && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: eventName,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error) {
      appDebugPrint('[SHARE] event share failed: $error');

      if (!mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: 'クエストを共有できませんでした。',
        type: QuestNoticeType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final participationColor = _participationColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'クエスト詳細',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        foregroundColor: QuestUiTokens.ink,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Builder(
            builder: (shareButtonContext) {
              return IconButton(
                tooltip: 'クエストを共有',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => _shareEvent(shareButtonContext),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            QuestGlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.event.coverImageUrl != null &&
                      widget.event.coverImageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          widget.event.coverImageUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 1200,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: QuestUiTokens.primary.withValues(
                                alpha: 0.045,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: QuestUiTokens.mutedInk,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: QuestUiTokens.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: QuestUiTokens.primary.withValues(
                                alpha: 0.20,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUEST',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.mutedInk,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.event.name,
                              style: const TextStyle(
                                fontSize: 21,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.ink,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _buildStatusChip(
                                  _eventStatusText(),
                                  Colors.green,
                                ),
                                _buildStatusChip(
                                  widget.participationLabel,
                                  participationColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: QuestUiTokens.primary.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.event.description,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.65,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (widget.primaryActionLabel != null &&
                widget.onPrimaryAction != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: QuestUiTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(
                    QuestUiTokens.controlRadius,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: QuestUiTokens.primary.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _isActionRunning ? null : _runPrimaryAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: QuestUiTokens.mutedInk.withValues(
                      alpha: 0.30,
                    ),
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        QuestUiTokens.controlRadius,
                      ),
                    ),
                  ),
                  icon: _isActionRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    widget.primaryActionLabel!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            QuestGlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: QuestUiTokens.cyan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: QuestUiTokens.cyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '開催情報',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _periodText(),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: QuestUiTokens.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _buildSocialStatsCard(),

            if (_hasProgress) ...[
              const SizedBox(height: 14),

              QuestGlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: QuestUiTokens.cyanGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_graph_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROGRESS',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w900,
                                  color: QuestUiTokens.mutedInk,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'クエスト進捗',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: QuestUiTokens.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$_progressPercent%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.collectedCount}',
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.ink,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 5, bottom: 2),
                          child: Text(
                            '/ ${widget.totalCount} SPOTS',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: QuestUiTokens.mutedInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 9,
                        backgroundColor: QuestUiTokens.primary.withValues(
                          alpha: 0.08,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          QuestUiTokens.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      widget.totalCount != null &&
                              widget.collectedCount != null &&
                              widget.totalCount! > 0
                          ? widget.collectedCount! >= widget.totalCount!
                                ? '完全制覇！'
                                : 'あと'
                                      '${widget.totalCount! - widget.collectedCount!}'
                                      '札で完全制覇'
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            widget.collectedCount != null &&
                                widget.totalCount != null &&
                                widget.collectedCount! >= widget.totalCount!
                            ? Colors.green
                            : QuestUiTokens.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            _buildNearestUncollectedCard(),

            const SizedBox(height: 14),

            _buildRecommendedRouteCard(),

            const SizedBox(height: 14),

            _buildCardGallery(),

            if (widget.onSelectAnotherEvent != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onSelectAnotherEvent!();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: QuestUiTokens.primary,
                    side: BorderSide(
                      color: QuestUiTokens.primary.withValues(alpha: 0.22),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        QuestUiTokens.controlRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text(
                    '別のクエストを見る',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return QuestStatusChip(label: label, accentColor: color);
  }
}
