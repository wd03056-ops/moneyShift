import 'package:flutter/material.dart';

/// 앱 전역 컬러 — 차콜 액센트 + 순백 배경 (파란색 사용 금지)
abstract final class AppColors {
  /// 딥 네이비 텍스트/브랜드
  static const Color primary = Color(0xFF191F28);

  /// 버튼·탭 액센트 — 다크 차콜 (구 Trust Blue 대체)
  static const Color secondary = Color(0xFF212529);

  /// 아웃라인·보조
  static const Color accentMuted = Color(0xFF343A40);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color holiday = Color(0xFFDC2626);

  /// 화면·카드·입력 — 순백만
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFFFFFF);

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
  static const Color badgeStaffBg = Color(0xFF343A40);
  static const Color badgeStaffFg = Color(0xFFFFFFFF);

  /// 채움 버튼 공통
  static const Color buttonFill = Color(0xFF212529);
  static const Color buttonOnFill = Color(0xFFFFFFFF);
}
