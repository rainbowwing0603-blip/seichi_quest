import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/content_block.dart';

void main() {
  group('ContentBlock.fromMap', () {
    test('parses semantic fields and metadata', () {
      final block = ContentBlock.fromMap({
        'id': 'block-1',
        'content_id': 'content-1',
        'block_type': 'image',
        'role': 'picture_card',
        'title': '絵札',
        'body': '札画像の説明',
        'media_path': 'cards/a.webp',
        'alt_text': '上毛かるたの絵札',
        'link_url': null,
        'display_order': 2,
        'metadata': {
          'credit': 'Gunma',
          'licensed': true,
        },
      });

      expect(block.id, 'block-1');
      expect(block.contentId, 'content-1');
      expect(block.type, ContentBlockType.image);
      expect(block.role, 'picture_card');
      expect(block.title, '絵札');
      expect(block.body, '札画像の説明');
      expect(block.mediaPath, 'cards/a.webp');
      expect(block.altText, '上毛かるたの絵札');
      expect(block.displayOrder, 2);
      expect(block.metadata['credit'], 'Gunma');
      expect(block.metadata['licensed'], isTrue);
    });

    test('uses safe defaults for legacy rows', () {
      final block = ContentBlock.fromMap({
        'id': 'block-2',
        'content_id': 'content-2',
        'block_type': 'text',
        'body': '本文',
        'display_order': '3',
      });

      expect(block.role, 'default');
      expect(block.altText, isNull);
      expect(block.metadata, isEmpty);
      expect(block.displayOrder, 3);
    });

    test('keeps unknown block types unsupported', () {
      final block = ContentBlock.fromMap({
        'id': 'block-3',
        'content_id': 'content-3',
        'block_type': 'future_type',
        'role': 'default',
        'metadata': const <String, dynamic>{},
      });

      expect(block.type, ContentBlockType.unsupported);
    });
  });
}
