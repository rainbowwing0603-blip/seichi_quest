import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../collection_history_service.dart';
import '../models/content_block.dart';
import '../models/event.dart';
import '../models/quest_item.dart';
import '../policies/collection_card_frame_policy.dart';
import '../services/content_block_service.dart';
import '../services/content_media_resolver.dart';

/// The rendering and export boundary for one collected item. No event-specific
/// labels or artwork are required for the card to render.
class CollectionCardPage extends StatefulWidget {
  const CollectionCardPage({
    super.key,
    required this.event,
    required this.item,
    required this.collectedCount,
    required this.totalCount,
    this.collectedAt,
    this.debugPreview = false,
  });

  final Event event;
  final QuestItem item;
  final int collectedCount;
  final int totalCount;
  final DateTime? collectedAt;
  final bool debugPreview;

  @override
  State<CollectionCardPage> createState() => _CollectionCardPageState();
}

class _CollectionCardPageState extends State<CollectionCardPage> {
  static const _gallery = MethodChannel(
    'jp.seichiquest.app/collection_card_gallery',
  );
  final _boundaryKey = GlobalKey();
  DateTime? _collectedAt;
  String? _subtitle;
  Uint8List? _artwork;
  Uint8List? _readingArtwork;
  bool _busy = false;
  bool _loadingContent = true;
  bool _hideArtwork = false;
  bool _longText = false;

  @override
  void initState() {
    super.initState();
    _collectedAt = widget.collectedAt;
    _loadContent();
  }

  Future<void> _loadContent() async {
    String? readingImagePath;
    try {
      final blocks = await ContentBlockService().loadForContent(
        widget.item.contentId,
      );
      final reading = blocks
          .where(
            (block) =>
                block.type == ContentBlockType.text &&
                (block.role == 'reading' || block.role == 'reading_card') &&
                block.body?.trim().isNotEmpty == true,
          )
          .firstOrNull;
      final readingCard = blocks
          .where(
            (block) =>
                block.type == ContentBlockType.image &&
                block.role == 'reading_card',
          )
          .firstOrNull;
      readingImagePath = readingCard?.mediaPath;
      if (mounted) {
        setState(() {
          _subtitle = reading?.body?.trim();
        });
      }
    } catch (_) {
      // Optional copy does not block card export when offline.
    }

    if (!widget.debugPreview) {
      try {
        final history = await CollectionHistoryService().loadHistory(
          eventId: widget.event.id,
        );
        final row = history
            .where(
              (entry) =>
                  entry['event_content_id']?.toString() == widget.item.id,
            )
            .firstOrNull;
        final acquired = DateTime.tryParse(
          row?['collected_at']?.toString() ?? '',
        );
        if (mounted && acquired != null) {
          setState(() => _collectedAt = acquired);
        }
      } catch (_) {
        // History is cached independently and the date is optional.
      }
    }

    final resolver = ContentMediaResolver();
    final pictureUrl = resolver.resolve(widget.item.primaryImageUrl);
    final readingUrl = resolver.resolve(readingImagePath);
    if (pictureUrl != null) {
      final bytes = await _downloadImage(pictureUrl);
      if (mounted && bytes != null) setState(() => _artwork = bytes);
    }
    if (readingUrl != null) {
      final bytes = await _downloadImage(readingUrl);
      if (mounted && bytes != null) setState(() => _readingArtwork = bytes);
    }
    if (mounted) setState(() => _loadingContent = false);
  }

  Future<Uint8List?> _downloadImage(String url) async {
    if (url.startsWith('assets/')) {
      try {
        final data = await rootBundle.load(url);
        return data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      } catch (_) {
        return null;
      }
    }

    final client = HttpClient();
    try {
      final response = await client
          .getUrl(Uri.parse(url))
          .then((r) => r.close());
      if (response.statusCode != HttpStatus.ok) return null;
      final builder = BytesBuilder();
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<Uint8List> _render() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('画像の生成に失敗しました');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _export({required bool save, required bool share}) async {
    if (_busy || _loadingContent) return;
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      if (save) {
        await _gallery.invokeMethod<void>('savePng', <String, Object>{
          'bytes': bytes,
          'name': 'seichi_quest_${DateTime.now().millisecondsSinceEpoch}.png',
        });
      }
      if (share) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'image/png',
                name: 'seichi_quest.png',
              ),
            ],
            fileNameOverrides: ['seichi_quest.png'],
            sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        );
      }
      if (mounted && save) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('写真に保存しました')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('画像を保存・共有できませんでした: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _collectedAt?.toLocal();
    final dateText = date == null
        ? null
        : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}  '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('獲得記念カード')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: _card(dateText),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_loadingContent)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('カードの画像と情報を読み込み中…'),
              ),
            if (widget.debugPreview)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('画像なし'),
                      selected: _hideArtwork,
                      onSelected: (value) =>
                          setState(() => _hideArtwork = value),
                    ),
                    FilterChip(
                      label: const Text('日本語長文'),
                      selected: _longText,
                      onSelected: (value) => setState(() => _longText = value),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy || _loadingContent
                        ? null
                        : () => _export(save: true, share: false),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('写真に保存'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _loadingContent
                        ? null
                        : () => _export(save: false, share: true),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('共有'),
                  ),
                  FilledButton(
                    onPressed: _busy || _loadingContent
                        ? null
                        : () => _export(save: true, share: true),
                    child: const Text('保存して共有'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String? dateText) {
    final hasArtwork = _artwork != null && !_hideArtwork;
    final readingText = _subtitle;
    final descriptionText = _longText
        ? 'この旅で出会った景色と物語を、いつまでも大切にしたい。季節を越えてもう一度訪れたくなる、心に残る場所の記念です。'
        : widget.item.description.trim();
    final hasReading =
        widget.debugPreview ||
        _readingArtwork != null ||
        readingText?.trim().isNotEmpty == true;
    return SizedBox(
      width: 360,
      height: 600,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: AssetImage(
                const CollectionCardFramePolicy().assetFor(widget.event),
              ),
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .36, .57, 1],
                  colors: [
                    Color(0x6605122A),
                    Color(0x0005122A),
                    Color(0xB3071830),
                    Color(0xF8041124),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 24, 25, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC061B30),
                          border: Border.all(color: const Color(0xAA75E4E5)),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          widget.debugPreview ? 'PREVIEW' : 'COLLECTED',
                          style: const TextStyle(
                            color: Color(0xFFE8FFFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 35,
                        height: 35,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xCC061B30),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xAA75E4E5)),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF90F1EC),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (hasReading)
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 145,
                              child: AspectRatio(
                                aspectRatio: 730 / 909,
                                child: _buildKarutaPanel(
                                  image: hasArtwork ? _artwork : null,
                                  fallbackText: widget.item.title,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 145,
                              child: AspectRatio(
                                aspectRatio: 730 / 909,
                                child: _buildKarutaPanel(
                                  image: _hideArtwork ? null : _readingArtwork,
                                  fallbackText:
                                      readingText?.trim().isNotEmpty == true
                                      ? readingText!
                                      : (widget.item.description.trim().isNotEmpty
                                          ? widget.item.description.trim()
                                          : widget.item.title),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (hasArtwork)
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: 250,
                          child: AspectRatio(
                            aspectRatio: 730 / 909,
                            child: _buildKarutaPanel(
                              image: _artwork,
                              fallbackText: widget.item.title,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xAA061B30),
                          border: Border.all(
                            color: const Color(0x8875E4E5),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.item.title,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            height: 1.22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 21),
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF76EEE8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (descriptionText.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      descriptionText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE0ECF0),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (!hasReading &&
                      readingText?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Text(
                      readingText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE0ECF0),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66304C66),
                      border: Border.all(color: const Color(0x8875E4E5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${widget.collectedCount} / ${widget.totalCount}',
                          style: const TextStyle(
                            color: Color(0xFFADFFF2),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        if (dateText != null)
                          Flexible(
                            child: Text(
                              dateText,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'SEICHI QUEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w900,
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

  Widget _buildKarutaPanel({
    String? label,
    required Uint8List? image,
    required String fallbackText,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xEAF3FBFC),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88010C20),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          if (label?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF23394A),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF7F6F2),
              alignment: Alignment.center,
              child: image != null
                  ? Image.memory(
                      image,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      width: double.infinity,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        fallbackText,
                        textAlign: TextAlign.center,
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1B3441),
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
