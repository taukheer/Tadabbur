import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:home_widget/home_widget.dart';

import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';

/// Writes today's ayah to the shared storage that the Android
/// AppWidgetProvider (and later iOS WidgetKit) reads from.
///
/// Call [updateWithAyah] whenever the daily ayah loads or the user
/// completes one so the widget reflects the user's actual progress,
/// not a stale snapshot from when the widget was first added.
///
/// The keys here MUST match what [TadabburWidgetProvider] reads on the
/// Android side (see TadabburWidgetProvider.kt).
class HomeWidgetService {
  HomeWidgetService._();

  static const _androidWidgetName = 'TadabburWidgetProvider';
  static const _iosWidgetName = 'TadabburWidget';

  /// Widget providers that should be updated after writing.
  static const _providers = [_androidWidgetName, _iosWidgetName];

  /// Write the given ayah to widget storage and trigger a refresh.
  /// Safe to call even if no widget has been added to the home screen —
  /// the data sits in shared prefs ready for when one is.
  ///
  /// Failures that indicate a real misconfiguration (e.g. the Android
  /// AppWidgetProvider receiver isn't registered in the manifest) are
  /// reported to Crashlytics as non-fatal errors so silent breakage on
  /// user devices becomes visible. Platform-mismatch failures (trying
  /// to update the iOS widget from Android or vice versa) are
  /// intentionally ignored — they're expected.
  static Future<void> updateWithAyah({
    required Ayah ayah,
    required int dayNumber,
  }) async {
    try {
      // Keep the body short enough for the widget's two-line clamp.
      // Very long ayat (e.g. 2:282) would otherwise dominate the card.
      final shortArabic = _truncateArabic(ayah.textUthmani, maxChars: 180);
      final shortTranslation =
          _cleanAndTruncateTranslation(ayah.translationText, maxChars: 90);
      final surahName = surahNameFromKey(ayah.verseKey);

      await Future.wait([
        HomeWidget.saveWidgetData('arabic', shortArabic),
        HomeWidget.saveWidgetData('translation', shortTranslation),
        HomeWidget.saveWidgetData('verseKey', ayah.verseKey),
        HomeWidget.saveWidgetData('surahName', surahName),
        HomeWidget.saveWidgetData('dayLabel', 'Day $dayNumber'),
      ]);

      for (final provider in _providers) {
        // Skip providers that don't belong on this platform so we
        // don't generate noise for the unavoidable "no such widget"
        // errors on the mismatched side.
        if (!_isRelevantForPlatform(provider)) continue;

        try {
          await HomeWidget.updateWidget(
            name: provider,
            androidName: provider,
            iOSName: _iosWidgetName,
          );
        } catch (error, stack) {
          _reportWidgetFailure(
            phase: 'updateWidget',
            provider: provider,
            verseKey: ayah.verseKey,
            error: error,
            stack: stack,
          );
        }
      }
    } catch (error, stack) {
      _reportWidgetFailure(
        phase: 'saveWidgetData',
        provider: 'all',
        verseKey: ayah.verseKey,
        error: error,
        stack: stack,
      );
    }
  }

  static bool _isRelevantForPlatform(String provider) {
    if (Platform.isAndroid) return provider == _androidWidgetName;
    if (Platform.isIOS) return provider == _iosWidgetName;
    return false;
  }

  static void _reportWidgetFailure({
    required String phase,
    required String provider,
    required String verseKey,
    required Object error,
    required StackTrace stack,
  }) {
    // Quiet severity: audio/UX still works without the widget, so don't
    // surface a user-visible banner. But do log it and push a non-fatal
    // to Crashlytics so we notice if it's happening broadly.
    SyncReporter.report(
      'widget · $phase ($provider)',
      error,
      severity: SyncSeverity.quiet,
    );
    unawaited(FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: 'home widget $phase failed',
      information: [
        'provider=$provider',
        'platform=${Platform.operatingSystem}',
        'verseKey=$verseKey',
      ],
      fatal: false,
    ));
  }

  static String _truncateArabic(String text, {required int maxChars}) {
    final trimmed = text.trim();
    if (trimmed.length <= maxChars) return trimmed;
    // Arabic word-boundary ellipsis — don't slice mid-word.
    final cut = trimmed.substring(0, maxChars);
    final lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > 0 ? cut.substring(0, lastSpace) : cut}…';
  }

  static String _cleanAndTruncateTranslation(
    String? raw, {
    required int maxChars,
  }) {
    if (raw == null) return '';
    final cleaned = raw
        .replaceAll(RegExp(r'\.\d+'), '') // strip ".2" footnote refs
        // Word-glued footnote digits ("Lord1 of") — mirror the same
        // defensive clean used in journal_screen / share_card.
        // `replaceAllMapped`, not `replaceAll` — Dart's `replaceAll`
        // doesn't expand `$1` back-references.
        .replaceAllMapped(
          RegExp(r'(\w)\d+(?=\s|[,.!?;:"]|$)'),
          (m) => m.group(1)!,
        )
        .replaceAll(RegExp(r'\s*-\s*$'), '')
        .trim();
    if (cleaned.length <= maxChars) return cleaned;
    final cut = cleaned.substring(0, maxChars);
    final lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > 0 ? cut.substring(0, lastSpace) : cut}…';
  }

}
