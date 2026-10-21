import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/legal/legal_texts.dart';
import '../theme/app_colors.dart';

/// Play 정책: 위치 권한 요청 전 눈에 띄는 고지
class LocationDisclosure {
  LocationDisclosure._();

  static const _prefsKey = 'location_disclosure_accepted_v1';

  /// 고지 확인 후 true. 거부 시 false.
  static Future<bool> ensureAccepted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) == true) return true;
    if (!context.mounted) return false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(LegalTexts.locationDisclosureTitle),
        content: SingleChildScrollView(
          child: Text(
            LegalTexts.locationDisclosureBody,
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: AppColors.textCaption,
                ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('거부'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('계속'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await prefs.setBool(_prefsKey, true);
      return true;
    }
    return false;
  }
}
