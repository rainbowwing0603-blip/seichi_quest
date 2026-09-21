import 'package:flutter/material.dart';

import '../models/content_block.dart';
import '../models/seichi.dart';
import '../services/content_block_presentation_policy.dart';
import '../services/content_block_service.dart';
import 'content_block_renderer.dart';
import 'quest_ui.dart';

class QuestItemContentSection extends StatelessWidget {
  const QuestItemContentSection({
    super.key,
    required this.item,
    this.showLegacyImage = true,
    this.showLegacyText = true,
    this.legacyDescriptionOverride,
    this.collected = false,
    ContentBlockService? contentBlockService,
  }) : _contentBlockService = contentBlockService;

  static const ContentBlockPresentationPolicy _presentationPolicy =
      ContentBlockPresentationPolicy();

  final Seichi item;
  final bool showLegacyImage;
  final bool showLegacyText;
  final String? legacyDescriptionOverride;
  final bool collected;
  final ContentBlockService? _contentBlockService;

  @override
  Widget build(BuildContext context) {
    final contentId = item.contentId?.trim() ?? '';

    if (contentId.isEmpty) {
      return _buildLegacyContent(
        context,
        const ContentBlockPresentation(
          blocks: <ContentBlock>[],
          showLegacyReading: true,
          showLegacyDescription: true,
          showLegacyImage: true,
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
            _buildLegacyContent(context, presentation),
            if (presentation.blocks.isNotEmpty) ...[
              if (_hasVisibleLegacyContent(presentation))
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

  bool _hasVisibleLegacyContent(ContentBlockPresentation presentation) {
    final imageUrl = item.cardImageUrl?.trim() ?? '';
    final description = legacyDescriptionOverride ?? item.description;

    return (showLegacyImage &&
            presentation.showLegacyImage &&
            imageUrl.isNotEmpty) ||
        (showLegacyText &&
            presentation.showLegacyReading &&
            item.reading.trim().isNotEmpty) ||
        (showLegacyText &&
            presentation.showLegacyDescription &&
            description.trim().isNotEmpty);
  }

  Widget _buildLegacyContent(
    BuildContext context,
    ContentBlockPresentation presentation,
  ) {
    final widgets = <Widget>[];
    final imageUrl = item.cardImageUrl?.trim() ?? '';
    final description = legacyDescriptionOverride ?? item.description;

    if (showLegacyImage &&
        presentation.showLegacyImage &&
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

    if (showLegacyText &&
        presentation.showLegacyReading &&
        item.reading.trim().isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 14));
      }
      widgets.add(
        Text(
          item.reading,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
      );
    }

    if (showLegacyText &&
        presentation.showLegacyDescription &&
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
