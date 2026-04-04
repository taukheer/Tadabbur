import 'package:flutter/material.dart';

/// Tadabbur color palette.
///
/// Sacred, minimal, Islamic-inspired. Every shade is chosen to evoke
/// reverence, calm, and focused contemplation.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Primary: Emerald green -- the traditional color of Islam
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF0A3D0A);
  static const Color primarySurface = Color(0xFFE8F5E9);
  static const Color primaryMuted = Color(0xFF81C784);

  // ---------------------------------------------------------------------------
  // Accent: Warm gold -- evokes illuminated manuscripts
  // ---------------------------------------------------------------------------
  static const Color accent = Color(0xFFD4A856);
  static const Color accentLight = Color(0xFFE6C87A);
  static const Color accentDark = Color(0xFFB8922E);
  static const Color accentSurface = Color(0xFFFFF8E7);

  // ---------------------------------------------------------------------------
  // Surface / Background
  // ---------------------------------------------------------------------------
  /// Light mode: warm cream/ivory that feels like aged parchment.
  static const Color surfaceLight = Color(0xFFFEFDF8);
  static const Color surfaceLightElevated = Color(0xFFFFFDF5);
  static const Color surfaceLightCard = Color(0xFFFFFBF0);

  /// Dark mode: deep navy with a hint of warmth.
  static const Color surfaceDark = Color(0xFF0D1B2A);
  static const Color surfaceDarkElevated = Color(0xFF1B2B3E);
  static const Color surfaceDarkCard = Color(0xFF223449);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------
  static const Color textPrimaryLight = Color(0xFF1C1B1F);
  static const Color textSecondaryLight = Color(0xFF49454F);
  static const Color textTertiaryLight = Color(0xFF79747E);

  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFCAC4D0);
  static const Color textTertiaryDark = Color(0xFF938F99);

  // ---------------------------------------------------------------------------
  // Sacred: Warm tones used specifically for ayah/verse display areas
  // ---------------------------------------------------------------------------
  static const Color sacredBackground = Color(0xFFFFF9EE);
  static const Color sacredBackgroundDark = Color(0xFF1A2636);
  static const Color sacredBorder = Color(0xFFE8D5B0);
  static const Color sacredBorderDark = Color(0xFF3A4A5C);
  static const Color sacredText = Color(0xFF2C1810);
  static const Color sacredTextDark = Color(0xFFF0E6D4);

  // ---------------------------------------------------------------------------
  // Streak indicator: Amber / gold tones
  // ---------------------------------------------------------------------------
  static const Color streakActive = Color(0xFFF59E0B);
  static const Color streakInactive = Color(0xFFD1D5DB);
  static const Color streakGlow = Color(0x33F59E0B);
  static const Color streakFrozen = Color(0xFF93C5FD);

  // ---------------------------------------------------------------------------
  // Reflection tier colors
  // ---------------------------------------------------------------------------
  /// Tier 1 -- "Quick Reflection": soft calming blue
  static const Color tier1 = Color(0xFF64B5F6);
  static const Color tier1Surface = Color(0xFFE3F2FD);

  /// Tier 2 -- "Deeper Reflection": warm amber
  static const Color tier2 = Color(0xFFFFB74D);
  static const Color tier2Surface = Color(0xFFFFF3E0);

  /// Tier 3 -- "Scholar's Reflection": deep emerald
  static const Color tier3 = Color(0xFF4CAF50);
  static const Color tier3Surface = Color(0xFFE8F5E9);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // ---------------------------------------------------------------------------
  // Miscellaneous
  // ---------------------------------------------------------------------------
  static const Color dividerLight = Color(0xFFE0DCD4);
  static const Color dividerDark = Color(0xFF2E3D50);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  static const Color scrim = Color(0x52000000);
}
