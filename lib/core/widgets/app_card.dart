import 'package:flutter/material.dart';

import '../theme/app_decorations.dart';

/// 테두리 + 그림자의 입체 카드
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.radius = AppDecorations.radiusLg,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: AppDecorations.borderedSurface(radius: radius),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// 섹션 사이 구분
class AppSectionDivider extends StatelessWidget {
  const AppSectionDivider({super.key, this.height = 8});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AppDecorations.sectionGap(height: height);
  }
}

/// 테두리+그림자로 감싼 입력 필드 래퍼 (고정 높이로 비율 유지)
class AppBorderedField extends StatelessWidget {
  const AppBorderedField({
    super.key,
    required this.child,
    this.radius = AppDecorations.radiusMd,
    this.height = 52,
  });

  final Widget child;
  final double radius;

  /// null이면 자식 고유 높이 사용
  final double? height;

  @override
  Widget build(BuildContext context) {
    final boxed = DecoratedBox(
      decoration: AppDecorations.borderedSurface(radius: radius),
      child: child,
    );
    if (height == null) return boxed;
    return SizedBox(height: height, child: boxed);
  }
}
