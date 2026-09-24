import '../models/content_block.dart';
import 'content_reveal_policy.dart';

class ContentBlockPresentation {
  const ContentBlockPresentation({
    required this.blocks,
    required this.showLegacyDescription,
    required this.showLegacyImage,
  });

  final List<ContentBlock> blocks;
  final bool showLegacyDescription;
  final bool showLegacyImage;
}

class ContentBlockPresentationPolicy {
  const ContentBlockPresentationPolicy();

  ContentBlockPresentation resolveForCollectionState(
    List<ContentBlock> blocks, {
    required bool collected,
  }) {
    final visibleBlocks = ContentRevealPolicy.visibleBlocks(
      blocks,
      collected: collected,
    );
    return resolve(visibleBlocks);
  }

  ContentBlockPresentation resolve(List<ContentBlock> blocks) {
    final renderableBlocks = blocks
        .where(_canRepresentContent)
        .toList(growable: false);

    final roles = renderableBlocks.map((block) => block.role).toSet();
    final orderedBlocks = [...renderableBlocks]..sort(_compareDisplayPriority);

    return ContentBlockPresentation(
      blocks: orderedBlocks,
      showLegacyDescription:
          !roles.contains('description') && !roles.contains('about'),
      showLegacyImage: !roles.contains('picture_card'),
    );
  }

  int _compareDisplayPriority(ContentBlock a, ContentBlock b) {
    final priorityCompare = _displayPriority(
      a.role,
    ).compareTo(_displayPriority(b.role));
    if (priorityCompare != 0) {
      return priorityCompare;
    }

    final orderCompare = a.displayOrder.compareTo(b.displayOrder);
    if (orderCompare != 0) {
      return orderCompare;
    }

    return a.id.compareTo(b.id);
  }

  int _displayPriority(String role) {
    return switch (role) {
      'picture_card' => 0,
      'reading_card' => 1,
      'reading' => 2,
      _ => 10,
    };
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
