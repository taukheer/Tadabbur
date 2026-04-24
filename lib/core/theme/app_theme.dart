import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Tadabbur application theme -- Material 3, sacred & minimal.
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------
  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accentSurface,
      onSecondaryContainer: AppColors.accentDark,
      tertiary: AppColors.tier1,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tier1Surface,
      onTertiaryContainer: const Color(0xFF0D47A1),
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
      outline: AppColors.dividerLight,
      outlineVariant: AppColors.dividerLight.withAlpha(128),
      shadow: Colors.black,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.textPrimaryDark,
      inversePrimary: AppColors.primaryMuted,
      surfaceContainerHighest: AppColors.surfaceLightCard,
    );

    return _buildTheme(colorScheme);
  }

  // ---------------------------------------------------------------------------
  // Dark theme
  // ---------------------------------------------------------------------------
  static ThemeData get dark {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryMuted,
      onPrimary: AppColors.primaryDark,
      primaryContainer: AppColors.primary,
      onPrimaryContainer: AppColors.primarySurface,
      secondary: AppColors.accentLight,
      onSecondary: AppColors.accentDark,
      secondaryContainer: AppColors.accentDark,
      onSecondaryContainer: AppColors.accentSurface,
      tertiary: AppColors.tier1,
      onTertiary: const Color(0xFF003258),
      tertiaryContainer: const Color(0xFF004880),
      onTertiaryContainer: AppColors.tier1Surface,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      outline: AppColors.dividerDark,
      outlineVariant: AppColors.dividerDark.withAlpha(128),
      shadow: Colors.black,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.textPrimaryLight,
      inversePrimary: AppColors.primary,
      surfaceContainerHighest: AppColors.surfaceDarkCard,
    );

    return _buildTheme(colorScheme);
  }

  // ---------------------------------------------------------------------------
  // Midnight (OLED true-black) theme
  // ---------------------------------------------------------------------------
  //
  // For late-night / pre-dawn use. The regular dark theme uses a warm
  // navy surface (#0D1B2A) that glows off the face in a dark bedroom;
  // the midnight variant swaps to pure #000 so OLED pixels are fully
  // off outside of content areas. Primary/accent hues are lifted
  // slightly so they don't lose presence against the deeper ground.
  //
  // Activated automatically during the night band (see
  // time_of_day_ribbon.bandForHour); this isn't a user toggle — it's
  // a prayer-time-aware design choice for the users who open the app
  // at fajr in a dark room.
  static ThemeData get midnightOled {
    final base = dark;
    const black = Color(0xFF000000);
    const nearBlack = Color(0xFF0A0A0A);
    final scheme = base.colorScheme.copyWith(
      surface: black,
      onSurface: const Color(0xFFF0EDE7),
      surfaceContainerHighest: nearBlack,
      outline: const Color(0xFF1F1F1F),
      outlineVariant: const Color(0xFF141414),
      primary: AppColors.primaryMuted,
      inverseSurface: AppColors.surfaceLight,
    );
    return _buildTheme(scheme);
  }

  // ---------------------------------------------------------------------------
  // Shared builder
  // ---------------------------------------------------------------------------
  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    final textTheme = AppTypography.textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,

      // -- AppBar ---------------------------------------------------------------
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.sectionHeader.copyWith(
          color: colorScheme.onSurface,
          fontSize: 18,
        ),
      ),

      // -- Cards ----------------------------------------------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        color: isDark
            ? AppColors.surfaceDarkCard
            : AppColors.surfaceLightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outline.withAlpha(51),
            width: 0.5,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // -- Elevated Button ------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.buttonLabel,
        ),
      ),

      // -- Text Button ----------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppTypography.buttonLabel,
        ),
      ),

      // -- Outlined Button ------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: AppTypography.buttonLabel,
        ),
      ),

      // -- Floating Action Button -----------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // -- Input Decoration -----------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceDarkElevated
            : AppColors.surfaceLightElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withAlpha(128)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        hintStyle: AppTypography.englishCaption.copyWith(
          color: colorScheme.onSurfaceVariant.withAlpha(153),
        ),
        labelStyle: AppTypography.englishLabel.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // -- Bottom Navigation / Navigation Bar -----------------------------------
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
      ),

      // -- Bottom Sheet ---------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // -- Dialog ---------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // -- Chip -----------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outline.withAlpha(77)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: AppTypography.englishLabel.copyWith(
          color: colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // -- Divider --------------------------------------------------------------
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withAlpha(51),
        thickness: 0.5,
        space: 1,
      ),

      // -- Snackbar -------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceDarkElevated
            : AppColors.textPrimaryLight,
        contentTextStyle:
            AppTypography.englishBody.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
      ),

      // -- Icon -----------------------------------------------------------------
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),

      // -- Page transition (calm fade) ------------------------------------------
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // -- Splash / highlight ---------------------------------------------------
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: colorScheme.primary.withAlpha(20),
    );
  }

  // ---------------------------------------------------------------------------
  // Elevation / shadow helpers (use in custom widgets)
  // ---------------------------------------------------------------------------

  /// Subtle shadow for cards that should feel "resting".
  static List<BoxShadow> get calmShadow => const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Slightly more pronounced shadow for focused / lifted elements.
  static List<BoxShadow> get liftedShadow => const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  /// Glow effect used behind the streak counter.
  static List<BoxShadow> streakGlow(Color color) => [
        BoxShadow(
          color: color.withAlpha(51),
          blurRadius: 24,
          spreadRadius: 4,
        ),
      ];

  // ---------------------------------------------------------------------------
  // Sacred container decoration
  // ---------------------------------------------------------------------------

  /// Decoration for the ayah display area (light mode).
  static BoxDecoration get sacredContainerLight => BoxDecoration(
        color: AppColors.sacredBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.sacredBorder,
          width: 0.5,
        ),
        boxShadow: calmShadow,
      );

  /// Decoration for the ayah display area (dark mode).
  static BoxDecoration get sacredContainerDark => BoxDecoration(
        color: AppColors.sacredBackgroundDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.sacredBorderDark,
          width: 0.5,
        ),
        boxShadow: calmShadow,
      );
}
