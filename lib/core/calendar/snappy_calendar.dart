import 'package:flutter/material.dart';

/// TableCalendar 즉시 반응용 — 페이지·포맷 전환 애니메이션 제거
abstract final class SnappyCalendar {
  SnappyCalendar._();

  /// 월 스와이프/포커스 이동 애니메이션 끄기 (선택 하이라이트 지연 방지)
  static const bool pageAnimationEnabled = false;

  static const Duration pageAnimationDuration = Duration.zero;
  static const Duration formatAnimationDuration = Duration.zero;

  /// 바텀시트·다이얼로그 진입 페이드/슬라이드 단축
  static const Duration sheetDuration = Duration(milliseconds: 120);

  static AnimationStyle get sheetAnimationStyle => AnimationStyle(
        duration: sheetDuration,
        reverseDuration: sheetDuration,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
}
