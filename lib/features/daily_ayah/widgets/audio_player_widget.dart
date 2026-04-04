import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tadabbur/core/providers/app_providers.dart';

class AudioPlayerWidget extends ConsumerStatefulWidget {
  final String? audioUrl;

  const AudioPlayerWidget({super.key, this.audioUrl});

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final audioService = ref.watch(audioServiceProvider);
    final theme = Theme.of(context);

    if (widget.audioUrl == null) return const SizedBox.shrink();

    return StreamBuilder<PlayerState>(
      stream: audioService.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = playerState?.playing ?? false;
        final processingState = playerState?.processingState;

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
              _isLoading || processingState == ProcessingState.loading
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
                      onPressed: () => _togglePlayback(audioService, isPlaying),
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 28,
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
                child: StreamBuilder<Duration>(
                  stream: audioService.positionStream,
                  builder: (context, posSnap) {
                    return StreamBuilder<Duration?>(
                      stream: audioService.durationStream,
                      builder: (context, durSnap) {
                        final position = posSnap.data ?? Duration.zero;
                        final duration =
                            durSnap.data ?? const Duration(seconds: 1);
                        final progress = duration.inMilliseconds > 0
                            ? position.inMilliseconds /
                                duration.inMilliseconds
                            : 0.0;

                        return SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                            activeTrackColor: theme.colorScheme.primary,
                            inactiveTrackColor: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            thumbColor: theme.colorScheme.primary,
                          ),
                          child: Slider(
                            value: progress.clamp(0.0, 1.0),
                            onChanged: (value) {
                              final newPosition = Duration(
                                milliseconds:
                                    (value * duration.inMilliseconds).round(),
                              );
                              audioService.seek(newPosition);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Repeat button
              IconButton(
                onPressed: () => _replay(audioService),
                icon: const Icon(Icons.replay_rounded, size: 22),
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
      },
    );
  }

  Future<void> _togglePlayback(dynamic audioService, bool isPlaying) async {
    if (isPlaying) {
      await audioService.pause();
    } else {
      setState(() => _isLoading = true);
      try {
        await audioService.playAyah(widget.audioUrl!);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _replay(dynamic audioService) async {
    await audioService.seek(Duration.zero);
    setState(() => _isLoading = true);
    try {
      await audioService.playAyah(widget.audioUrl!);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
