import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_decorations.dart';

/// 화면 전환 애니메이션 없음 (슬라이드 제거)
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// 전역 테마 — 순백 배경, 버튼 채움(차콜/파랑) 없음 → 테두리만
abstract final class AppTheme {
  static const String _font = 'Pretendard';
  static const Color _charcoal = Color(0xFF212529);
  static const Color _border = Color(0xFFE5E8EB);

  static const PageTransitionsTheme noSlideTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _NoTransitionsBuilder(),
      TargetPlatform.iOS: _NoTransitionsBuilder(),
      TargetPlatform.macOS: _NoTransitionsBuilder(),
      TargetPlatform.windows: _NoTransitionsBuilder(),
      TargetPlatform.linux: _NoTransitionsBuilder(),
      TargetPlatform.fuchsia: _NoTransitionsBuilder(),
    },
  );

  /// 흰 배경 + 테두리 + 부드러운 elevation 그림자
  static ButtonStyle get _flatOutlineButton {
    return ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      foregroundColor: const WidgetStatePropertyAll(_charcoal),
      overlayColor: WidgetStatePropertyAll(
        _charcoal.withValues(alpha: 0.06),
      ),
      elevation: const WidgetStatePropertyAll(2),
      shadowColor: WidgetStatePropertyAll(AppColors.shadowStrong),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(
        BorderSide(color: _border, width: 1),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _charcoal,
        ),
      ),
    );
  }

  static TextTheme get textTheme {
    return const TextTheme(
      titleLarge: TextStyle(
        fontFamily: _font,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: _font,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AppColors.textSection,
      ),
      titleSmall: TextStyle(
        fontFamily: _font,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: _font,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: _font,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontFamily: _font,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textCaption,
      ),
      labelLarge: TextStyle(
        fontFamily: _font,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: _font,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: AppColors.textCaption,
      ),
      labelSmall: TextStyle(
        fontFamily: _font,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      displayLarge: TextStyle(
        fontFamily: _font,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: _font,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: _font,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineLarge: TextStyle(
        fontFamily: _font,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: _font,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: _font,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  static ThemeData get light {
    const white = Colors.white;
    final theme = textTheme;

    // ColorScheme.primary 자체를 차콜로 — M3 기본 파랑 상속 차단
    final colorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: _charcoal,
      onPrimary: white,
      primaryContainer: Color(0xFFF2F4F6),
      onPrimaryContainer: _charcoal,
      secondary: _charcoal,
      onSecondary: white,
      secondaryContainer: Color(0xFFF2F4F6),
      onSecondaryContainer: Color(0xFF343A40),
      tertiary: Color(0xFF10B981),
      onTertiary: white,
      error: Color(0xFFDC2626),
      onError: white,
      surface: white,
      onSurface: Color(0xFF191F28),
      onSurfaceVariant: Color(0xFF8B95A1),
      outline: Color(0xFFE5E8EB),
      outlineVariant: Color(0xFFE5E8EB),
      shadow: Color(0x0A000000),
      scrim: Color(0x99000000),
      inverseSurface: Color(0xFF191F28),
      onInverseSurface: white,
      inversePrimary: Color(0xFFADB5BD),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _font,
      colorScheme: colorScheme,
      primaryColor: _charcoal,
      scaffoldBackgroundColor: white,
      canvasColor: white,
      cardColor: white,
      pageTransitionsTheme: noSlideTransitions,
      textTheme: theme,
      primaryTextTheme: theme,
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        // 뒤로가기 ↔ 제목 사이 기본 여백(16) 제거
        titleSpacing: 0,
        leadingWidth: 48,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: theme.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: AppDecorations.cardShape,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      // Elevated / Filled — 차콜 채움 제거, 흰 배경+테두리만
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _flatOutlineButton,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _flatOutlineButton,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _flatOutlineButton,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF343A40),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: _charcoal,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE5E8EB), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE5E8EB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          borderSide: const BorderSide(color: _charcoal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        labelStyle: theme.bodyMedium,
        hintStyle: theme.bodyMedium,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E8EB),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _charcoal,
        contentTextStyle: theme.bodyLarge?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
      ),
      // Material 기본 날짜 선택기 — 선택일 숫자 보이도록 (흰 글씨)
      datePickerTheme: DatePickerThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: white,
        headerForegroundColor: _charcoal,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return white;
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textSecondary;
          }
          return _charcoal;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _charcoal;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return white;
          return _charcoal;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _charcoal;
          return Colors.transparent;
        }),
        todayBorder: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: _charcoal.withValues(alpha: 0.08),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _charcoal : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? _charcoal : AppColors.textSecondary,
          );
        }),
      ),
    );
  }
}
