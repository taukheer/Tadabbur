import 'package:flutter/material.dart';

/// Solar-time bands the ribbon cycles through.
enum SolarBand { preDawn, fajr, morning, day, dusk, maghrib, night }

/// Returns the band for the given hour (0–23).
///
/// This is a heuristic — prayer-time-aware scheduling lives elsewhere
/// and should eventually drive this too, but for a purely visual ribbon
/// local hour-of-day is accurate enough that we don't need to block on
/// network/location-derived prayer times to tint the top 40px.
SolarBand bandForHour(int hour) {
  if (hour >= 3 && hour < 5) return SolarBand.preDawn;
  if (hour >= 5 && hour < 7) return SolarBand.fajr;
  if (hour >= 7 && hour < 11) return SolarBand.morning;
  if (hour >= 11 && hour < 16) return SolarBand.day;
  if (hour >= 16 && hour < 18) return SolarBand.dusk;
  if (hour >= 18 && hour < 20) return SolarBand.maghrib;
  return SolarBand.night;
}

/// A narrow top-of-scaffold gradient whose hue follows the solar
/// band of the user's local time.
///
/// The ribbon is 40px tall and fades to transparent at the bottom so
/// it reads as atmosphere rather than a header. Headspace and similar
/// apps use the same pattern; for a Quran app it's more resonant —
/// the times of day the ribbon signals (fajr, maghrib) are the same
/// times the user prays.
class TimeOfDayRibbon extends StatelessWidget {
  /// Override the hour for testing / previews.
  final int? hourOverride;
  final double height;

  const TimeOfDayRibbon({
    super.key,
    this.hourOverride,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hour = hourOverride ?? DateTime.now().hour;
    final band = bandForHour(hour);
    final color = _colorForBand(band, isDark);

    // A transparent mid-day band gets rendered as zero-alpha gradient,
    // so the ribbon visually disappears when there's nothing to signal.
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: isDark ? 0.45 : 0.18),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  /// Sky-inspired color per band. Tuned warmer in light mode and
  /// deeper in dark mode so the ribbon reads as atmosphere in both.
  static Color _colorForBand(SolarBand band, bool isDark) {
    switch (band) {
      case SolarBand.preDawn:
        return isDark ? const Color(0xFF0F1B3A) : const Color(0xFF3A4A7C);
      case SolarBand.fajr:
        return isDark ? const Color(0xFF3A2948) : const Color(0xFFF4B084);
      case SolarBand.morning:
        return isDark ? const Color(0xFF22334A) : const Color(0xFFFFE4B5);
      case SolarBand.day:
        // Intentionally near-transparent: midday gets no ribbon.
        return Colors.transparent;
      case SolarBand.dusk:
        return isDark ? const Color(0xFF3A2630) : const Color(0xFFFFB07C);
      case SolarBand.maghrib:
        return isDark ? const Color(0xFF2B1A3A) : const Color(0xFFD46A6A);
      case SolarBand.night:
        return isDark ? const Color(0xFF0A0F1F) : const Color(0xFF2C3E66);
    }
  }
}
