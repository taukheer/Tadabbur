import 'package:just_audio/just_audio.dart';

/// Service that wraps [AudioPlayer] for Quran audio playback.
///
/// Provides a simplified interface for playing individual ayah audio files,
/// with reactive streams for UI binding and proper resource cleanup.
class AudioService {
  final AudioPlayer _player;

  /// Creates an [AudioService].
  ///
  /// An optional [player] can be injected for testing; otherwise a new
  /// [AudioPlayer] instance is created.
  AudioService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

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

  /// Pauses the current playback.
  ///
  /// No-op if nothing is playing.
  Future<void> pause() async {
    try {
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
