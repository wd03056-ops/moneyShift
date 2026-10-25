import 'package:flutter/material.dart';

import '../theme/app_decorations.dart';

/// 하단 floating 알약형 SnackBar — `#1A1A1A` · 흰 문구 · 은은한 그림자
///
/// - 기본: bottomNavigationBar(배너·탭) 바로 위
/// - [aboveStickyActions]: StickyActionBar(확인/저장 등) 바로 위
void showAppSnackBar(
  BuildContext context, {
  required String message,
  /// true면 하단 스티키 CTA 바 위에 표시
  bool aboveStickyActions = false,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  // hide는 퇴장 애니메이션을 기다려 늦게 뜸 → 즉시 제거
  messenger.removeCurrentSnackBar();

  final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
  // StickyActionBar: top12 + 버튼50 + bottom16 + safe + 여유
  final bottom = aboveStickyActions
      ? 12 + 50 + 16 + safeBottom + 10
      : 10.0;

  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      content: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppDecorations.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
    snackBarAnimationStyle: AnimationStyle.noAnimation,
  );
}
