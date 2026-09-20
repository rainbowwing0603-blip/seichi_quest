import '../models/content_block.dart';

class ContentBlockPresentation {
  const ContentBlockPresentation({
    required this.blocks,
    required this.showLegacyReading,
    required this.showLegacyDescription,
    required this.showLegacyImage,
  });

  final List<ContentBlock> blocks;
  final bool showLegacyReading;
  final bool showLegacyDescription;
  final bool showLegacyImage;
}

class ContentBlockPresentationPolicy {
  const ContentBlockPresentationPolicy();

  ContentBlockPresentation resolve(List<ContentBlock> blocks) {
    final visibleBlocks = blocks
        .where((block) => block.type != ContentBlockType.unsupported)
        .toList(growable: false);

    final roles = visibleBlocks.map((block) => block.role).toSet();

    return ContentBlockPresentation(
      blocks: visibleBlocks,
      showLegacyReading: !roles.contains('reading'),
      showLegacyDescription:
          !roles.contains('description') && !roles.contains('about'),
      showLegacyImage: !roles.contains('picture_card'),
    );
  }
}
