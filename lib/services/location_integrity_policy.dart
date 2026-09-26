import 'package:flutter/foundation.dart';

/// A platform-neutral decision for whether a location sample may be used to
/// collect a stamp.
///
/// This policy deliberately treats mock-location evidence separately from GPS
/// quality problems. Debug builds keep mock locations available for emulator
/// testing, while release/profile builds reject them.
abstract final class LocationIntegrityPolicy {
  static bool shouldRejectMockLocation({
    required bool isMocked,
    bool isDebugBuild = kDebugMode,
  }) {
    return isMocked && !isDebugBuild;
  }
}
