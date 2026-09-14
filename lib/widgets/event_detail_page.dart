import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/event.dart';
import '../models/seichi.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    this.collectedCount,
    this.totalCount,
    this.participationLabel = '選択中',
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onSelectAnotherEvent,
    this.currentNextSeichiId,
    this.onSetNextDestination,
  });

  final Event event;

  final int? collectedCount;
  final int? totalCount;

  final String participationLabel;

  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;

  final Future<void> Function()? onSelectAnotherEvent;

  final String? currentNextSeichiId;
  final ValueChanged<Seichi>? onSetNextDestination;

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

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSeichiList();
  }

  Future<void> _loadSeichiList() async {
    try {
      final data = await _client
          .from('seichi')
          .select(
            'id, card, reading, name, latitude, longitude, '
            'stamp_radius_meters, description, icon, '
            'card_image_url, is_active, place_id',
          )
          .eq('event_id', widget.event.id)
          .eq('is_active', true);

      final list = List<Map<String, dynamic>>.from(data)
          .map(Seichi.fromMap)
          .where((seichi) => seichi.id.isNotEmpty)
          .toList();

      list.sort((a, b) => _cardOrder(a.card).compareTo(_cardOrder(b.card)));

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
          debugPrint('[EVENT_DETAIL] collection history load failed: $error');
          debugPrint(
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
      debugPrint('[EVENT_DETAIL] seichi load failed: $error');
      debugPrint('[EVENT_DETAIL] seichi load stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSeichi = false;
        _seichiErrorMessage = '札情報を読み込めませんでした。';
      });
    }
  }

  int _cardOrder(String card) {
    const cards = <String>[
      'あ',
      'い',
      'う',
      'え',
      'お',
      'か',
      'き',
      'く',
      'け',
      'こ',
      'さ',
      'し',
      'す',
      'せ',
      'そ',
      'た',
      'ち',
      'つ',
      'て',
      'と',
      'な',
      'に',
      'ぬ',
      'ね',
      'の',
      'は',
      'ひ',
      'ふ',
      'へ',
      'ほ',
      'ま',
      'み',
      'む',
      'め',
      'も',
      'や',
      'ゆ',
      'よ',
      'ら',
      'り',
      'る',
      'れ',
      'ろ',
      'わ',
    ];

    final index = cards.indexOf(card);

    if (index < 0) {
      return cards.length;
    }

    return index;
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
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (seichi.cardImageUrl != null)
                  _buildLargeCardImage(seichi)
                else
                  _buildCardFallback(seichi),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        seichi.card,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seichi.name,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (seichi.reading.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              seichi.reading,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (seichi.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    seichi.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (_collectedSeichiIds.contains(seichi.id)) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 17, color: Colors.green),
                        SizedBox(width: 6),
                        Text(
                          '獲得済み',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '獲得範囲 '
                        '${seichi.stampRadiusMeters}m',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),

                if (widget.onSetNextDestination != null &&
                    !_collectedSeichiIds.contains(seichi.id)) ...[
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: widget.currentNextSeichiId == seichi.id
                          ? null
                          : () {
                              widget.onSetNextDestination!(seichi);

                              Navigator.of(sheetContext).pop();
                            },
                      icon: Icon(
                        widget.currentNextSeichiId == seichi.id
                            ? Icons.flag
                            : Icons.navigation_outlined,
                      ),
                      label: Text(
                        widget.currentNextSeichiId == seichi.id
                            ? '次の目的地に設定済み'
                            : '次の目的地に設定',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLargeCardImage(Seichi seichi) {
    final imageUrl = seichi.cardImageUrl;

    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildCardFallback(seichi);
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        cacheWidth: 1200,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildCardFallback(seichi);
        },
      ),
    );
  }

  Widget _buildCardFallback(Seichi seichi) {
    return Container(
      width: double.infinity,
      height: 240,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            seichi.card,
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(seichi.icon, style: const TextStyle(fontSize: 34)),
        ],
      ),
    );
  }

  Widget _buildCardGallery() {
    final filteredList = _filteredSeichiList;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '札ギャラリー',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (!_isLoadingSeichi && _seichiList.isNotEmpty)
                Text(
                  '${filteredList.length} / ${_seichiList.length}札',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '札をタップすると詳細を確認できます',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          if (!_isLoadingSeichi &&
              _seichiErrorMessage == null &&
              _seichiList.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in const <String>['すべて', '獲得済み', '未獲得'])
                  ChoiceChip(
                    label: Text(filter),
                    selected: _galleryFilter == filter,
                    onSelected: (_) {
                      setState(() {
                        _galleryFilter = filter;
                      });
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          if (_isLoadingSeichi)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_seichiErrorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 8),
                  Text(_seichiErrorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoadingSeichi = true;
                        _seichiErrorMessage = null;
                      });

                      _loadSeichiList();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('再読み込み'),
                  ),
                ],
              ),
            )
          else if (_seichiList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'このクエストには札が登録されていません。',
                textAlign: TextAlign.center,
              ),
            )
          else if (filteredList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _galleryFilter == '獲得済み' ? '獲得済みの札はまだありません。' : '未獲得の札はありません。',
                textAlign: TextAlign.center,
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                return _buildGalleryCard(filteredList[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGalleryCard(Seichi seichi) {
    final imageUrl = seichi.cardImageUrl;

    final collected = _collectedSeichiIds.contains(seichi.id);

    final isNext = widget.currentNextSeichiId == seichi.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _showSeichiDetail(seichi);
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: collected
                  ? Colors.green.withValues(alpha: 0.55)
                  : isNext
                  ? Colors.deepPurple.withValues(alpha: 0.55)
                  : Colors.grey.shade200,
              width: collected || isNext ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 360,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildGalleryFallback(seichi);
                              },
                            )
                          : _buildGalleryFallback(seichi),
                    ),

                    if (collected)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    if (isNext && !collected)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'NEXT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: collected
                            ? Colors.green.withValues(alpha: 0.10)
                            : Colors.deepPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        seichi.card,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: collected ? Colors.green : Colors.deepPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        seichi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryFallback(Seichi seichi) {
    return Container(
      color: Colors.deepPurple.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: Text(
        seichi.card,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participationColor = _participationColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('クエスト詳細'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.event.coverImageUrl != null &&
                      widget.event.coverImageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          widget.event.coverImageUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 1200,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade100,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey.shade400,
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
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.explore_outlined,
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.name,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
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
                    const SizedBox(height: 20),
                    Text(
                      widget.event.description,
                      style: TextStyle(
                        height: 1.6,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '開催情報',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _periodText(),
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_hasProgress) ...[
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '進捗',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.collectedCount}'
                            ' / '
                            '${widget.totalCount}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '$_progressPercent%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            _buildCardGallery(),

            if (widget.primaryActionLabel != null &&
                widget.onPrimaryAction != null) ...[
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isActionRunning ? null : _runPrimaryAction,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            if (widget.onSelectAnotherEvent != null) ...[
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onSelectAnotherEvent!();
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('別のクエストを見る'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
