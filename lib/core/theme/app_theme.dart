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

/// 전역 테마 — 순백 배경 + Primary Blue CTA
abstract final class AppTheme {
  static const String _font = 'Pretendard';

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

  /// 주요 액션 — 블루 채움 + 흰 굵은 글씨 + 둥근 모서리
  static ButtonStyle get _filledCtaButton {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.accentMuted;
        }
        return AppColors.buttonFill;
      }),
      foregroundColor: const WidgetStatePropertyAll(AppColors.buttonOnFill),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: WidgetStatePropertyAll(AppColors.shadowStrong),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.buttonOnFill,
        ),
      ),
    );
  }

  /// 보조 — 흰 배경 + 블루 테두리
  static ButtonStyle get _outlineButton {
    return ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: WidgetStatePropertyAll(AppColors.shadowStrong),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(
        BorderSide(color: AppColors.borderSubtle, width: 1.2),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
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

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.secondary,
      secondary: AppColors.secondary,
      onSecondary: white,
      secondaryContainer: AppColors.primarySoft,
      onSecondaryContainer: AppColors.secondary,
      tertiary: AppColors.success,
      onTertiary: white,
      error: AppColors.holiday,
      onError: white,
      surface: white,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderSubtle,
      shadow: AppColors.shadow,
      scrim: const Color(0x99000000),
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: white,
      inversePrimary: AppColors.accentMuted,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _font,
      colorScheme: colorScheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: white,
      canvasColor: white,
      cardColor: white,
      // Material 회색 물결(리플) 전역 제거
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
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
      elevatedButtonTheme: ElevatedButtonThemeData(style: _filledCtaButton),
      filledButtonTheme: FilledButtonThemeData(style: _filledCtaButton),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlineButton),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          overlayColor: Colors.transparent,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        enableFeedback: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.buttonFill,
        foregroundColor: AppColors.buttonOnFill,
        elevation: 2,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        labelStyle: TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        hintStyle: TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.secondary,
        contentTextStyle: theme.bodyLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.primarySoft,
        headerForegroundColor: AppColors.secondary,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return white;
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textSecondary;
          }
          return AppColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return white;
          return AppColors.primary;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        todayBorder: const BorderSide(color: AppColors.primary, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.surfaceMuted,
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
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          );
        }),
      ),
      // 설정 화면 OutlinedToggle 과 동일 — ON 초록 / OFF 회색
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF34C759);
          }
          return const Color(0xFFE5E5EA);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
