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

  /// Selected loop count persisted across sessions. 1 = play once.
  /// Higher values (3, 5, 10) enable memorization mode: the ayah
  /// repeats N times before stopping automatically.
  int _loopCount = 1;
  int _loopCurrent = 0;
  int _loopActiveTotal = 0;

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
      audioService.loopStream.listen((s) {
        if (!mounted) return;
        setState(() {
          _loopCurrent = s.current;
          _loopActiveTotal = s.total;
        });
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

          // Loop-count button — opens a quick menu to pick 1×/3×/5×/10×.
          // When a loop is in flight the icon shows "N/M" to give the
          // user an honest counter without another row of chrome.
          _LoopMenuButton(
            selected: _loopCount,
            activeCurrent: _loopCurrent,
            activeTotal: _loopActiveTotal,
            onChanged: (n) {
              setState(() => _loopCount = n);
              if (_isPlaying && n > 1) {
                // Picking a new count while already playing restarts
                // with the new loop target so the choice takes effect
                // immediately rather than on next tap of play.
                final messenger = ScaffoldMessenger.of(context);
                audioService.playAyahLooped(widget.audioUrl!, n)
                    .catchError((Object e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Audio failed: $e')),
                    );
                  }
                });
              }
            },
            color: theme.colorScheme.primary,
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
        if (_loopCount > 1) {
          await audioService.playAyahLooped(widget.audioUrl!, _loopCount);
        } else {
          await audioService.playAyah(widget.audioUrl!);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio failed: $e')),
          );
        }
      }
    }
  }
}

/// Button + popup menu for picking how many times the ayah loops.
/// Renders either a plain repeat icon (when not looping) or an active
/// iteration badge like "2/5" when a memorization session is running.
class _LoopMenuButton extends StatelessWidget {
  final int selected;
  final int activeCurrent;
  final int activeTotal;
  final ValueChanged<int> onChanged;
  final Color color;

  const _LoopMenuButton({
    required this.selected,
    required this.activeCurrent,
    required this.activeTotal,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isLooping = activeTotal > 1;
    final hasSelection = selected > 1;

    return PopupMenuButton<int>(
      tooltip: 'Memorization loop',
      initialValue: selected,
      onSelected: onChanged,
      position: PopupMenuPosition.over,
      offset: const Offset(0, -120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 1, child: Text('Play once')),
        PopupMenuItem(value: 3, child: Text('Repeat 3×')),
        PopupMenuItem(value: 5, child: Text('Repeat 5×')),
        PopupMenuItem(value: 10, child: Text('Repeat 10×')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: hasSelection
              ? color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLooping ? Icons.repeat_on_rounded : Icons.repeat_rounded,
              size: 18,
              color: color.withValues(alpha: hasSelection ? 0.9 : 0.6),
              semanticLabel: 'Memorization loop',
            ),
            if (isLooping) ...[
              const SizedBox(width: 4),
              Text(
                // `activeCurrent` is already the 1-indexed iteration
                // currently playing (see AudioService.loopStream).
                // Previously we rendered `activeCurrent + 1`, which
                // produced "2/5" on the very first iteration and the
                // infamous "6/5" on the final one.
                '$activeCurrent/$activeTotal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
            ] else if (hasSelection) ...[
              const SizedBox(width: 3),
              Text(
                '$selected×',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
