import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const evergreen = Color(0xFF3478F6); // Xanh dương chính
  static const evergreenDark = Color(0xFF8FB4FF); // Xanh cho dark theme
  static const terracotta = Color(0xFF8057D7); // Tím phụ

  static const canvas = Color(0xFFF3F6FF);
  static const ink = Color(0xFF17233D);
  static const mutedInk = Color(0xFF65738D);
  static const border = Color(0xFFDDE5F4);

  static const success = Color(0xFF2E9D78);
  static const warning = Color(0xFFE89634);
  static const danger = Color(0xFFD95869);
}

abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: isLight ? AppPalette.evergreen : AppPalette.evergreenDark,
          brightness: brightness,
        ).copyWith(
          primary: isLight ? AppPalette.evergreen : AppPalette.evergreenDark,
          onPrimary: isLight ? Colors.white : const Color(0xFF102A52),
          primaryContainer: isLight
              ? const Color(0xFFDFE9FF)
              : const Color(0xFF29436B),
          onPrimaryContainer: isLight
              ? const Color(0xFF183A78)
              : const Color(0xFFE0EAFF),

          secondary: isLight ? AppPalette.terracotta : const Color(0xFFC1A3FF),
          onSecondary: isLight ? Colors.white : const Color(0xFF34215D),
          secondaryContainer: isLight
              ? const Color(0xFFEEE5FF)
              : const Color(0xFF49356E),
          onSecondaryContainer: isLight
              ? const Color(0xFF3E286B)
              : const Color(0xFFF0E7FF),

          tertiary: isLight ? AppPalette.success : const Color(0xFF7ED7AD),
          onTertiary: isLight ? Colors.white : const Color(0xFF123B2E),
          tertiaryContainer: isLight
              ? const Color(0xFFD7F4E7)
              : const Color(0xFF22533F),
          onTertiaryContainer: isLight
              ? const Color(0xFF174C39)
              : const Color(0xFFD6F4E6),

          surface: isLight ? AppPalette.canvas : const Color(0xFF131C2C),
          onSurface: isLight ? AppPalette.ink : const Color(0xFFE7EDFA),
          outline: isLight ? const Color(0xFF8493AD) : const Color(0xFF75839B),
          outlineVariant: isLight ? AppPalette.border : const Color(0xFF35445D),

          error: isLight ? AppPalette.danger : const Color(0xFFFF9BA8),
          onError: isLight ? Colors.white : const Color(0xFF4B0E1A),
          errorContainer: isLight
              ? const Color(0xFFFFE4E8)
              : const Color(0xFF6D2230),
          onErrorContainer: isLight
              ? const Color(0xFF671C2A)
              : const Color(0xFFFFDFE4),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: isLight ? Colors.white : const Color(0xFF202925),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF202925),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
        selectedColor: scheme.primaryContainer,
        showCheckmark: false,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
