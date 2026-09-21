import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/content_block.dart';
import 'package:seichi_quest/services/content_media_resolver.dart';
import 'package:seichi_quest/widgets/content_block_renderer.dart';

class FakeContentMediaResolver extends ContentMediaResolver {
  FakeContentMediaResolver();

  @override
  String? resolve(String? mediaPath) {
    final value = mediaPath?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return 'https://example.com/$value';
  }
}

ContentBlock block({
  required String id,
  required ContentBlockType type,
  String role = 'default',
  String? title,
  String? body,
  String? mediaPath,
  String? linkUrl,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) {
  return ContentBlock(
    id: id,
    contentId: 'content-1',
    type: type,
    role: role,
    title: title,
    body: body,
    mediaPath: mediaPath,
    altText: null,
    linkUrl: linkUrl,
    displayOrder: 0,
    metadata: metadata,
  );
}

Widget app(List<ContentBlock> blocks) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ContentBlockRenderer(
          blocks: blocks,
          mediaResolver: FakeContentMediaResolver(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty media blocks do not leave phantom spacing', (tester) async {
    await tester.pumpWidget(
      app([
        block(
          id: 'missing-image',
          type: ContentBlockType.image,
          role: 'hero',
        ),
        block(
          id: 'text',
          type: ContentBlockType.text,
          title: '説明',
          body: '本文',
        ),
      ]),
    );

    expect(find.text('説明'), findsOneWidget);
    expect(find.text('本文'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('multiple images render through the same generic renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([
        block(
          id: 'picture',
          type: ContentBlockType.image,
          role: 'picture_card',
          mediaPath: 'picture.webp',
        ),
        block(
          id: 'reading',
          type: ContentBlockType.image,
          role: 'reading_card',
          mediaPath: 'reading.webp',
        ),
      ]),
    );

    expect(find.byType(Image), findsNWidgets(2));
    final ratios = tester
        .widgetList<AspectRatio>(find.byType(AspectRatio))
        .map((widget) => widget.aspectRatio)
        .toList();
    expect(ratios, everyElement(closeTo(4 / 3, 0.001)));
  });

  testWidgets('multiple gallery images stay generic and ordered', (tester) async {
    await tester.pumpWidget(
      app([
        block(
          id: 'gallery-1',
          type: ContentBlockType.image,
          role: 'gallery',
          title: '関連画像',
          mediaPath: 'gallery-1.webp',
        ),
        block(
          id: 'gallery-2',
          type: ContentBlockType.image,
          role: 'gallery',
          mediaPath: 'gallery-2.webp',
        ),
      ]),
    );

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('関連画像'), findsOneWidget);
  });

  testWidgets('hero and product use role-aware media presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([
        block(
          id: 'hero',
          type: ContentBlockType.image,
          role: 'hero',
          mediaPath: 'hero.webp',
        ),
        block(
          id: 'product',
          type: ContentBlockType.image,
          role: 'product',
          mediaPath: 'product.webp',
        ),
      ]),
    );

    final ratios = tester
        .widgetList<AspectRatio>(find.byType(AspectRatio))
        .map((widget) => widget.aspectRatio)
        .toList();
    expect(ratios[0], closeTo(16 / 9, 0.001));
    expect(ratios[1], 1);

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images[0].fit, BoxFit.cover);
    expect(images[1].fit, BoxFit.contain);
  });

  testWidgets('semantic text roles expose clear section cues', (tester) async {
    await tester.pumpWidget(
      app([
        block(
          id: 'reading',
          type: ContentBlockType.text,
          role: 'reading',
          title: '読み札',
          body: '県都前橋 生糸の市',
        ),
        block(
          id: 'field-guide',
          type: ContentBlockType.text,
          role: 'field_guide',
          title: '現地で歴史をたどる',
          body: '現地で見るポイント',
        ),
      ]),
    );

    expect(find.text('読み札'), findsOneWidget);
    expect(find.text('現地で歴史をたどる'), findsOneWidget);
    expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
  });

  testWidgets('metadata can override image aspect ratio generically', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([
        block(
          id: 'custom',
          type: ContentBlockType.image,
          role: 'gallery',
          mediaPath: 'custom.webp',
          metadata: const {'aspect_ratio': 2.0},
        ),
      ]),
    );

    final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, 2);
  });
}
