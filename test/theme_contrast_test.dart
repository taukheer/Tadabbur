// Guards the fix for the "app is unreadable in dark mode" reports.
//
// Two things are pinned here:
//   1. Every brightness-aware palette accessor clears WCAG contrast
//      against the surface it is designed to land on, in *both*
//      themes. The original bug was a screenful of light-mode-only
//      constants painted onto the navy dark surface.
//   2. Appearance defaults to light and round-trips through storage,
//      so a user on a dark-mode phone is not forced into the dark
//      theme with no way back.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/core/theme/app_theme.dart';

/// Relative luminance per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Composites [fg] — alpha included — over the opaque [bg].
Color flatten(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectReadable(
    String what,
    Color fg,
    ThemeData theme, {
    double min = 4.5,
  }) {
    final bg = theme.colorScheme.surface;
    final ratio = contrast(flatten(fg, bg), bg);
    expect(
      ratio,
      greaterThanOrEqualTo(min),
      reason: '$what is ${ratio.toStringAsFixed(2)}:1 against the surface, '
          'below the $min:1 floor',
    );
  }

  group('palette contrast on the themed surface', () {
    // The schemes are inspected directly rather than via AppTheme.light
    // / .dark, because building the full ThemeData pulls the Inter text
    // theme through google_fonts, which wants the network.
    final themes = <String, ThemeData Function()>{
      'light': () => ThemeData(colorScheme: AppTheme.lightScheme),
      'dark': () => ThemeData(colorScheme: AppTheme.darkScheme),
      'midnight': () => ThemeData(colorScheme: AppTheme.midnightScheme),
    };

    themes.forEach((name, buildTheme) {
      test('$name: body and brand ink are legible', () {
        final theme = buildTheme();
        expectReadable('inkPrimary', theme.inkPrimary, theme);
        expectReadable('inkSecondary', theme.inkSecondary, theme);
        expectReadable('brandInk', theme.brandInk, theme);
      });

      test('$name: supporting ink clears large-text contrast', () {
        final theme = buildTheme();
        expectReadable('inkTertiary', theme.inkTertiary, theme, min: 3.0);
        expectReadable('warmInk', theme.warmInk, theme, min: 3.0);
      });

      test('$name: softened brand ink stays visible at every alpha', () {
        final theme = buildTheme();
        for (final alpha in [0.3, 0.4, 0.5, 0.6, 0.7]) {
          expectReadable(
            'brandInkAt($alpha)',
            theme.brandInkAt(alpha),
            theme,
            min: 4.5,
          );
        }
      });

      test('$name: button labels contrast against their own fill', () {
        final theme = buildTheme();
        for (final (label, fill) in [
          ('brandFill', theme.brandFill),
          ('brandInk', theme.brandInk),
        ]) {
          final ratio = contrast(theme.onBrandInk, fill);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'onBrandInk on $label is ${ratio.toStringAsFixed(2)}:1 — '
                'this is the "I felt this" button bug',
          );
        }
      });

      test('$name: card text contrasts against the card surface', () {
        final theme = buildTheme();
        final ratio = contrast(theme.colorScheme.onSurface, theme.cardSurface);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'onSurface on cardSurface is ${ratio.toStringAsFixed(2)}:1',
        );
      });

      test('$name: softened warm and body ink stay visible', () {
        final theme = buildTheme();
        for (final alpha in [0.25, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]) {
          expectReadable('inkAt($alpha)', theme.inkAt(alpha), theme);
          expectReadable('warmInkAt($alpha)', theme.warmInkAt(alpha), theme);
        }
      });

      test('$name: accent, streak, stat and tier inks are legible', () {
        final theme = buildTheme();
        expectReadable('accentInk', theme.accentInk, theme);
        expectReadable('streakInk', theme.streakInk, theme);
        expectReadable('statInk', theme.statInk, theme);
        for (final tier in [1, 2, 3]) {
          expectReadable('tierInk($tier)', theme.tierInk(tier), theme);
        }
        expectReadable('error', theme.colorScheme.error, theme);
      });

      test('$name: ayah ink contrasts against the sacred panel', () {
        final theme = buildTheme();
        final ratio = contrast(theme.sacredInk, theme.sacredSurface);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'sacredInk on sacredSurface is '
                '${ratio.toStringAsFixed(2)}:1');
      });
    });
  });

  group('appearance preference', () {
    // LocalStorageService.init() also warms flutter_secure_storage,
    // which has no implementation under the test binding.
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
    });

    Future<LocalStorageService> storage() async {
      SharedPreferences.setMockInitialValues({});
      final s = LocalStorageService();
      await s.init();
      return s;
    }

    test('defaults to light so dark-mode phones are not forced in', () async {
      expect((await storage()).themeMode, 'light');
    });

    test('round-trips the user choice', () async {
      final s = await storage();
      for (final mode in ['dark', 'system', 'light']) {
        await s.setThemeMode(mode);
        expect(s.themeMode, mode);
      }
    });

    test('text size defaults to the designed size and round-trips',
        () async {
      final s = await storage();
      expect(s.textScale, 1.0);
      for (final scale in [0.9, 1.15, 1.3, 1.0]) {
        await s.setTextScale(scale);
        expect(s.textScale, scale);
      }
    });
  });
}
