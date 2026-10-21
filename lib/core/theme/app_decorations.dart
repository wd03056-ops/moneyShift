import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 테두리 + 부드러운 그림자로 입체감
abstract final class AppDecorations {
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  /// 은은한 이중 그림자 (흰 배경 위)
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.shadowStrong,
          blurRadius: 14,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 4,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
      ];

  static Border get cardBorder => Border.all(
        color: AppColors.border,
        width: 1,
      );

  /// 흰 면 + 테두리 + 그림자
  static BoxDecoration borderedSurface({
    Color color = Colors.white,
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: cardBorder,
      boxShadow: softShadow,
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
