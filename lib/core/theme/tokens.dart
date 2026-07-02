import 'package:flutter/material.dart';

/// OpenThings design tokens — the Things 3 visual language.
///
/// Colors, typography scale, spacing, radii, and list-icon colors, with
/// light and dark variants. Everything visual should come from here.
abstract final class OtColors {
  // Signature accent — "Things blue".
  static const accent = Color(0xFF2E7CF6);
  static const accentDark = Color(0xFF4A94F8);

  // Today star yellow.
  static const todayYellow = Color(0xFFFFC94D);

  // Deadline / overdue red.
  static const deadlineRed = Color(0xFFF2564D);

  // Sidebar list icon colors (Things uses distinct hues per list).
  static const inboxBlue = Color(0xFF5FA8F5);
  static const upcomingRed = Color(0xFFF2564D);
  static const anytimeTeal = Color(0xFF41B3AE);
  static const somedaySand = Color(0xFFC7A97B);
  static const logbookGreen = Color(0xFF54B552);
  static const trashGray = Color(0xFF9AA0A6);

  // Light surfaces.
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSidebar = Color(0xFFF5F6F8);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF1C1C1E);
  static const lightTextSecondary = Color(0xFF8A8A8E);
  static const lightDivider = Color(0xFFE5E5EA);

  // Dark surfaces.
  static const darkBackground = Color(0xFF1E2126);
  static const darkSidebar = Color(0xFF16181C);
  static const darkCard = Color(0xFF272B31);
  static const darkTextPrimary = Color(0xFFF2F2F7);
  static const darkTextSecondary = Color(0xFF98989F);
  static const darkDivider = Color(0xFF3A3D44);
}

abstract final class OtSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class OtRadii {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
}

abstract final class OtTheme {
  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accent = isDark ? OtColors.accentDark : OtColors.accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      surface: isDark ? OtColors.darkBackground : OtColors.lightBackground,
    );
    final textColor =
        isDark ? OtColors.darkTextPrimary : OtColors.lightTextPrimary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: null, // System font, like Things.
      textTheme: TextTheme(
        // Large list titles ("Today", "Upcoming").
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: -0.4,
        ),
        // Project titles.
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: -0.2,
        ),
        // To-do row titles.
        bodyLarge: TextStyle(fontSize: 15, color: textColor),
        // Notes, secondary text.
        bodyMedium: TextStyle(
          fontSize: 13,
          color: isDark
              ? OtColors.darkTextSecondary
              : OtColors.lightTextSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? OtColors.darkDivider : OtColors.lightDivider,
        thickness: 0.5,
        space: 0.5,
      ),
    );
  }
}
