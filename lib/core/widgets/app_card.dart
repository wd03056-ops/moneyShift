import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// [AppBorderedField] 안쪽용 TextField — 입력 밑줄·맞춤법 밑줄 없음
class AppPlainTextField extends StatelessWidget {
  const AppPlainTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.style,
    this.hintStyle,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.textAlignVertical,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlignVertical? textAlignVertical;

  static const InputDecoration plainDecoration = InputDecoration(
    filled: false,
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textAlignVertical: textAlignVertical,
      autocorrect: false,
      enableSuggestions: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      style: (style ?? Theme.of(context).textTheme.bodyLarge)?.copyWith(
        decoration: TextDecoration.none,
      ),
      decoration: plainDecoration.copyWith(
        hintText: hintText,
        hintStyle: hintStyle,
      ),
    );
  }
}
