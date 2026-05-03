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

  /// HTTP status code if the underlying error is an [ApiException].
  /// Null for non-HTTP failures (network, parse, etc.).
  int? get statusCode {
    final e = error;
    try {
      // Avoid an `is ApiException` check here so this file doesn't
      // need to import api_client.dart (would create a cycle).
      final dynamic dyn = e;
      final code = dyn.statusCode;
      return code is int ? code : null;
    } catch (_) {
      return null;
    }
  }

  /// Server‑returned error body if the underlying error is an
  /// [ApiException] with a captured response payload. Trimmed to a
  /// readable size so a giant HTML 500 page doesn't blow up a dialog.
  String? get serverBody {
    try {
      final dynamic dyn = error;
      final data = dyn.data;
      if (data == null) return null;
      final s = data.toString();
      return s.length > 600 ? '${s.substring(0, 600)}…' : s;
    } catch (_) {
      return null;
    }
  }

  /// Brief, single‑line summary of the error suitable for showing in a
  /// snackbar or dialog. Never contains a stack trace.
  String get summary {
    final code = statusCode;
    final base = error.toString();
    return code != null ? 'HTTP $code · $base' : base;
  }
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
