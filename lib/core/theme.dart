import 'package:flutter/material.dart';

class HuitTheme {
  static const Color seed = Color(0xFF0E6B5C);
  static const Color accent = Color(0xFFE08A1E);
  static const Color canvas = Color(0xFFF7F3EC);
  static const Color paper = Color(0xFFFFFCF7);
  static const Color ink = Color(0xFF1D2926);
  static const Color muted = Color(0xFF61716C);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: seed,
      secondary: accent,
      surface: paper,
      brightness: Brightness.light,
    );

    final textTheme = Typography.blackMountainView.copyWith(
      displayLarge: Typography.blackMountainView.displayLarge?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        color: ink,
      ),
      displayMedium: Typography.blackMountainView.displayMedium?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: ink,
      ),
      headlineMedium: Typography.blackMountainView.headlineMedium?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: Typography.blackMountainView.titleLarge?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: Typography.blackMountainView.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: Typography.blackMountainView.bodyLarge?.copyWith(
        color: ink,
        height: 1.42,
      ),
      bodyMedium: Typography.blackMountainView.bodyMedium?.copyWith(
        color: muted,
        height: 1.38,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ink,
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      cardTheme: CardThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.82),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: muted.withValues(alpha: 0.78),
        ),
        labelStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC44536)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC44536), width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        labelStyle: textTheme.bodyMedium ?? const TextStyle(),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
