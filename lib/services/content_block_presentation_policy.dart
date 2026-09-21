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
    final renderableBlocks = blocks
        .where(_canRepresentContent)
        .toList(growable: false);

    final roles = renderableBlocks.map((block) => block.role).toSet();

    return ContentBlockPresentation(
      blocks: renderableBlocks,
      showLegacyReading: !roles.contains('reading'),
      showLegacyDescription:
          !roles.contains('description') && !roles.contains('about'),
      showLegacyImage: !roles.contains('picture_card'),
    );
  }

  bool _canRepresentContent(ContentBlock block) {
    return switch (block.type) {
      ContentBlockType.text => _hasText(block.body),
      ContentBlockType.image => _hasText(block.mediaPath),
      ContentBlockType.link => _isValidWebUri(block.linkUrl),
      ContentBlockType.unsupported => false,
    };
  }

  bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;

  bool _isValidWebUri(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
