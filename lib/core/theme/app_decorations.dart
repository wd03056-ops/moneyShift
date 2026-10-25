import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 테두리 + 부드러운 그림자로 입체감
abstract final class AppDecorations {
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  /// 과하지 않은 기본 입체감 — 버튼·카드·클릭 면 공통
  /// `Colors.black.withOpacity(0.06), blur 10, offset (0, 4)`
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 10,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  /// 포커스·선택 시 약간만 강조 (여전히 은은함)
  static List<BoxShadow> get softShadowEmphasis => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.10),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  /// 에러 상태 입력
  static List<BoxShadow> get softShadowError => [
        BoxShadow(
          color: AppColors.holiday.withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  /// 비활성·완료 — 평평하게
  static const List<BoxShadow> noShadow = [];

  static Border get cardBorder => Border.all(
        color: AppColors.border,
        width: 1,
      );

  /// 흰 면 + 테두리 + 그림자
  static BoxDecoration borderedSurface({
    Color color = Colors.white,
    double radius = radiusLg,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: cardBorder,
      boxShadow: elevated ? softShadow : noShadow,
    );
  }

  /// 입력칸용 — Outline Border + 은은한 그림자
  /// [enabled] false면 그림자 제거(flat)
  static BoxDecoration elevatedInput({
    Color color = Colors.white,
    double radius = radiusMd,
    bool focused = false,
    bool error = false,
    bool enabled = true,
  }) {
    final List<BoxShadow> shadows;
    if (!enabled) {
      shadows = noShadow;
    } else if (error) {
      shadows = softShadowError;
    } else if (focused) {
      shadows = softShadowEmphasis;
    } else {
      shadows = softShadow;
    }
    final BorderSide side;
    if (error) {
      side = BorderSide(color: AppColors.holiday.withValues(alpha: 0.55));
    } else if (!enabled) {
      side = BorderSide(color: AppColors.border.withValues(alpha: 0.7));
    } else if (focused) {
      side = BorderSide(color: AppColors.primary.withValues(alpha: 0.45));
    } else {
      side = const BorderSide(color: AppColors.border);
    }
    return BoxDecoration(
      color: enabled ? color : const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(radius),
      border: Border.fromBorderSide(side),
      boxShadow: shadows,
    );
  }

  /// AppCard 호환
  static BoxDecoration card({
    Color color = Colors.white,
    double radius = radiusLg,
  }) =>
      borderedSurface(color: color, radius: radius);

  static BorderRadius get cardBorderRadius =>
      BorderRadius.circular(radiusLg);

  static ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: cardBorderRadius,
        side: const BorderSide(color: AppColors.border, width: 1),
      );

  static BoxDecoration get topHairline => const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      );

  static Widget sectionGap({double height = 8}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const Align(
        alignment: Alignment.center,
        child: Divider(height: 1, thickness: 1),
      ),
    );
  }
}
