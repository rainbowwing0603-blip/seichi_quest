import 'package:supabase_flutter/supabase_flutter.dart';

class LocationSecurityState {
  LocationSecurityState({
    required this.violationCount,
    required this.cooldownUntil,
    required this.cooldownSeconds,
  }) : _cooldownClock = Stopwatch()..start();

  LocationSecurityState.clear()
      : violationCount = 0,
        cooldownUntil = null,
        cooldownSeconds = 0,
        _cooldownClock = Stopwatch()..start();

  final int violationCount;
  final DateTime? cooldownUntil;

  /// Remaining seconds reported by the server when this state was fetched.
  ///
  /// A monotonic Stopwatch is used locally so changing the device wall clock
  /// cannot make an active server cooldown appear expired.
  final int cooldownSeconds;
  final Stopwatch _cooldownClock;

  bool get isCollectionCooldownActive => remainingCooldown > Duration.zero;

  Duration get remainingCooldown {
    final initial = Duration(seconds: cooldownSeconds);
    final remaining = initial - _cooldownClock.elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  factory LocationSecurityState.fromRow(Map<String, dynamic> row) {
    final rawUntil = row['cooldown_until']?.toString();

    return LocationSecurityState(
      violationCount: (row['violation_count'] as num?)?.toInt() ?? 0,
      cooldownUntil: rawUntil == null ? null : DateTime.tryParse(rawUntil),
      cooldownSeconds: (row['cooldown_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Server-backed location security state.
///
/// The server is authoritative for cooldown timing so changing the device clock
/// or restarting the app does not clear a penalty.
class LocationIntegrityService {
  LocationIntegrityService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<LocationSecurityState> loadState() async {
    final result = await _client.rpc('get_my_location_security_state');
    return _stateFromResult(result);
  }

  Future<LocationSecurityState> reportViolation(String violationType) async {
    final result = await _client.rpc(
      'report_location_integrity_violation',
      params: {'p_violation_type': violationType},
    );
    return _stateFromResult(result);
  }

  Future<LocationSecurityState> reportMockLocation() {
    return reportViolation('mock_location');
  }

  Future<LocationSecurityState> reportImplausibleMovement() {
    return reportViolation('implausible_movement');
  }

  LocationSecurityState _stateFromResult(dynamic result) {
    if (result is! List || result.isEmpty || result.first is! Map) {
      return LocationSecurityState.clear();
    }

    return LocationSecurityState.fromRow(
      Map<String, dynamic>.from(result.first as Map),
    );
  }
}
