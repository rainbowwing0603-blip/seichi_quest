import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Serializes Mobile Ads SDK startup and ad requests.
///
/// The map is the startup priority. [initialize] is called only after the
/// first frame and the configured startup grace period. Ad widgets/services
/// await [ready] so they cannot accidentally initialize native ad work early.
class AdSdkService {
  AdSdkService._();

  static final AdSdkService instance = AdSdkService._();

  final Completer<bool> _readyCompleter = Completer<bool>();
  Future<void>? _initializationFuture;

  Future<bool> get ready => _readyCompleter.future;

  Future<void> initialize() {
    return _initializationFuture ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    var initialized = false;
    try {
      await MobileAds.instance.initialize();
      initialized = true;
    } finally {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete(initialized);
      }
    }
  }
}
