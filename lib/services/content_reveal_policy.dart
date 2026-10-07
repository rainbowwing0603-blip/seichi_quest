import '../models/content_block.dart';

enum ContentRevealMode {
  always,
  afterCollection,
  hidden,
}

abstract final class ContentRevealPolicy {
  static const String metadataKey = 'visibility';

  static ContentRevealMode modeFor(ContentBlock block) {
    final raw = block.metadata[metadataKey]?.toString().trim().toLowerCase();

    return switch (raw) {
      'after_collection' => ContentRevealMode.afterCollection,
      'hidden' => ContentRevealMode.hidden,
      _ => ContentRevealMode.always,
    };
  }

  static bool isVisible(
    ContentBlock block, {
    required bool collected,
    bool storyPreview = false,
  }) {
    return switch (modeFor(block)) {
      ContentRevealMode.always => true,
      ContentRevealMode.afterCollection => collected ||
          (storyPreview && isStoryPreviewEligible(block)),
      ContentRevealMode.hidden => false,
    };
  }

  static bool isStoryPreviewEligible(ContentBlock block) =>
      modeFor(block) == ContentRevealMode.afterCollection &&
      const {'description', 'history', 'field_guide', 'story'}.contains(block.role);

  static List<ContentBlock> visibleBlocks(
    Iterable<ContentBlock> blocks, {
    required bool collected,
    bool storyPreview = false,
  }) {
    return blocks
        .where((block) => isVisible(block, collected: collected, storyPreview: storyPreview))
        .toList(growable: false);
  }
}
