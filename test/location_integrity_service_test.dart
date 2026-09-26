import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/location_integrity_service.dart';

void main() {
  group('LocationSecurityState', () {
    test('restores an active server cooldown from cooldown_seconds', () {
      final state = LocationSecurityState.fromRow({
        'violation_count': 2,
        'cooldown_until': '2026-09-25T15:08:10Z',
        'cooldown_seconds': 900,
      });

      expect(state.violationCount, 2);
      expect(state.cooldownUntil, DateTime.parse('2026-09-25T15:08:10Z'));
      expect(state.isCollectionCooldownActive, isTrue);
      expect(state.remainingCooldown, greaterThan(Duration.zero));
      expect(state.remainingCooldown, lessThanOrEqualTo(const Duration(minutes: 15)));
    });

    test('treats an expired server cooldown as inactive', () {
      final state = LocationSecurityState.fromRow({
        'violation_count': 2,
        'cooldown_until': '2026-09-25T15:08:10Z',
        'cooldown_seconds': 0,
      });

      expect(state.isCollectionCooldownActive, isFalse);
      expect(state.remainingCooldown, Duration.zero);
    });

    test('uses safe defaults when optional RPC values are absent', () {
      final state = LocationSecurityState.fromRow(<String, dynamic>{});

      expect(state.violationCount, 0);
      expect(state.cooldownUntil, isNull);
      expect(state.cooldownSeconds, 0);
      expect(state.isCollectionCooldownActive, isFalse);
    });
  });
}
