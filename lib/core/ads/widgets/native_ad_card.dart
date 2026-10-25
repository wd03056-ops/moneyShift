import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../security/secure_log.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../ad_bootstrap.dart';
import '../ad_config.dart';

/// 앱 카드(둥근 모서리·은은한 그림자)와 맞춘 인피드 네이티브 광고
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({
    super.key,
    this.margin = const EdgeInsets.only(top: 16, bottom: 4),
  });

  final EdgeInsetsGeometry margin;

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  var _loaded = false;
  var _attempt = 0;
  var _disposed = false;
  var _loading = false;

  /// listTile 팩토리 기준 (미디어 포함)
  static const double _adHeight = 220;
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    // 배너와 동시 요청 충돌을 줄이기 위해 살짝 지연
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load(delayMs: 400));
    });
  }

  Future<void> _load({int delayMs = 0}) async {
    if (_disposed || !mounted || _loading) return;
    if (!AdConfig.isSupported) return;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (_disposed || !mounted) return;
    }

    if (!AdBootstrap.isReady) {
      await AdBootstrap.init();
    }
    if (_disposed || !mounted || !AdBootstrap.isReady) return;

    _loading = true;
    _attempt += 1;
    final useVideoUnit = _attempt >= _maxAttempts && AdConfig.useTestAds;
    final unitId = useVideoUnit
        ? AdConfig.nativeVideoAdUnitId
        : AdConfig.nativeAdUnitId;

    _ad?.dispose();
    _ad = null;
    if (mounted) setState(() => _loaded = false);

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    final ad = NativeAd(
      adUnitId: unitId,
      factoryId: isAndroid ? AdConfig.nativeFactoryId : null,
      nativeTemplateStyle: isAndroid
          ? null
          : NativeTemplateStyle(
              templateType: TemplateType.medium,
              cornerRadius: AppDecorations.radiusLg,
              mainBackgroundColor: Colors.white,
              callToActionTextStyle: NativeTemplateTextStyle(
                textColor: Colors.white,
                backgroundColor: AppColors.buttonFill,
                style: NativeTemplateFontStyle.bold,
                size: 14,
              ),
              primaryTextStyle: NativeTemplateTextStyle(
                textColor: AppColors.textPrimary,
                style: NativeTemplateFontStyle.bold,
                size: 15,
              ),
              secondaryTextStyle: NativeTemplateTextStyle(
                textColor: AppColors.textSecondary,
                style: NativeTemplateFontStyle.normal,
                size: 13,
              ),
            ),
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        mediaAspectRatio: MediaAspectRatio.any,
        requestCustomMuteThisAd: false,
        shouldRequestMultipleImages: false,
      ),
      listener: NativeAdListener(
        onAdLoaded: (loaded) {
          _loading = false;
          if (_disposed || !mounted) {
            loaded.dispose();
            return;
          }
          SecureLog.d('[Ads] native loaded (attempt=$_attempt)');
          setState(() {
            _ad = loaded as NativeAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (failed, error) {
          _loading = false;
          SecureLog.d(
            '[Ads] native failed attempt=$_attempt '
            'code=${error.code} msg=${error.message}',
          );
          failed.dispose();
          if (_disposed || !mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          if (_attempt < _maxAttempts) {
            unawaited(_load(delayMs: 900 * _attempt));
          }
        },
      ),
    );

    _ad = ad;
    if (_disposed || !mounted) {
      _loading = false;
      ad.dispose();
      _ad = null;
      return;
    }
    try {
      await ad.load();
    } catch (e) {
      _loading = false;
      SecureLog.d('[Ads] native load threw: $e');
      ad.dispose();
      if (_ad == ad) _ad = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    // PlatformView 는 Clip 과 충돌하기 쉬워 그림자는 바깥 DecoratedBox 만 사용
    return Padding(
      padding: widget.margin,
      child: DecoratedBox(
        decoration: AppDecorations.borderedSurface(),
        child: SizedBox(
          height: _adHeight,
          width: double.infinity,
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
