import 'package:flutter/material.dart';

import '../models/content_block.dart';
import '../models/quest_item.dart';
import '../services/content_block_presentation_policy.dart';
import '../services/content_block_service.dart';
import 'content_block_renderer.dart';
import 'quest_ui.dart';

class QuestItemContentSection extends StatelessWidget {
  const QuestItemContentSection({
    super.key,
    required this.item,
    this.showFallbackImage = true,
    this.showFallbackText = true,
    this.fallbackDescriptionOverride,
    this.collected = false,
    this._contentBlockService,
  });

  static const ContentBlockPresentationPolicy _presentationPolicy =
      ContentBlockPresentationPolicy();

  final QuestItem item;
  final bool showFallbackImage;
  final bool showFallbackText;
  final String? fallbackDescriptionOverride;
  final bool collected;
  final ContentBlockService? _contentBlockService;

  @override
  Widget build(BuildContext context) {
    final contentId = item.contentId.trim();

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

    final contentBlockService = _contentBlockService ?? ContentBlockService();

    return FutureBuilder<List<ContentBlock>>(
      future: contentBlockService.loadForContent(contentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[CONTENT_BLOCKS] quest item content load failed: ${snapshot.error}',
          );
        }

        final presentation = _presentationPolicy.resolveForCollectionState(
          snapshot.data ?? const <ContentBlock>[],
          collected: collected,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFallbackContent(context, presentation),
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
    final imageUrl = item.primaryImageUrl?.trim() ?? '';
    final description = fallbackDescriptionOverride ?? item.description;

    return (showFallbackImage &&
            presentation.showFallbackImage &&
            imageUrl.isNotEmpty) ||
        (showFallbackText &&
            presentation.showFallbackDescription &&
            description.trim().isNotEmpty);
  }

  Widget _buildFallbackContent(
    BuildContext context,
    ContentBlockPresentation presentation,
  ) {
    final widgets = <Widget>[];
    final imageUrl = item.primaryImageUrl?.trim() ?? '';
    final description = fallbackDescriptionOverride ?? item.description;

    if (showFallbackImage &&
        presentation.showFallbackImage &&
        imageUrl.isNotEmpty) {
      widgets.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            imageUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      );
    }

    if (showFallbackText &&
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
