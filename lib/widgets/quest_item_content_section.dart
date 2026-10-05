import 'dart:async';

import 'package:flutter/material.dart';

import '../models/content_block.dart';
import '../models/quest_item.dart';
import '../services/content_block_presentation_policy.dart';
import '../services/content_block_service.dart';
import '../services/content_reveal_policy.dart';
import '../services/story_preview_service.dart';
import '../services/story_rewarded_ad_service.dart';
import 'content_block_renderer.dart';
import 'quest_ui.dart';

class QuestItemContentSection extends StatefulWidget {
  const QuestItemContentSection({
    super.key,
    required this.item,
    this.showFallbackImage = true,
    this.showFallbackText = true,
    this.fallbackDescriptionOverride,
    this.collected = false,
    this._contentBlockService,
    this.previewService,
    this.rewardedAdService,
  });

  final QuestItem item;
  final bool showFallbackImage;
  final bool showFallbackText;
  final String? fallbackDescriptionOverride;
  final bool collected;
  final ContentBlockService? _contentBlockService;
  final StoryPreviewService? previewService;
  final StoryRewardedAdService? rewardedAdService;

  @override
  State<QuestItemContentSection> createState() =>
      _QuestItemContentSectionState();
}

class _QuestItemContentSectionState extends State<QuestItemContentSection> with WidgetsBindingObserver {
  static const ContentBlockPresentationPolicy _presentationPolicy =
      ContentBlockPresentationPolicy();

  Future<List<ContentBlock>>? _contentFuture;
  Timer? _expiryTimer;
  Timer? _refreshTimer;
  bool _previewActive = false;
  bool _watching = false;
  bool _hasPreviewableStory = false;
  int _generation = 0;
  String? _previewUser;
  late final StoryPreviewService _previewService =
      widget.previewService ?? StoryPreviewService();
  StoryRewardedAdService get _rewardedAds =>
      widget.rewardedAdService ?? StoryRewardedAdService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant QuestItemContentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.contentId.trim() != oldWidget.item.contentId.trim() ||
        widget._contentBlockService != oldWidget._contentBlockService) {
      _loadContent();
    }
  }

  void _loadContent() {
    _generation++;
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    _previewActive = false;
    _hasPreviewableStory = false;
    final generation = _generation;
    final contentId = widget.item.contentId.trim();
    _contentFuture = contentId.isEmpty
        ? null
        : (widget._contentBlockService ?? ContentBlockService())
              .loadForContent(contentId);
    unawaited(_contentFuture?.then((blocks) {
      if (!mounted || generation != _generation || widget.collected ||
          !blocks.any(ContentRevealPolicy.isStoryPreviewEligible)) {
        return;
      }
      _hasPreviewableStory = true;
      unawaited(_refreshPreview());
      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        unawaited(_refreshPreview());
      });
    }, onError: (Object _) {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasPreviewableStory) {
      if (_previewActive) setState(() => _previewActive = false);
      unawaited(_refreshPreview());
    }
  }

  Future<void> _refreshPreview() async {
    final generation = _generation;
    try {
      final user = await _previewService.ensureUser();
      final remaining = await _previewService.remaining(widget.item.contentId.trim());
      if (user != _previewService.currentUserId) return;
      if (!mounted || generation != _generation) return;
      _setPreview(remaining);
    } catch (_) {
      if (mounted && generation == _generation) _setPreview(null);
    }
  }

  void _setPreview(Duration? remaining) {
    _expiryTimer?.cancel();
    setState(() {
      _previewActive = remaining != null && remaining > Duration.zero;
      _previewUser = _previewService.currentUserId;
    });
    if (_previewActive) {
      _expiryTimer = Timer(remaining!, () {
        if (mounted) setState(() => _previewActive = false);
      });
    }
  }

  Future<void> _watchStoryAd() async {
    if (_watching) return;
    final contentId = widget.item.contentId.trim();
    final generation = _generation;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('物語を1時間読む'),
        content: const Text('広告を見て報酬を受け取ると、この場所の物語を1時間読めます。スタンプは獲得されません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('今は見ない')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('広告を見る')),
        ],
      ),
    );
    if (accepted != true || !mounted || generation != _generation) return;
    setState(() => _watching = true);
    try {
      final user = await _previewService.ensureUser();
      final earned = await _rewardedAds.show(canPresent: () => mounted &&
          generation == _generation && !widget.collected &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
      if (!earned) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('閲覧権は付与されていません。広告を表示できない場合は、時間をおいてお試しください。')),
        );
        }
        return;
      }
      final remaining = await _previewService.grant(contentId, expectedUserId: user);
      if (mounted && generation == _generation) _setPreview(remaining);
    } catch (_) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('閲覧期限を確認できませんでした。通信状態を確認してお試しください。')),
      );
      }
    } finally {
      if (mounted) setState(() => _watching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentId = widget.item.contentId.trim();

    if (contentId.isEmpty) {
      return _buildFallbackContent(
        context,
        const ContentBlockPresentation(
          blocks: <ContentBlock>[],
          showFallbackDescription: true,
          showFallbackImage: true,
        ),
      );
    }

    return FutureBuilder<List<ContentBlock>>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[CONTENT_BLOCKS] quest item content load failed: ${snapshot.error}',
          );
        }

        final presentation = _presentationPolicy.resolveForCollectionState(
          snapshot.data ?? const <ContentBlock>[],
          collected: widget.collected,
          storyPreview: _previewActive &&
              _previewUser == _previewService.currentUserId,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFallbackContent(context, presentation),
            if (!widget.collected && (snapshot.data ?? const <ContentBlock>[])
                .any(ContentRevealPolicy.isStoryPreviewEligible)) ...[
              const SizedBox(height: 14),
              if (_previewActive && _previewUser == _previewService.currentUserId)
                const Text('物語を一時閲覧中。現地でスタンプを獲得すると、期限なしで読めます。')
              else if (_rewardedAds.available)
                OutlinedButton.icon(
                  onPressed: _watching ? null : _watchStoryAd,
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(_watching ? '広告を準備中…' : '広告を見て物語を1時間読む'),
                )
              else
                const Text('この物語は現地でスタンプを獲得すると読めます。'),
            ],
            if (presentation.blocks.isNotEmpty) ...[
              if (_hasVisibleFallbackContent(presentation))
                const SizedBox(height: 14),
              QuestGlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: ContentBlockRenderer(blocks: presentation.blocks),
              ),
            ],
          ],
        );
      },
    );
  }

  bool _hasVisibleFallbackContent(ContentBlockPresentation presentation) {
    final imageUrl = widget.item.primaryImageUrl?.trim() ?? '';
    final description =
        widget.fallbackDescriptionOverride ?? widget.item.description;

    return (widget.showFallbackImage &&
            presentation.showFallbackImage &&
            imageUrl.isNotEmpty) ||
        (widget.showFallbackText &&
            presentation.showFallbackDescription &&
            description.trim().isNotEmpty);
  }

  Widget _buildFallbackContent(
    BuildContext context,
    ContentBlockPresentation presentation,
  ) {
    final widgets = <Widget>[];
    final imageUrl = widget.item.primaryImageUrl?.trim() ?? '';
    final description =
        widget.fallbackDescriptionOverride ?? widget.item.description;

    if (widget.showFallbackImage &&
        presentation.showFallbackImage &&
        imageUrl.isNotEmpty) {
      widgets.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            imageUrl,
            cacheWidth: (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .ceil()
                .clamp(1, 2048),
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      );
    }

    if (widget.showFallbackText &&
        presentation.showFallbackDescription &&
        description.trim().isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 14));
      }
      widgets.add(
        Text(
          description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
        ),
      );
    }

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}
