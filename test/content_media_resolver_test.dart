import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/content_media_resolver.dart';

void main() {
  group('ContentMediaResolver', () {
    test('empty media path resolves without Supabase initialization', () {
      final resolver = ContentMediaResolver();

      expect(resolver.resolve(null), isNull);
      expect(resolver.resolve('   '), isNull);
    });

    test('absolute URL resolves without Supabase initialization', () {
      final resolver = ContentMediaResolver();

      expect(
        resolver.resolve('https://example.com/image.webp'),
        'https://example.com/image.webp',
      );
    });

    test('relative path with empty bucket is safely ignored', () {
      final resolver = ContentMediaResolver(defaultBucket: '');

      expect(resolver.resolve('cards/a.webp'), isNull);
    });
  });
}
