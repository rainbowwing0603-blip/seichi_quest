import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/marker_cache_revision.dart';

void main() {
  group('MarkerCacheRevision', () {
    test('初期revisionは0', () {
      final revision = MarkerCacheRevision();

      expect(revision.value, 0);
      expect(revision.isCurrent(0), isTrue);
    });

    test('変更通知ごとにrevisionを進める', () {
      final revision = MarkerCacheRevision();

      revision.markChanged();
      expect(revision.value, 1);
      expect(revision.isCurrent(0), isFalse);
      expect(revision.isCurrent(1), isTrue);

      revision.markChanged();
      expect(revision.value, 2);
      expect(revision.isCurrent(1), isFalse);
      expect(revision.isCurrent(2), isTrue);
    });
  });
}
