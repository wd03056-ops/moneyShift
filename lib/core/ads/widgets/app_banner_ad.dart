import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../security/secure_log.dart';
import '../../theme/app_colors.dart';
import '../ad_bootstrap.dart';
import '../ad_config.dart';

/// 하단 내비게이션 바로 위에 고정되는 배너 광고
class AppBannerAd extends StatefulWidget {
  const AppBannerAd({super.key});

  @override
  State<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends State<AppBannerAd> {
  BannerAd? _banner;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!AdConfig.isSupported) return;
    if (!AdBootstrap.isReady) {
      await AdBootstrap.init();
    }
    if (!mounted || !AdBootstrap.isReady) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted) return;
    final adSize = size ?? AdSize.banner;

    final banner = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          SecureLog.d('[Ads] banner failed: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _banner = null;
              _loaded = false;
            });
          }
        },
      ),
    );

    setState(() => _banner = banner);
    await banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded || banner == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          width: banner.size.width.toDouble(),
          height: banner.size.height.toDouble(),
          child: AdWidget(ad: banner),
        ),
      ),
    );
  }
}

/// [NavigationBar] 위에 배너를 올린 하단 바 묶음
class BottomNavWithBanner extends StatelessWidget {
  const BottomNavWithBanner({super.key, required this.navigationBar});

  final Widget navigationBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBannerAd(),
        navigationBar,
      ],
    );
  }
}
