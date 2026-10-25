import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

/// 선택형 칩 — 테두리·회색 바탕 없이 순백 + 그림자로만 구분
class AppSelectChip extends StatelessWidget {
  const AppSelectChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  /// true면 가로를 채우고 라벨을 가운데 정렬 (균등 분할 Row용)
  final bool expand;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: expand ? double.infinity : null,
        padding: padding,
        alignment: expand ? Alignment.center : null,
        decoration: BoxDecoration(
          // 순백만 — 선택은 글자색·은은한 그림자로만 구분. 비활성은 flat
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: !enabled
              ? AppDecorations.noShadow
              : selected
                  ? AppDecorations.softShadowEmphasis
                  : AppDecorations.softShadow,
        ),
        child: Text(
          label,
          textAlign: expand ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                color: !enabled
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
