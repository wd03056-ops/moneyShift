import 'package:flutter/material.dart';

/// 앱 전역 컬러 — 검정 포인트 + 순백 배경
abstract final class AppColors {
  /// 메인 포인트 (버튼·선택·강조)
  static const Color primary = Color(0xFF191F28);

  /// 보조 액센트 (호버·진한 강조)
  static const Color secondary = Color(0xFF191F28);

  /// 연한 틴트 (칩·인디케이터·카드 배경)
  static const Color primarySoft = Color(0xFFF5F6F8);

  /// 아웃라인·보조
  static const Color accentMuted = Color(0xFFC9CDD2);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color holiday = Color(0xFFDC2626);

  /// 화면·카드·입력 — 순백만
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF7F8FA);

  /// 본문 텍스트는 가독성 위해 딥 네이비 유지
  static const Color textPrimary = Color(0xFF191F28);
  static const Color textSection = Color(0xFF333D4B);
  static const Color textSecondary = Color(0xFF8B95A1);
  static const Color textCaption = Color(0xFF4E5968);

  static const Color border = Color(0xFFE5E8EB);
  static const Color borderSubtle = Color(0xFFE5E8EB);

  static const Color shadow = Color(0x0A000000);
  static const Color shadowStrong = Color(0x0F000000);

  static const Color badgeOwnerBg = Color(0xFF191F28);
  static const Color badgeOwnerFg = Color(0xFFFFFFFF);
  static const Color badgeStaffBg = Color(0xFFF2F4F6);
  static const Color badgeStaffFg = Color(0xFF191F28);

  /// 채움 버튼 공통
  static const Color buttonFill = Color(0xFF191F28);
  static const Color buttonOnFill = Color(0xFFFFFFFF);
}
