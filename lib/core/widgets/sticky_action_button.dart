import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

enum StickyActionVariant {
  /// 기본 — 흰 배경 + 블루 테두리
  primary,

  /// 채움 Primary Blue — 시인성 높은 CTA
  filled,

  /// Emerald — 출근 등
  success,

  /// Amber — 대기·요청 관련
  warning,

  /// Primary Blue 텍스트 강조 (outline)
  navy,
}

/// 핵심 액션용 스티키 버튼 — 블루 CTA / 라이트 톤
class StickyActionButton extends StatelessWidget {
  const StickyActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = StickyActionVariant.primary,
    this.enabled = true,
    this.isLoading = false,
    this.showBorder = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final StickyActionVariant variant;
  final bool enabled;
  final bool isLoading;

  /// false면 테두리 없이 그림자만 (카드형 입체감). [filled]에서는 무시.
  final bool showBorder;

  bool get _isFilled =>
      variant == StickyActionVariant.filled ||
      variant == StickyActionVariant.success ||
      variant == StickyActionVariant.warning;

  Color get _fg {
    switch (variant) {
      case StickyActionVariant.filled:
      case StickyActionVariant.success:
      case StickyActionVariant.warning:
        return AppColors.buttonOnFill;
      case StickyActionVariant.primary:
      case StickyActionVariant.navy:
        return AppColors.primary;
    }
  }

  Color get _bg {
    switch (variant) {
      case StickyActionVariant.filled:
        return AppColors.buttonFill;
      case StickyActionVariant.success:
        return AppColors.success;
      case StickyActionVariant.warning:
        return AppColors.warning;
      case StickyActionVariant.primary:
      case StickyActionVariant.navy:
        return Colors.white;
    }
  }

  Color get _borderColor {
    switch (variant) {
      case StickyActionVariant.filled:
        return AppColors.buttonFill;
      case StickyActionVariant.primary:
      case StickyActionVariant.navy:
        return AppColors.borderSubtle;
      case StickyActionVariant.success:
        return AppColors.success;
      case StickyActionVariant.warning:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    final fg = active
        ? _fg
        : (_isFilled
            ? AppColors.buttonOnFill.withValues(alpha: 0.85)
            : AppColors.textSecondary);
    final bg = active
        ? _bg
        : (_isFilled ? AppColors.accentMuted : Colors.white);
    final border = active ? _borderColor : AppColors.border;
    final radius = AppDecorations.radiusMd; // 12

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: fg,
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    height: 1.2,
                    color: fg,
                  ),
                ),
              ],
            ),
          );

    final decoration = _isFilled
        ? BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: AppDecorations.softShadow,
          )
        : AppDecorations.borderedSurface(radius: radius).copyWith(
            color: bg,
            border: showBorder
                ? Border.all(color: border, width: 1.2)
                : null,
          );

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: GestureDetector(
            onTap: active && !isLoading ? onPressed : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 하단에 붙는 스티키 액션 바 (1~2개 버튼)
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.children,
    this.safeAreaBottom = true,
    this.showTopBorder = true,
    this.elevated = false,
  });

  final List<Widget> children;
  final bool safeAreaBottom;
  final bool showTopBorder;

  /// true면 상단 테두리 + 위쪽 그림자로 본문과 분리
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: false,
      bottom: safeAreaBottom,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: children.length == 1
            ? children.first
            : Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
      ),
    );

    if (!showTopBorder && !elevated) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: showTopBorder || elevated
            ? const Border(
                top: BorderSide(color: AppColors.border, width: 1),
              )
            : null,
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, -4),
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: content,
    );
  }
}
