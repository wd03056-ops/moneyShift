import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/navigation/app_navigation.dart';
import 'legal_document_screen.dart';

/// 개인정보처리방침·이용약관 — assets 본문 인앱 표시
abstract final class LegalLinks {
  LegalLinks._();

  static const String _termsAsset = 'assets/terms.txt';
  static const String _privacyAsset = 'assets/privacy.txt';
  static const String _privacyAssetLegacy = 'assets/priavcy.txt';

  static Future<void> openPrivacyPolicy([BuildContext? context]) => _openAsset(
        title: '개인정보처리방침',
        assetPaths: const [_privacyAsset, _privacyAssetLegacy],
        routeName: 'legal_privacy',
        context: context,
      );

  static Future<void> openTermsOfService([BuildContext? context]) => _openAsset(
        title: '이용약관',
        assetPaths: const [_termsAsset],
        routeName: 'legal_terms',
        context: context,
      );

  static Future<void> _openAsset({
    required String title,
    required List<String> assetPaths,
    required String routeName,
    BuildContext? context,
  }) async {
    try {
      String? body;
      for (final path in assetPaths) {
        try {
          body = await rootBundle.loadString(path);
          break;
        } catch (_) {
          // 다음 후보 경로
        }
      }
      if (body == null || body.trim().isEmpty) {
        throw StateError('legal asset missing');
      }
      await AppNavigation.pushSingleTop(
        name: routeName,
        builder: (_) => LegalDocumentScreen(title: title, body: body!),
      );
    } catch (_) {
      if (context == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문서를 불러오지 못했습니다. 앱을 다시 실행해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
