import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

/// 입력창 공통 값 — 한글 IME(Android) 호환 우선
///
/// Android에서 [enableSuggestions]/[autocorrect] 를 false 로 두면
/// Gboard/삼성 키보드가 영문으로 고정되어 한글 전환이 안 되는 기기가 있습니다.
abstract final class AppTextInputDefaults {
  AppTextInputDefaults._();

  static const SpellCheckConfiguration spellCheckConfiguration =
      SpellCheckConfiguration.disabled();

  /// 입력 박스 모서리
  static const double borderRadius = 12;

  /// Android는 한글 IME를 위해 true 유지. iOS는 밑줄/자동완성 완화로 false.
  static bool get autocorrect {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  static bool get enableSuggestions {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  static const SmartDashesType smartDashesType = SmartDashesType.disabled;
  static const SmartQuotesType smartQuotesType = SmartQuotesType.disabled;

  /// 연한 회색 / 포커스 Primary / 에러 (레거시·테마용)
  static OutlineInputBorder outlineBorder({
    Color color = AppColors.border,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// 테두리 없음 — [AppElevatedInputShell]과 함께 사용
  static InputDecoration decoration({
    String? labelText,
    String? hintText,
    String? helperText,
    String? suffixText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.transparent,
      isDense: false,
      contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );
  }

  /// 한글 IME 조합(composing) 중이면 true.
  /// 이때 setState / FormField.didChange 를 호출하면 입력이 끊깁니다.
  static bool isComposing(TextEditingController controller) {
    final range = controller.value.composing;
    return range.isValid && !range.isCollapsed;
  }

  /// 맞춤법 밑줄이 TextStyle decoration 으로 남는 경우 차단
  static TextStyle? styleWithoutDecoration(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      decoration: TextDecoration.none,
      decorationThickness: 0,
    );
  }
}

/// 입력 필드 입체 셸 — 테두리 없이 그림자로 입력칸 인지
class AppElevatedInputShell extends StatefulWidget {
  const AppElevatedInputShell({
    super.key,
    required this.child,
    this.hasError = false,
    this.enabled = true,
  });

  final Widget child;
  final bool hasError;

  /// false면 Outline만 유지하고 그림자 제거
  final bool enabled;

  @override
  State<AppElevatedInputShell> createState() => _AppElevatedInputShellState();
}

class _AppElevatedInputShellState extends State<AppElevatedInputShell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (_focused == focused) return;
        setState(() => _focused = focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: AppDecorations.elevatedInput(
          focused: widget.enabled && _focused,
          error: widget.hasError,
          enabled: widget.enabled,
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.child,
      ),
    );
  }
}
