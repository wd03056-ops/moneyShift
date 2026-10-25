import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../security/secure_log.dart';
import 'ad_config.dart';

/// Mobile Ads SDK 초기화 (앱 기동 시 1회)
abstract final class AdBootstrap {
  AdBootstrap._();

  static var _initialized = false;

  static bool get isReady => _initialized;

  static Future<void> init() async {
    if (_initialized) return;
    AdConfig.logStatus();
    if (!AdConfig.isSupported) {
      SecureLog.d('[Ads] skip init (unsupported platform)');
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      SecureLog.d('[Ads] MobileAds initialized');
    } catch (e, st) {
      SecureLog.d('[Ads] init failed (app continues): $e');
      if (kDebugMode) SecureLog.d('$st');
    }
  }
}
