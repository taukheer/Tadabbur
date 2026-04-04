import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tadabbur typographic scale.
///
/// Arabic styles use the locally-bundled Amiri Quran font (declared in
/// pubspec.yaml). English styles use Google Fonts Inter for a clean,
/// highly-legible sans-serif feel.
abstract final class AppTypography {
  // ---------------------------------------------------------------------------
  // Arabic
  // ---------------------------------------------------------------------------

  /// Main ayah display -- large, centered, right-to-left.
  static const TextStyle arabicAyah = TextStyle(
    fontFamily: 'AmiriQuran',
    fontSize: 32,
    height: 2.0,
    letterSpacing: 0,
    color: AppColors.sacredText,
    textBaseline: TextBaseline.alphabetic,
  );

  /// Word-by-word view -- medium size, still uses Amiri Quran.
  static const TextStyle arabicWord = TextStyle(
    fontFamily: 'AmiriQuran',
    fontSize: 20,
    height: 1.8,
    letterSpacing: 0,
    color: AppColors.sacredText,
  );

  /// Small Arabic annotation (e.g. surah name header).
  static const TextStyle arabicCaption = TextStyle(
    fontFamily: 'AmiriQuran',
    fontSize: 16,
    height: 1.6,
    color: AppColors.textSecondaryLight,
  );

  // ---------------------------------------------------------------------------
  // English -- built via Google Fonts (Inter)
  // ---------------------------------------------------------------------------

  /// Standard body text.
  static TextStyle get englishBody => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0.15,
        color: AppColors.textPrimaryLight,
      );

  /// Smaller caption / metadata text.
  static TextStyle get englishCaption => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.25,
        color: AppColors.textTertiaryLight,
      );

  /// Smaller label (e.g. "Surah Al-Baqarah", verse numbers).
  static TextStyle get englishLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.4,
        color: AppColors.textSecondaryLight,
      );

  // ---------------------------------------------------------------------------
  // Special-purpose
  // ---------------------------------------------------------------------------

  /// Large bold number for the streak counter.
  static TextStyle get streakNumber => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: AppColors.streakActive,
      );

  /// Section header (e.g. "Historical Context", "Scholar's Reflection").
  static TextStyle get sectionHeader => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.textPrimaryLight,
      );

  /// Sub-section header inside content cards.
  static TextStyle get sectionSubheader => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.textSecondaryLight,
      );

  /// Journal entry text when reading back a past reflection.
  static TextStyle get journalEntry => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.7,
        letterSpacing: 0.15,
        fontStyle: FontStyle.italic,
        color: AppColors.textPrimaryLight,
      );

  /// Button label.
  static TextStyle get buttonLabel => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.3,
      );

  /// Onboarding title -- slightly larger, bolder.
  static TextStyle get onboardingTitle => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
        color: AppColors.textPrimaryLight,
      );

  /// Onboarding body.
  static TextStyle get onboardingBody => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0.15,
        color: AppColors.textSecondaryLight,
      );

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Convenience: returns a complete Google-Fonts-based [TextTheme] suitable
  /// for Material 3. Apply per-slot overrides via [ThemeData.textTheme].
  static TextTheme get textTheme => GoogleFonts.interTextTheme();
}
