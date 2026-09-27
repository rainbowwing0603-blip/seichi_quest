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
import '../policies/quest_event_theme_policy.dart';
import '../services/content_block_service.dart';
import '../services/content_media_resolver.dart';

/// The rendering and export boundary for one collected item. No event-specific
/// labels or artwork are required for the card to render.
class CollectionCardPage extends StatefulWidget {
  const CollectionCardPage({super.key, required this.event, required this.item,
    required this.collectedCount, required this.totalCount, this.collectedAt});

  final Event event;
  final QuestItem item;
  final int collectedCount;
  final int totalCount;
  final DateTime? collectedAt;

  @override
  State<CollectionCardPage> createState() => _CollectionCardPageState();
}

class _CollectionCardPageState extends State<CollectionCardPage> {
  static const _gallery = MethodChannel('jp.seichiquest.app/collection_card_gallery');
  final _boundaryKey = GlobalKey();
  DateTime? _collectedAt;
  String? _subtitle;
  Uint8List? _artwork;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _collectedAt = widget.collectedAt;
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final results = await Future.wait<Object>([
        ContentBlockService().loadForContent(widget.item.contentId),
        CollectionHistoryService().loadHistory(eventId: widget.event.id),
      ]);
      final blocks = results[0] as List<ContentBlock>;
      final history = results[1] as List<Map<String, dynamic>>;
      final row = history.where((entry) =>
          entry['event_content_id']?.toString() == widget.item.id).firstOrNull;
      final reading = blocks.where((block) => block.type == ContentBlockType.text &&
          (block.role == 'reading' || block.role == 'reading_card')).firstOrNull;
      if (mounted) {
        setState(() {
          _subtitle = reading?.body ?? reading?.title;
          _collectedAt = DateTime.tryParse(row?['collected_at']?.toString() ?? '') ?? _collectedAt;
        });
      }
    } catch (_) {
      // A disconnected device can still export a card without optional copy.
    }
    final url = ContentMediaResolver().resolve(widget.item.primaryImageUrl);
    if (url == null) return;
    try {
      final response = await HttpClient().getUrl(Uri.parse(url)).then((r) => r.close());
      if (response.statusCode != 200) return;
      final builder = BytesBuilder();
      await for (final chunk in response) { builder.add(chunk); }
      if (mounted) setState(() => _artwork = builder.takeBytes());
    } catch (_) {
      // Missing artwork uses the same typographic layout as image-free events.
    }
  }

  Future<Uint8List> _render() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('画像の生成に失敗しました');
      return data.buffer.asUint8List();
    } finally { image.dispose(); }
  }

  Future<void> _export({required bool save, required bool share}) async {
    if (_busy) return;
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
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'seichi_quest.png')],
          fileNameOverrides: ['seichi_quest.png'],
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ));
      }
      if (mounted && save) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真に保存しました')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像を保存・共有できませんでした: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = const QuestEventThemePolicy().resolve(widget.event);
    final date = _collectedAt?.toLocal();
    final dateText = date == null ? null :
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}  '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('獲得記念カード')),
      body: SafeArea(child: Column(children: [
        Expanded(child: Center(child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(child: RepaintBoundary(key: _boundaryKey,
            child: _card(theme, dateText))),
        )))),
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _busy ? null : () => _export(save: true, share: false),
              icon: const Icon(Icons.download_rounded), label: const Text('写真に保存')),
            OutlinedButton.icon(onPressed: _busy ? null : () => _export(save: false, share: true),
              icon: const Icon(Icons.share_rounded), label: const Text('共有')),
            FilledButton(onPressed: _busy ? null : () => _export(save: true, share: true),
              child: const Text('保存して共有')),
          ])),
      ])),
    );
  }

  Widget _card(QuestEventTheme theme, String? dateText) {
    return Container(width: 360, height: 600, decoration: BoxDecoration(
      color: const Color(0xFFF7F5F0),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: theme.primary.withValues(alpha: .22), width: 2),
    ), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 8, color: theme.primary),
        Padding(padding: const EdgeInsets.fromLTRB(28, 26, 28, 0), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('COLLECTED', style: TextStyle(color: theme.primary, fontSize: 13,
              fontWeight: FontWeight.w800, letterSpacing: 3)),
            const SizedBox(height: 8),
            Text(widget.event.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5E6570))),
          ])),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(28, 18, 28, 16),
          child: _artwork == null
            ? Container(alignment: Alignment.center, decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primary.withValues(alpha: .12),
                  theme.accent.withValues(alpha: .18)]),
                borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.explore_outlined, size: 84,
                  color: theme.primary.withValues(alpha: .55)))
            : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(
                _artwork!, fit: BoxFit.contain, gaplessPlayback: true)))),
        Padding(padding: const EdgeInsets.fromLTRB(28, 0, 28, 20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 29, height: 1.2, fontWeight: FontWeight.w800,
                color: Color(0xFF192B35))),
            if (_subtitle?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(_subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF495761))),
            ],
            const SizedBox(height: 16),
            Divider(color: theme.primary.withValues(alpha: .25)),
            const SizedBox(height: 7),
            Row(children: [
              Text('${widget.collectedCount} / ${widget.totalCount}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.primary)),
              const Spacer(),
              if (dateText != null) Text(dateText, style: const TextStyle(fontSize: 11,
                color: Color(0xFF63717A))),
            ]),
            const SizedBox(height: 16),
            const Text('SEICHI QUEST', style: TextStyle(fontSize: 12,
              letterSpacing: 2.4, fontWeight: FontWeight.w800, color: Color(0xFF192B35))),
          ])),
      ])));
  }
}
