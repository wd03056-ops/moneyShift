import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// 입력창 공통 값 — 한글 IME(Android) 호환 우선
///
/// Android에서 [enableSuggestions]/[autocorrect] 를 false 로 두면
/// Gboard/삼성 키보드가 영문으로 고정되어 한글 전환이 안 되는 기기가 있습니다.
abstract final class AppTextInputDefaults {
  AppTextInputDefaults._();

  static const SpellCheckConfiguration spellCheckConfiguration =
      SpellCheckConfiguration.disabled();

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
