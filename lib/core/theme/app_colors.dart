import 'package:flutter/material.dart';

/// Tadabbur color palette.
///
/// Sacred, minimal, Islamic-inspired. Every shade is chosen to evoke
/// reverence, calm, and focused contemplation.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Primary: Emerald green -- the traditional color of Islam
  // ---------------------------------------------------------------------------
  // The palette was built on Material Green (#1B5E20), which sits at
  // hue 124° — a yellow-green that reads olive and muddy next to the
  // warm cream ground. Everything below is the same family shifted to
  // ~143°, a true emerald: cleaner and fresher at identical lightness,
  // so no contrast is traded away for the nicer hue.

  /// Brand green as *ink* — text, icons, borders, tint fills. Kept
  /// dark deliberately: this is the value the readability floors are
  /// calibrated against, so lightening it would push quiet brand text
  /// back under WCAG AA. 7.00:1 on cream.
  static const Color primary = Color(0xFF166534);

  /// Brand green as a solid *fill* — the primary buttons and the
  /// selected-tab chrome. Fills have the opposite requirement to ink:
  /// only the white label on top needs contrast (5.14:1 here), so the
  /// green itself can be brighter and livelier than [primary]. This is
  /// what stops the main CTA reading as a heavy dark slab.
  static const Color primaryFill = Color(0xFF177E3C);

  static const Color primaryLight = Color(0xFF1E8449);
  static const Color primaryDark = Color(0xFF08351E);
  static const Color primarySurface = Color(0xFFE7F5EC);
  static const Color primaryMuted = Color(0xFF7DD3A0);

  // ---------------------------------------------------------------------------
  // Accent: Warm gold -- evokes illuminated manuscripts
  // ---------------------------------------------------------------------------
  static const Color accent = Color(0xFFD4A856);
  static const Color accentLight = Color(0xFFE6C87A);
  static const Color accentDark = Color(0xFFB8922E);
  /// Gold dark enough to be read as *text* on the cream surface.
  /// [accentDark] itself is only 2.87:1 there — fine as a fill or a
  /// dark-mode ink, unreadable as light-mode body copy.
  static const Color accentTextLight = Color(0xFF8A6D1C);
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
  // Darkened from #79747E, which measured 4.47:1 on the cream surface —
  // below WCAG AA at *full* opacity, so no amount of alpha tuning could
  // rescue the text using it. #6B6673 keeps the cool-grey cast and
  // clears AA at 5.46:1.
  static const Color textTertiaryLight = Color(0xFF6B6673);

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
  // The tier hues are pastels tuned for the navy surface, where they
  // read at 6–10:1. On cream they collapse to 1.7–2.7:1, and they are
  // used for the tier label *and* the prompt quote on every journal
  // entry — so each gets a light-mode counterpart of the same hue.
  //
  /// Tier 1 -- "Quick Reflection": soft calming blue
  static const Color tier1 = Color(0xFF64B5F6);
  static const Color tier1Ink = Color(0xFF1565C0);
  static const Color tier1Surface = Color(0xFFE3F2FD);

  /// Tier 2 -- "Deeper Reflection": warm amber
  static const Color tier2 = Color(0xFFFFB74D);
  static const Color tier2Ink = Color(0xFF9A5700);
  static const Color tier2Surface = Color(0xFFFFF3E0);

  /// Tier 3 -- "Scholar's Reflection": deep emerald
  static const Color tier3 = Color(0xFF4CAF50);
  static const Color tier3Ink = Color(0xFF2E7D32);
  static const Color tier3Surface = Color(0xFFE8F5E9);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  // Darkened from #EF5350, which was 3.42:1 on cream — a warning the
  // reader can barely see is not a warning. Only referenced by the
  // light ColorScheme (dark has its own #FFB4AB), so this is a
  // light-mode change alone.
  static const Color error = Color(0xFFB3261E);
  static const Color info = Color(0xFF42A5F5);

  // ---------------------------------------------------------------------------
  // Warm tones — used for pills, tags, card backgrounds, borders, labels
  // ---------------------------------------------------------------------------
  // Darkened from #8B7355 (4.40:1 on cream — under AA even at full
  // opacity, and it is used at 0.5–0.8 alpha). #6E5A42 holds the same
  // warm-brown character at 6.44:1.
  static const Color warmBrown = Color(0xFF6E5A42);
  static const Color warmBrownDark = Color(0xFFBFA87E);
  static const Color warmSurface = Color(0xFFF5F0E8);
  static const Color warmSurfaceDark = Color(0xFF1E2C3E);
  static const Color warmSurfaceLight = Color(0xFFF8F5F0);
  static const Color warmSurfaceLightDark = Color(0xFF1A2836);
  static const Color warmBorder = Color(0xFFE8E0D4);
  static const Color warmBorderDark = Color(0xFF2E3D50);

  // ---------------------------------------------------------------------------
  // Button variants
  // ---------------------------------------------------------------------------
  static const Color primaryDarkButton = Color(0xFF2E3A2F);
  static const Color primaryDarkButtonDark = Color(0xFF3A5040);

  // ---------------------------------------------------------------------------
  // Revelation type & Sajdah indicators
  // ---------------------------------------------------------------------------
  static const Color makkiSurface = Color(0xFFFFF4D6);
  static const Color makkiText = Color(0xFF7A5A12);
  // Sage-green palette to harmonize with the warm-beige pill it lives
  // inside. The previous Material-green (#E8F5E9 / #2E7D32) clashed with
  // the warm-brown chrome — too saturated, wrong undertone.
  static const Color madaniSurface = Color(0xFFE2EAD8);
  static const Color madaniText = Color(0xFF4A6B3F);
  static const Color sajdahSurface = Color(0xFFEDE7F6);
  static const Color sajdahText = Color(0xFF4A148C);

  // ---------------------------------------------------------------------------
  // Progress / stats
  // ---------------------------------------------------------------------------
  // Darkened from #5C6BC0 (4.77:1 on cream — no headroom once any
  // alpha is applied). Paired with [statIndigoDark] for the navy
  // surface, where this value would read at 2.79:1.
  static const Color statIndigo = Color(0xFF4A5AAF);
  static const Color statIndigoDark = Color(0xFF9FA8DA);
  static const Color streakOrange = Color(0xFFE65100);
  /// [streakOrange] reads at 3.72:1 on cream; this is the same hue
  /// taken dark enough for text.
  static const Color streakTextLight = Color(0xFFC24300);
  static const Color tierAmber = Color(0xFFFF8F00);

  // ---------------------------------------------------------------------------
  // Miscellaneous
  // ---------------------------------------------------------------------------
  static const Color dividerLight = Color(0xFFE0DCD4);
  static const Color dividerDark = Color(0xFF2E3D50);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  static const Color scrim = Color(0x52000000);
}

/// Brightness-aware palette accessors.
///
/// The raw [AppColors] constants are single-brightness by design:
/// `textPrimaryLight` really is a near-black, `primary` really is a
/// dark emerald. Reaching for them directly inside a widget produces
/// text that vanishes the moment the app renders in dark mode — the
/// bug that made the app unreadable for users on dark-mode phones.
///
/// Use these accessors instead of the raw constants anywhere a color
/// lands on a themed surface:
///
/// ```dart
/// final theme = Theme.of(context);
/// Text('…', style: TextStyle(color: theme.inkPrimary));
/// ```
///
/// The only legitimate uses of the raw light-mode constants are
/// surfaces that are *always* light regardless of theme — the share
/// cards, which render a fixed parchment image for export.
extension AppPalette on ThemeData {
  bool get _dark => brightness == Brightness.dark;

  /// Body/heading text on a themed surface.
  Color get inkPrimary =>
      _dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  /// Supporting text — captions, subtitles, metadata.
  Color get inkSecondary =>
      _dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  /// De-emphasised text — hints, disabled labels.
  Color get inkTertiary =>
      _dark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

  /// The emerald brand color as a *foreground* — labels, icons,
  /// borders, tint fills. Lifts to the muted mint in dark mode, where
  /// the dark emerald is indistinguishable from the navy ground.
  Color get brandInk => _dark ? AppColors.primaryMuted : AppColors.primary;

  /// Brand green for solid fills — primary buttons, selected-tab
  /// chrome. Brighter than [brandInk] in light mode; in dark mode the
  /// mint already is the fill.
  Color get brandFill => _dark ? AppColors.primaryMuted : AppColors.primaryFill;

  /// Text/icon color that sits legibly on a [brandFill] surface.
  Color get onBrandInk => _dark ? AppColors.primaryDark : Colors.white;

  /// Body ink softened to [alpha], never below the readable floor.
  ///
  /// This is the workhorse: most of the app's supporting text —
  /// translations, subtitles, timestamps, metadata — is `onSurface` at
  /// some fraction of opacity. Those fractions were chosen by eye and
  /// land far below WCAG AA: on the cream surface, 40% measured 2.5:1
  /// and 30% measured 1.9:1. Readers with any degree of low vision
  /// simply could not make them out, and that is what users reported.
  ///
  /// Rather than clamp (which would collapse three tiers of quiet into
  /// one flat value), the alpha is *remapped* into the range that is
  /// actually legible against these two surfaces. Quieter text stays
  /// quieter; nothing lands below ~5.5:1.
  Color inkAt(double alpha) =>
      colorScheme.onSurface.withValues(alpha: _remap(alpha, 0.55));

  /// [brandInk] softened to [alpha], never below the readable floor.
  ///
  /// The emerald needs a higher floor than [inkAt] in light mode — it
  /// is a mid-tone, so it runs out of contrast against cream sooner
  /// than near-black does (4.5:1 needs 78% opacity, versus 60%).
  Color brandInkAt(double alpha) =>
      brandInk.withValues(alpha: _remap(alpha, _dark ? 0.55 : 0.75));

  /// Remaps [alpha] into `[floor, 1.0]`, preserving ordering.
  ///
  /// The design's opacity scale assumed a wider usable range than these
  /// surfaces actually offer. Compressing it upward keeps the intent —
  /// a hierarchy of emphasis — while putting the whole scale above the
  /// accessibility floor.
  static double _remap(double alpha, double floor) {
    // These helpers exist to stop *foreground* text and icons falling
    // below the readability floor. Passing a tint alpha through one
    // does the opposite of what the caller wants — it drags a 6%
    // background wash up to ~78% and paints a solid block. (That is
    // exactly how the "Today · Day 1" chip ended up as green-on-green.)
    // For fills, borders and washes, call `brandInk.withValues(...)`
    // directly and leave the alpha alone.
    assert(
      alpha >= 0.25,
      'Ink helpers are for foregrounds only — alpha $alpha looks like a '
      'tint. Use the raw ink with .withValues(alpha: $alpha) instead.',
    );
    return floor + (1 - floor) * alpha.clamp(0.0, 1.0);
  }

  /// Card/tile background for surfaces that were hardcoded white.
  Color get cardSurface =>
      _dark ? AppColors.surfaceDarkCard : Colors.white;

  /// Slightly raised surface — pickers, inline panels.
  Color get elevatedSurface =>
      _dark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated;

  /// Gold as a *foreground*. The palette's gold is a fill color; used
  /// as text it needs to go dark on cream and bright on navy.
  Color get accentInk =>
      _dark ? AppColors.accentLight : AppColors.accentTextLight;

  /// A reflection-tier hue as a *foreground*. Pass 1, 2 or 3.
  Color tierInk(int tier) => switch (tier) {
        1 => _dark ? AppColors.tier1 : AppColors.tier1Ink,
        2 => _dark ? AppColors.tier2 : AppColors.tier2Ink,
        _ => _dark ? AppColors.tier3 : AppColors.tier3Ink,
      };

  /// The indigo used for the "Historical context" layer and the stats
  /// tiles, as a *foreground* — dark on cream, light on navy.
  Color get statInk =>
      _dark ? AppColors.statIndigoDark : AppColors.statIndigo;

  /// Streak amber as a *foreground* — same story as [accentInk].
  Color get streakInk =>
      _dark ? AppColors.streakActive : AppColors.streakTextLight;

  /// Warm brown used for pills, tags and quiet labels.
  Color get warmInk => _dark ? AppColors.warmBrownDark : AppColors.warmBrown;

  /// [warmInk] softened to [alpha], never below the readable floor.
  ///
  /// The warm brown carries the least contrast of any ink in the
  /// palette on either surface, so it gets the highest floor.
  Color warmInkAt(double alpha) =>
      warmInk.withValues(alpha: _remap(alpha, _dark ? 0.7 : 0.8));

  /// Warm beige panel background.
  Color get warmSurfaceInk =>
      _dark ? AppColors.warmSurfaceDark : AppColors.warmSurface;

  /// The lighter warm panel variant.
  Color get warmSurfaceLightInk =>
      _dark ? AppColors.warmSurfaceLightDark : AppColors.warmSurfaceLight;

  /// Hairline borders on warm panels.
  Color get warmBorderInk =>
      _dark ? AppColors.warmBorderDark : AppColors.warmBorder;

  /// Parchment background behind the ayah itself.
  Color get sacredSurface =>
      _dark ? AppColors.sacredBackgroundDark : AppColors.sacredBackground;

  /// Border around the ayah display area.
  Color get sacredBorderInk =>
      _dark ? AppColors.sacredBorderDark : AppColors.sacredBorder;

  /// Ink for the ayah text itself.
  Color get sacredInk =>
      _dark ? AppColors.sacredTextDark : AppColors.sacredText;

  /// Divider hairline.
  Color get dividerInk =>
      _dark ? AppColors.dividerDark : AppColors.dividerLight;

  /// Fill for the deep-green secondary button. Lifted in dark mode so
  /// the button reads as a button and not as a hole in the navy.
  Color get primaryButtonFill => _dark
      ? AppColors.primaryDarkButtonDark
      : AppColors.primaryDarkButton;
}

/// [AppPalette] for call sites that hold a [BuildContext] but no
/// local `theme` variable.
extension AppPaletteContext on BuildContext {
  ThemeData get palette => Theme.of(this);
}
