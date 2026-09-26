import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/quest_item.dart';
import 'package:seichi_quest/policies/quest_presentation_policy.dart';

void main() {
  const policy = QuestPresentationPolicy();

  QuestItem item({String? imageUrl}) {
    return QuestItem(
      id: 'event-content-1',
      eventContentId: 'event-content-1',
      contentId: 'content-1',
      placeId: 'place-1',
      contentKey: 'generic-content',
      title: '汎用スポット',
      latitude: 36.0,
      longitude: 139.0,
      radiusMeters: 200,
      description: '',
      icon: '📍',
      primaryImageUrl: imageUrl,
      displayOrder: 0,
      isActive: true,
    );
  }

  group('QuestPresentationPolicy', () {
    test('未獲得では画像があっても公開せずロック表示にする', () {
      final presentation = policy.forItem(
        item(imageUrl: 'https://example.com/image.jpg'),
        collected: false,
      );

      expect(presentation.hasPrimaryImage, isTrue);
      expect(presentation.revealPrimaryImage, isFalse);
      expect(presentation.showLockedPlaceholder, isTrue);
    });

    test('獲得済みで画像があれば画像を公開する', () {
      final presentation = policy.forItem(
        item(imageUrl: 'https://example.com/image.jpg'),
        collected: true,
      );

      expect(presentation.hasPrimaryImage, isTrue);
      expect(presentation.revealPrimaryImage, isTrue);
      expect(presentation.showLockedPlaceholder, isFalse);
    });

    test('画像なしの汎用コンテンツでも獲得済み表示が成立する', () {
      final presentation = policy.forItem(
        item(),
        collected: true,
      );

      expect(presentation.hasPrimaryImage, isFalse);
      expect(presentation.revealPrimaryImage, isFalse);
      expect(presentation.showLockedPlaceholder, isFalse);
    });

    test('空白だけの画像URLは画像なしとして扱う', () {
      final presentation = policy.forItem(
        item(imageUrl: '   '),
        collected: true,
      );

      expect(presentation.hasPrimaryImage, isFalse);
      expect(presentation.revealPrimaryImage, isFalse);
    });
  });
}
