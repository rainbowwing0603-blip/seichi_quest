import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/content_block.dart';
import 'package:seichi_quest/services/content_block_presentation_policy.dart';

ContentBlock block({
  required ContentBlockType type,
  required String role,
}) {
  return ContentBlock(
    id: '${type.name}-$role',
    contentId: 'content-1',
    type: type,
    role: role,
    title: null,
    body: type == ContentBlockType.text ? 'body' : null,
    mediaPath: type == ContentBlockType.image ? 'image.png' : null,
    altText: null,
    linkUrl: type == ContentBlockType.link ? 'https://example.com' : null,
    displayOrder: 0,
    metadata: const <String, dynamic>{},
  );
}

void main() {
  const policy = ContentBlockPresentationPolicy();

  test('no blocks keeps every legacy fallback visible', () {
    final result = policy.resolve(const <ContentBlock>[]);

    expect(result.blocks, isEmpty);
    expect(result.showLegacyReading, isTrue);
    expect(result.showLegacyDescription, isTrue);
    expect(result.showLegacyImage, isTrue);
  });

  test('semantic roles replace only matching legacy sections', () {
    final result = policy.resolve([
      block(type: ContentBlockType.text, role: 'reading'),
      block(type: ContentBlockType.text, role: 'description'),
      block(type: ContentBlockType.image, role: 'picture_card'),
      block(type: ContentBlockType.link, role: 'official'),
    ]);

    expect(result.showLegacyReading, isFalse);
    expect(result.showLegacyDescription, isFalse);
    expect(result.showLegacyImage, isFalse);
    expect(result.blocks, hasLength(4));
  });

  test('supplemental content does not hide legacy content', () {
    final result = policy.resolve([
      block(type: ContentBlockType.text, role: 'history'),
      block(type: ContentBlockType.image, role: 'gallery'),
      block(type: ContentBlockType.link, role: 'official'),
    ]);

    expect(result.showLegacyReading, isTrue);
    expect(result.showLegacyDescription, isTrue);
    expect(result.showLegacyImage, isTrue);
  });

  test('reading card and hero images are additive to legacy picture card', () {
    final result = policy.resolve([
      block(type: ContentBlockType.image, role: 'reading_card'),
      block(type: ContentBlockType.image, role: 'hero'),
    ]);

    expect(result.showLegacyImage, isTrue);
    expect(result.blocks, hasLength(2));
  });

  test('karuta card media is prioritized at the top of detail content', () {
    ContentBlock orderedBlock(String id, String role, int displayOrder) {
      return ContentBlock(
        id: id,
        contentId: 'content-1',
        type: role == 'reading' || role == 'description'
            ? ContentBlockType.text
            : ContentBlockType.image,
        role: role,
        title: null,
        body: role == 'reading' || role == 'description' ? 'body' : null,
        mediaPath: role == 'reading' || role == 'description'
            ? null
            : '$id.png',
        altText: null,
        linkUrl: null,
        displayOrder: displayOrder,
        metadata: const <String, dynamic>{},
      );
    }

    final result = policy.resolve([
      orderedBlock('description', 'description', 0),
      orderedBlock('reading', 'reading', 10),
      orderedBlock('reading-card', 'reading_card', 40),
      orderedBlock('picture-card', 'picture_card', 50),
    ]);

    expect(
      result.blocks.map((block) => block.role).toList(),
      ['picture_card', 'reading_card', 'reading', 'description'],
    );
  });

  test('unsupported future blocks cannot suppress legacy fallback', () {
    final result = policy.resolve([
      block(type: ContentBlockType.unsupported, role: 'description'),
    ]);

    expect(result.blocks, isEmpty);
    expect(result.showLegacyDescription, isTrue);
  });

  test('empty semantic blocks cannot suppress legacy fallback', () {
    final result = policy.resolve([
      ContentBlock(
        id: 'empty-reading',
        contentId: 'content-1',
        type: ContentBlockType.text,
        role: 'reading',
        title: '読み',
        body: '   ',
        mediaPath: null,
        altText: null,
        linkUrl: null,
        displayOrder: 0,
        metadata: const <String, dynamic>{},
      ),
      ContentBlock(
        id: 'empty-picture',
        contentId: 'content-1',
        type: ContentBlockType.image,
        role: 'picture_card',
        title: null,
        body: null,
        mediaPath: '   ',
        altText: null,
        linkUrl: null,
        displayOrder: 10,
        metadata: const <String, dynamic>{},
      ),
    ]);

    expect(result.blocks, isEmpty);
    expect(result.showLegacyReading, isTrue);
    expect(result.showLegacyImage, isTrue);
  });

  test('invalid link blocks are excluded from presentation', () {
    final result = policy.resolve([
      ContentBlock(
        id: 'invalid-link',
        contentId: 'content-1',
        type: ContentBlockType.link,
        role: 'official',
        title: '公式',
        body: null,
        mediaPath: null,
        altText: null,
        linkUrl: 'not-a-url',
        displayOrder: 0,
        metadata: const <String, dynamic>{},
      ),
    ]);

    expect(result.blocks, isEmpty);
  });
  test('after_collection semantic content preserves legacy fallback before collection', () {
    final protectedDescription = ContentBlock(
      id: 'protected-description',
      contentId: 'content-1',
      type: ContentBlockType.text,
      role: 'description',
      title: '解放後の説明',
      body: '獲得後だけ表示する説明',
      mediaPath: null,
      altText: null,
      linkUrl: null,
      displayOrder: 10,
      metadata: const <String, dynamic>{'visibility': 'after_collection'},
    );

    final before = policy.resolveForCollectionState(
      [protectedDescription],
      collected: false,
    );
    final after = policy.resolveForCollectionState(
      [protectedDescription],
      collected: true,
    );

    expect(before.blocks, isEmpty);
    expect(before.showLegacyDescription, isTrue);

    expect(after.blocks, hasLength(1));
    expect(after.showLegacyDescription, isFalse);
  });

  test('hidden semantic content never suppresses legacy fallback', () {
    final hiddenPicture = ContentBlock(
      id: 'hidden-picture',
      contentId: 'content-1',
      type: ContentBlockType.image,
      role: 'picture_card',
      title: null,
      body: null,
      mediaPath: 'picture.png',
      altText: null,
      linkUrl: null,
      displayOrder: 10,
      metadata: const <String, dynamic>{'visibility': 'hidden'},
    );

    for (final collected in [false, true]) {
      final result = policy.resolveForCollectionState(
        [hiddenPicture],
        collected: collected,
      );

      expect(result.blocks, isEmpty);
      expect(result.showLegacyImage, isTrue);
    }
  });

}
