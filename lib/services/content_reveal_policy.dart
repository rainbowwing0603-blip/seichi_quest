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
  }) {
    return switch (modeFor(block)) {
      ContentRevealMode.always => true,
      ContentRevealMode.afterCollection => collected,
      ContentRevealMode.hidden => false,
    };
  }

  static List<ContentBlock> visibleBlocks(
    Iterable<ContentBlock> blocks, {
    required bool collected,
  }) {
    return blocks
        .where((block) => isVisible(block, collected: collected))
        .toList(growable: false);
  }
}
