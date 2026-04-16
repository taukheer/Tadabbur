import 'package:flutter/foundation.dart';

/// Severity of a sync failure, driving whether it's shown to the user.
///
/// - [quiet]: debug-only. Analytics pings and Firestore mirror writes
///   that already have a pending-replay queue fall here — the user
///   doesn't need to see a banner every time analytics is rate-limited.
/// - [userVisible]: surfaces a non-blocking banner in [AppShell]. Used
///   for QF User API sync failures where the local write succeeded but
///   the mirror on quran.com is lagging.
enum SyncSeverity { quiet, userVisible }

/// The most-recent sync failure worth showing to the user.
class SyncError {
  /// Short label for the failing operation (e.g. "streak sync",
  /// "bookmark · quran.com"). Shown in the banner.
  final String what;

  /// The underlying exception, kept for debugging via debugPrint.
  final Object error;

  /// When the failure happened. Used so stale banners auto-dismiss.
  final DateTime at;

  const SyncError({
    required this.what,
    required this.error,
    required this.at,
  });
}

/// Process-wide sink for sync failures.
///
/// Callers do not need a [WidgetRef] — any code path can call
/// [SyncReporter.report] and the UI layer (AppShell) listens via the
/// exposed [ValueNotifier]. This avoids threading a [Ref] through every
/// [StateNotifier] constructor just to surface an error.
///
/// Quiet failures are logged but do not update the notifier.
class SyncReporter {
  SyncReporter._();

  /// Read-only stream of the most-recent user-visible sync error, or
  /// null when nothing needs to be surfaced.
  static final ValueNotifier<SyncError?> lastError =
      ValueNotifier<SyncError?>(null);

  /// Log a sync failure. When [severity] is [SyncSeverity.userVisible]
  /// the banner in [AppShell] will show the [what] label.
  static void report(
    String what,
    Object error, {
    SyncSeverity severity = SyncSeverity.userVisible,
  }) {
    debugPrint('[Sync · $what] $error');
    if (severity == SyncSeverity.userVisible) {
      lastError.value = SyncError(
        what: what,
        error: error,
        at: DateTime.now(),
      );
    }
  }

  /// User dismissed the banner. Clears the last error so the banner
  /// hides — a fresh failure will bring it back.
  static void dismiss() {
    lastError.value = null;
  }
}
