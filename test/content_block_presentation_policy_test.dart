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

  test('unsupported future blocks cannot suppress legacy fallback', () {
    final result = policy.resolve([
      block(type: ContentBlockType.unsupported, role: 'description'),
    ]);

    expect(result.blocks, isEmpty);
    expect(result.showLegacyDescription, isTrue);
  });
}
