import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
          // 순백만 — Material/회색 틴트·애니메이션 없음. 선택은 글자색·그림자로만 구분
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.12 : 0.07),
              blurRadius: selected ? 12 : 8,
              spreadRadius: 0,
              offset: Offset(0, selected ? 3 : 2),
            ),
          ],
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
