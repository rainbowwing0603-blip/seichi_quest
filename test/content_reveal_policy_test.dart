import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/content_block.dart';
import 'package:seichi_quest/services/content_reveal_policy.dart';

ContentBlock blockWithVisibility(String? visibility) {
  return ContentBlock(
    id: 'block',
    contentId: 'content',
    type: ContentBlockType.text,
    role: 'description',
    displayOrder: 10,
    metadata: visibility == null
        ? const <String, dynamic>{}
        : <String, dynamic>{'visibility': visibility},
  );
}

void main() {
  group('ContentRevealPolicy', () {
    test('未設定は互換性のため常時表示', () {
      final block = blockWithVisibility(null);

      expect(
        ContentRevealPolicy.isVisible(block, collected: false),
        isTrue,
      );
    });

    test('alwaysは獲得前後とも表示', () {
      final block = blockWithVisibility('always');

      expect(
        ContentRevealPolicy.isVisible(block, collected: false),
        isTrue,
      );
      expect(
        ContentRevealPolicy.isVisible(block, collected: true),
        isTrue,
      );
    });

    test('after_collectionは獲得後だけ表示', () {
      final block = blockWithVisibility('after_collection');

      expect(
        ContentRevealPolicy.isVisible(block, collected: false),
        isFalse,
      );
      expect(
        ContentRevealPolicy.isVisible(block, collected: true),
        isTrue,
      );
    });

    test('hiddenは獲得状態に関係なく非表示', () {
      final block = blockWithVisibility('hidden');

      expect(
        ContentRevealPolicy.isVisible(block, collected: false),
        isFalse,
      );
      expect(
        ContentRevealPolicy.isVisible(block, collected: true),
        isFalse,
      );
    });

    test('未知の値は既存データを壊さず常時表示', () {
      final block = blockWithVisibility('future_mode');

      expect(
        ContentRevealPolicy.modeFor(block),
        ContentRevealMode.always,
      );
    });

    test('複数ブロックから現在表示可能なものだけを返す', () {
      final blocks = [
        blockWithVisibility('always'),
        ContentBlock(
          id: 'after',
          contentId: 'content',
          type: ContentBlockType.text,
          role: 'secret',
          displayOrder: 20,
          metadata: const {'visibility': 'after_collection'},
        ),
        ContentBlock(
          id: 'hidden',
          contentId: 'content',
          type: ContentBlockType.text,
          role: 'internal',
          displayOrder: 30,
          metadata: const {'visibility': 'hidden'},
        ),
      ];

      expect(
        ContentRevealPolicy.visibleBlocks(blocks, collected: false)
            .map((block) => block.id),
        ['block'],
      );
      expect(
        ContentRevealPolicy.visibleBlocks(blocks, collected: true)
            .map((block) => block.id),
        ['block', 'after'],
      );
    });
  });
}
