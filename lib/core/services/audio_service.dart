import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Bitrates by reciter slug for the cdn.islamic.network ayah endpoint,
/// which we use as the audio fallback when the QF recitations endpoint
/// is unavailable. Most reciters are at 128 kbps; Sudais is encoded at
/// 192 only — the override map keeps the fallback URL builder a single
/// expression.
const Map<String, String> _islamicNetworkBitrateByReciter = {
  'abdurrahmaansudais': '192',
};
const String _islamicNetworkDefaultBitrate = '128';

/// Builds a per-ayah audio URL on cdn.islamic.network for the given
/// reciter slug and absolute ayah number (1..6236). Used as the fallback
/// path when the Quran Foundation recitations endpoint returns no files
/// (which it does for unauthenticated public callers as of May 2026).
String islamicNetworkAyahUrl(String reciterPath, int absAyahNum) {
  final bitrate = _islamicNetworkBitrateByReciter[reciterPath] ??
      _islamicNetworkDefaultBitrate;
  return 'https://cdn.islamic.network/quran/audio/$bitrate/ar.$reciterPath/$absAyahNum.mp3';
}

/// Surah verse counts (index 1..114). Used to translate a `surah:ayah`
/// pair to the absolute ayah number that cdn.islamic.network expects.
const List<int> _surahVerseCounts = [
  0, 7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
  5, 4, 5, 6,
];

/// Convert a `verseKey` ("65:7") to the absolute ayah number 1..6236.
/// Returns null for malformed keys or out-of-range surahs.
int? absoluteAyahFromVerseKey(String verseKey) {
  final parts = verseKey.split(':');
  if (parts.length != 2) return null;
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  if (surah == null || ayah == null) return null;
  if (surah < 1 || surah >= _surahVerseCounts.length) return null;
  int total = 0;
  for (int i = 1; i < surah; i++) {
    total += _surahVerseCounts[i];
  }
  return total + ayah;
}

/// Service that wraps [AudioPlayer] for Quran audio playback.
///
/// Provides a simplified interface for playing individual ayah audio files,
/// with reactive streams for UI binding and proper resource cleanup.
class AudioService {
  final AudioPlayer _player;
  StreamSubscription<ProcessingState>? _completionSub;

  /// Remaining loop iterations after the current one. Decremented each
  /// time the audio completes. When it hits zero the player falls back
  /// to the default pause + rewind behaviour. The "memorization loop"
  /// feature on the UI sets this via [playAyahLooped].
  int _loopRemaining = 0;
  int _loopTotal = 0;

  /// True while a play/reset call is rewriting the loop counters. Any
  /// completion event that fires during this window is discarded — the
  /// handler would otherwise decrement the freshly-assigned
  /// `_loopRemaining` belonging to a brand-new session, making the UI
  /// show e.g. "2/10" on iteration 1 of a loop the user just started.
  bool _suspendCompletion = false;

  /// Emits `(current, total)` where `current` is the **1-indexed
  /// iteration currently playing** (so UIs can render `"$current/$total"`
  /// directly, no `+1`). When not looping the stream emits `(0, 0)` so
  /// the loop counter can hide cleanly. When the loop finishes, the
  /// final emit is also `(0, 0)` — there is never an emit with
  /// `current > total`.
  final StreamController<({int current, int total})> _loopCtrl =
      StreamController<({int current, int total})>.broadcast();
  Stream<({int current, int total})> get loopStream => _loopCtrl.stream;

  /// Creates an [AudioService].
  ///
  /// An optional [player] can be injected for testing; otherwise a new
  /// [AudioPlayer] instance is created.
  AudioService({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    // When a track finishes: if a memorization loop is active, restart
    // from zero and decrement the remaining count. Otherwise reset the
    // player (pause + seek to start) so listeners see `playing == false`
    // and the play icon flips back automatically.
    _completionSub = _player.processingStateStream
        .where((s) => s == ProcessingState.completed)
        .listen((_) async {
      // Drop this completion if a newer session is being configured —
      // see `_suspendCompletion` for the race it closes.
      if (_suspendCompletion) return;
      try {
        if (_loopRemaining > 0) {
          _loopRemaining--;
          _emitLoopState();
          await _player.seek(Duration.zero);
          await _player.play();
          return;
        }
        _loopTotal = 0;
        _emitLoopState();
        await _player.pause();
        await _player.seek(Duration.zero);
      } catch (_) {
        // Best-effort reset; ignore if the player was disposed mid-flight.
      }
    });
  }

  void _emitLoopState() {
    final completed = _loopTotal - _loopRemaining;
    _loopCtrl.add((current: completed, total: _loopTotal));
  }

  /// Current loop iteration index (0 when not looping) — how many times
  /// the track has completed so far in the active loop.
  int get loopCurrent => _loopTotal - _loopRemaining;

  /// Total iterations the current loop is configured for. Zero means
  /// not looping.
  int get loopTotal => _loopTotal;

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Stream of player state changes (playing, paused, completed, etc.).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of the current playback position.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of the total duration of the current audio.
  ///
  /// Emits `null` if no audio is loaded or the duration is unknown.
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of buffered position for showing download progress.
  Stream<Duration> get bufferedPositionStream =>
      _player.bufferedPositionStream;

  // ---------------------------------------------------------------------------
  // Synchronous state
  // ---------------------------------------------------------------------------

  /// Whether audio is currently playing.
  bool get isPlaying => _player.playing;

  /// The current playback position.
  Duration get position => _player.position;

  /// The total duration of the loaded audio, or `null` if unknown.
  Duration? get duration => _player.duration;

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  /// Loads and plays an ayah audio file from the given [audioUrl].
  ///
  /// If audio is already playing, it is stopped first before loading
  /// the new source. Throws an [AudioServiceException] if the audio
  /// cannot be loaded or load takes longer than [loadTimeout]
  /// (default 30 seconds).
  Future<void> playAyah(
    String audioUrl, {
    Duration loadTimeout = const Duration(seconds: 30),
  }) async {
    _suspendCompletion = true;
    try {
      _resetLoop();
      await _play(audioUrl, loadTimeout: loadTimeout);
    } finally {
      _suspendCompletion = false;
    }
  }

  /// Plays an ayah and repeats it [count] times total.
  ///
  /// Used by the memorization loop mode. A count of 1 plays once with
  /// no repeats (equivalent to [playAyah]); higher counts cause the
  /// completion handler to seek to zero and play again automatically.
  /// The current loop state is broadcast on [loopStream] so the UI can
  /// render a "2 of 5" counter.
  Future<void> playAyahLooped(
    String audioUrl,
    int count, {
    Duration loadTimeout = const Duration(seconds: 30),
  }) async {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'must be >= 1');
    }
    // Suspend completion handling across the whole reconfiguration
    // so an in-flight completion event from the previous session
    // can't clobber the counters we're about to write.
    _suspendCompletion = true;
    try {
      _loopTotal = count;
      _loopRemaining = count - 1;
      _emitLoopState();
      await _play(audioUrl, loadTimeout: loadTimeout);
    } finally {
      _suspendCompletion = false;
    }
  }

  Future<void> _play(
    String audioUrl, {
    required Duration loadTimeout,
  }) async {
    try {
      await _player.stop();
      await _player.setUrl(audioUrl).timeout(
            loadTimeout,
            onTimeout: () => throw AudioServiceException(
              message: 'Audio load timed out after ${loadTimeout.inSeconds}s',
            ),
          );
      _player.play(); // Don't await — returns immediately so UI can update
    } on AudioServiceException {
      rethrow;
    } on PlayerException catch (e) {
      throw AudioServiceException(
        message: 'Failed to play audio: ${e.message}',
        code: e.code,
      );
    } on PlayerInterruptedException {
      // Playback was interrupted (e.g. by loading a new source). This is
      // expected behavior when rapidly switching verses.
    } catch (e) {
      throw AudioServiceException(
        message: 'Unexpected audio error: $e',
      );
    }
  }

  void _resetLoop() {
    if (_loopTotal == 0 && _loopRemaining == 0) return;
    _loopTotal = 0;
    _loopRemaining = 0;
    _emitLoopState();
  }

  /// Pauses the current playback and cancels any active loop.
  ///
  /// No-op if nothing is playing.
  Future<void> pause() async {
    try {
      _resetLoop();
      await _player.pause();
    } catch (e) {
      throw AudioServiceException(message: 'Failed to pause: $e');
    }
  }

  /// Resumes playback from the current position.
  ///
  /// No-op if already playing.
  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      throw AudioServiceException(message: 'Failed to resume: $e');
    }
  }

  /// Stops playback and resets the position to the beginning.
  Future<void> stop() async {
    try {
      _resetLoop();
      await _player.stop();
    } catch (e) {
      throw AudioServiceException(message: 'Failed to stop: $e');
    }
  }

  /// Seeks to the given [position] within the current audio.
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      throw AudioServiceException(message: 'Failed to seek: $e');
    }
  }

  /// Sets the playback speed (1.0 = normal).
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
    } catch (e) {
      throw AudioServiceException(message: 'Failed to set speed: $e');
    }
  }

  /// Releases resources held by the audio player.
  ///
  /// Call this when the service is no longer needed (e.g. when the
  /// parent widget or provider is disposed).
  void dispose() {
    _completionSub?.cancel();
    _loopCtrl.close();
    _player.dispose();
  }
}

/// Exception thrown by [AudioService] when an audio operation fails.
class AudioServiceException implements Exception {
  final String message;
  final int? code;

  const AudioServiceException({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'AudioServiceException($code): $message';
}
