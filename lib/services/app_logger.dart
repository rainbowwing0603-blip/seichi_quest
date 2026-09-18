import 'package:flutter/foundation.dart';

/// Development-only application logging.
///
/// Release builds intentionally suppress these diagnostics because they can
/// contain identifiers, location details, and runtime error context.
void appDebugPrint(String? message, {int? wrapWidth}) {
  if (!kReleaseMode) {
    debugPrint(message, wrapWidth: wrapWidth);
  }
}
