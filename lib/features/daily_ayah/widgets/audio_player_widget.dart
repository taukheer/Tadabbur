import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/audio_service.dart';

class AudioPlayerWidget extends ConsumerStatefulWidget {
  final String? audioUrl;

  const AudioPlayerWidget({super.key, this.audioUrl});

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  /// Local snapshot of audio state, updated by stream subscriptions in
  /// [initState]. Replaces the previous three-level-deep StreamBuilder
  /// nest, which rebuilt the entire row on every position tick.
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 1);

  late final List<StreamSubscription<dynamic>> _subs;

  @override
  void initState() {
    super.initState();
    final audioService = ref.read(audioServiceProvider);
    _subs = [
      audioService.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          // Treat just-audio's transient loading/buffering states as
          // "loading" so the spinner shows for slow CDN fetches.
          _isLoading = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
        });
      }),
      audioService.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      }),
      audioService.durationStream.listen((d) {
        if (!mounted || d == null) return;
        setState(() => _duration = d);
      }),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioUrl == null) return const SizedBox.shrink();

    final audioService = ref.read(audioServiceProvider);
    final theme = Theme.of(context);
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          _isLoading
              ? SizedBox(
                  width: 40,
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: () => _togglePlayback(audioService),
                  tooltip: _isPlaying
                      ? 'Pause recitation'
                      : 'Play recitation',
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 28,
                    semanticLabel: _isPlaying
                        ? 'Pause recitation'
                        : 'Play recitation',
                  ),
                  color: theme.colorScheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),

          // Progress bar
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                thumbColor: theme.colorScheme.primary,
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  final newPosition = Duration(
                    milliseconds:
                        (value * _duration.inMilliseconds).round(),
                  );
                  audioService.seek(newPosition);
                },
              ),
            ),
          ),

          // Repeat button
          IconButton(
            onPressed: () => _replay(audioService),
            tooltip: 'Replay recitation',
            icon: const Icon(Icons.replay_rounded,
                size: 22, semanticLabel: 'Replay recitation'),
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlayback(AudioService audioService) async {
    if (_isPlaying) {
      await audioService.pause();
    } else {
      try {
        await audioService.playAyah(widget.audioUrl!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _replay(AudioService audioService) async {
    await audioService.seek(Duration.zero);
    try {
      await audioService.playAyah(widget.audioUrl!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio failed: $e')),
        );
      }
    }
  }
}
