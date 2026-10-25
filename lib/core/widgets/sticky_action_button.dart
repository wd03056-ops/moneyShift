import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

enum StickyActionVariant {
  /// 기본 — 흰 배경 + 그림자 (테두리 없음)
  primary,

  /// 채움 검정 — 시인성 높은 CTA
  filled,

  /// 채움 검정 (출근 등 — 동일 UI)
  success,

  /// 채움 검정 (대기·요청 — 동일 UI)
  warning,

  /// 흰 배경 + 그림자 (outline)
  navy,
}

/// 핵심 액션용 스티키 버튼 — 알약형
///
/// 가로: 부모 폭을 채움 (바가 좌우 inset으로 ~85–90% 비율 맞춤)
/// 세로: 가로:세로 ≈ 6.5:1 기준 높이 50
class StickyActionButton extends StatelessWidget {
  const StickyActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = StickyActionVariant.primary,
    this.enabled = true,
    this.isLoading = false,
    this.isCompleted = false,
    this.completedLabel = '완료됨',
    this.showBorder = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final StickyActionVariant variant;
  final bool enabled;
  final bool isLoading;

  /// 작업 완료 후 — 회색 비활성 + [completedLabel]
  final bool isCompleted;
  final String completedLabel;

  /// true면 outline 변형에만 테두리. 기본은 그림자만 (입체감).
  final bool showBorder;

  static final Color _doneBg = Colors.grey.shade300;
  static final Color _doneFg = Colors.grey.shade600;

  /// 참고 모달 CTA 비율 (가로:세로 ≈ 6.5~7:1)
  static const double _height = 50;

  bool get _isFilled =>
      variant == StickyActionVariant.filled ||
      variant == StickyActionVariant.success ||
      variant == StickyActionVariant.warning;

  Color get _fg {
    switch (variant) {
      case StickyActionVariant.filled:
      case StickyActionVariant.success:
      case StickyActionVariant.warning:
        return Colors.white;
      case StickyActionVariant.primary:
      case StickyActionVariant.navy:
        return Colors.black;
    }
  }

  Color get _bg {
    switch (variant) {
      case StickyActionVariant.filled:
      case StickyActionVariant.success:
      case StickyActionVariant.warning:
        return Colors.black;
      case StickyActionVariant.primary:
      case StickyActionVariant.navy:
        return Colors.white;
    }
  }

  Color get _borderColor {
    switch (variant) {
      case StickyActionVariant.filled:
      case StickyActionVariant.success:
      case StickyActionVariant.warning:
        return Colors.black;
      case StickyActionVariant.primary:
      case StickyActionVariant.navy:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = isCompleted;
    final active = !done && enabled && onPressed != null && !isLoading;
    final displayLabel = done ? completedLabel : label;
    final fg = done ? _doneFg : (active ? _fg : _doneFg);
    final bg = done
        ? _doneBg
        : (active ? _bg : (_isFilled ? _doneBg : Colors.white));
    final border =
        done ? _doneBg : (active ? _borderColor : AppColors.border);
    const radius = _height / 2;

    final child = isLoading && !done
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: fg,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null && !done) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.2,
                    color: fg,
                  ),
                ),
              ),
            ],
          );

    final useOutlineChrome = !_isFilled;
    // 활성만 은은한 그림자 — 로딩·비활성·완료는 flat
    final showElevation = active;
    final decoration = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: (useOutlineChrome && !done && showBorder)
          ? Border.all(color: border, width: 1.2)
          : null,
      boxShadow: showElevation
          ? AppDecorations.softShadow
          : AppDecorations.noShadow,
    );

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: active ? onPressed : null,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 하단에 붙는 스티키 액션 바
///
/// 좌우 inset으로 버튼이 화면 폭의 약 85–90%가 되도록 맞춤 (참고 모달 CTA 비율).
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.children,
    this.safeAreaBottom = true,
    this.showTopBorder = false,
    this.elevated = false,
  });

  final List<Widget> children;
  final bool safeAreaBottom;
  final bool showTopBorder;

  /// true면 위쪽 그림자로 본문과 분리 (구분선은 [showTopBorder])
  final bool elevated;

  /// 화면 대비 버튼 영역 ≈ 88% → 한쪽 inset ≈ 6%
  static const double _sideInset = 28;

  @override
  Widget build(BuildContext context) {
    final buttons = children.length == 1
        ? children.first
        : Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: children[i]),
              ],
            ],
          );

    final content = SafeArea(
      top: false,
      bottom: safeAreaBottom,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_sideInset, 12, _sideInset, 16),
        child: buttons,
      ),
    );

    if (!showTopBorder && !elevated) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: showTopBorder
            ? const Border(
                top: BorderSide(color: AppColors.border, width: 1),
              )
            : null,
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
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
