import 'package:flutter/material.dart';

/// TableCalendar 즉시 반응용 — 페이지·포맷 전환을 거의 즉시 처리
abstract final class SnappyCalendar {
  SnappyCalendar._();

  /// 월 스와이프 애니메이션 끄기 (선택 하이라이트 지연 방지)
  static const bool pageAnimationEnabled = false;

  /// chevron → PageController.animateToPage 는 duration > 0 필수
  /// (Duration.zero 이면 assertion 으로 전·후 월 이동이 깨짐)
  static const Duration pageAnimationDuration = Duration(milliseconds: 1);
  static const Duration formatAnimationDuration = Duration(milliseconds: 1);

  /// 바텀시트·다이얼로그 진입 페이드/슬라이드 단축
  static const Duration sheetDuration = Duration(milliseconds: 120);

  static AnimationStyle get sheetAnimationStyle => AnimationStyle(
        duration: sheetDuration,
        reverseDuration: sheetDuration,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
}
