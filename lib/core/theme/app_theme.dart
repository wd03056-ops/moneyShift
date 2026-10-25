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

  /// 주요 액션 — 검정 채움 + 흰 글씨 + 알약형 (StickyActionButton과 동일)
  static ButtonStyle get _filledCtaButton {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey.shade300;
        }
        return Colors.black;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey.shade600;
        }
        return Colors.white;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return 0;
        return 2;
      }),
      shadowColor: const WidgetStatePropertyAll(Color(0x0F000000)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(64, 50)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 50)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 보조 — 흰 배경 + 검정 글씨 + 그림자 입체감 (테두리 없음)
  static ButtonStyle get _outlineButton {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey.shade300;
        }
        return Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey.shade600;
        }
        return Colors.black;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return 0;
        return 2;
      }),
      shadowColor: const WidgetStatePropertyAll(Color(0x0F000000)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(BorderSide.none),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(64, 50)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 50)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black,
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
          foregroundColor: Colors.black,
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
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        isDense: false,
        contentPadding: EdgeInsets.fromLTRB(16, 18, 16, 18),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        labelStyle: TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
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
        backgroundColor: const Color(0xFF1A1A1A),
        contentTextStyle: theme.bodyLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: const StadiumBorder(),
        // bottomNavigationBar(배너·탭) 바로 위 — showAppSnackBar와 동일
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
