import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tadabbur/core/constants/feelings.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/core/theme/arabic_fonts.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/services/audio_service.dart';

class FeelingsScreen extends ConsumerStatefulWidget {
  const FeelingsScreen({super.key});

  @override
  ConsumerState<FeelingsScreen> createState() => _FeelingsScreenState();
}

class _FeelingsScreenState extends ConsumerState<FeelingsScreen> {
  FeelingAyah? _selected;
  Ayah? _ayah;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8),
          // Close button sits in a soft circular hit-target so it
          // reads as a deliberate surface rather than floating
          // punctuation. 40×40 is the minimum tap-target recommended
          // by Material; 44×44 is iOS's — splitting the difference.
          child: Material(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _ayah != null
            ? _buildAyahView(theme, t, lang)
            : _buildFeelingPicker(theme, t),
      ),
    );
  }

  Widget _buildFeelingPicker(ThemeData theme, String Function(String) t) {
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    // Soft bottom fade signals scrollability without a hard edge. The
    // last partially-visible card now looks intentionally fading into
    // more content, not clipped off.
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          surface,
          surface,
          surface.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.93, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 56),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
            child: Text(
              // "How are you feeling?" was a form-prompt; "What are you
              // carrying?" meets the user at the weight they're
              // bringing, which for a Muslim opening this screen is
              // the whole point — we carry our states *to* Allah.
              t('what_carrying'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(duration: 700.ms),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
            child: Text(
              t('feeling_subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ).animate().fadeIn(duration: 700.ms, delay: 200.ms),
          ),
          const SizedBox(height: 32),
          for (var i = 0; i < Feelings.all.length; i++)
            _FeelingRow(
              feeling: Feelings.all[i],
              selected: _selected?.id == Feelings.all[i].id,
              isDark: isDark,
              onTap:
                  _loading ? null : () => _selectFeeling(Feelings.all[i]),
              label: t(Feelings.all[i].labelKey),
              index: i,
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAyahView(ThemeData theme, String Function(String) t, String lang) {
    final arabicFontId = ref.watch(arabicFontProvider);
    final arabicFontSize = ref.watch(arabicFontSizeProvider);
    final reciterPath = ref.watch(reciterPathProvider);

    // Build audio URL
    final absAyahNum = _absoluteAyahNumber(
      int.parse(_ayah!.verseKey.split(':').first),
      int.parse(_ayah!.verseKey.split(':').last),
    );
    final audioUrl = islamicNetworkAyahUrl(reciterPath, absAyahNum);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Feeling label — no emoji. A small color bar matching the
          // feeling's accent reads as "this was your state; here is
          // what the Qur'an has for you now" without caricature.
          _FeelingResultChip(feeling: _selected!, label: t(_selected!.labelKey)),

          const SizedBox(height: 32),

          // Arabic
          Text(
            _ayah!.textUthmani,
            locale: const Locale('ar'),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: ArabicFonts.getStyle(arabicFontId, fontSize: arabicFontSize)
                .copyWith(color: AppColors.textPrimaryLight),
          ).animate().fadeIn(duration: 800.ms),

          const SizedBox(height: 20),

          // Translation
          if (_ayah!.translationText != null)
            Text(
              '"${_ayah!.translationText!}"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                height: 1.6,
                fontSize: 15,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

          const SizedBox(height: 24),

          // Listen — reactive play/pause
          _FeelingAudioButton(audioUrl: audioUrl, lang: lang)
              .animate().fadeIn(duration: 500.ms, delay: 400.ms),

          // Why this ayah?
          const SizedBox(height: 20),
          Text(
            t(_selected!.contextKey),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

          const SizedBox(height: 28),

          // I felt this
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(t('i_felt_this')),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

          const SizedBox(height: 12),

          // Show another ayah
          TextButton(
            onPressed: () => _selectFeeling(_selected!),
            child: Text(
              t('try_another'),
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Take a moment for dua
          Text(
            t('make_dua'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.warmBrown.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _selectFeeling(FeelingAyah feeling) async {
    setState(() {
      _selected = feeling;
      _loading = true;
    });

    try {
      final quranApi = ref.read(quranApiProvider);
      final storage = ref.read(localStorageProvider);
      final translationId =
          AppLanguages.getByCode(storage.language).translationId.toString();
      final ayah = await quranApi.getVerseByKey(
        feeling.randomVerseKey,
        translationId: translationId,
      );
      if (mounted) {
        setState(() {
          _ayah = ayah;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int _absoluteAyahNumber(int surah, int ayah) {
    const vc = [0,7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,98,135,112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,75,85,54,53,89,59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,13,14,11,11,18,12,12,30,52,52,44,28,28,20,56,40,31,50,40,46,42,29,19,36,25,22,17,19,26,30,20,15,21,11,8,8,19,5,8,8,11,11,8,3,9,5,4,7,3,6,3,5,4,5,6];
    int total = 0;
    for (int i = 1; i < surah && i < vc.length; i++) {
      total += vc[i];
    }
    return total + ayah;
  }
}

/// Reactive audio button — same play/pause behavior as daily ayah screen
class _FeelingAudioButton extends ConsumerWidget {
  final String audioUrl;
  final String lang;

  const _FeelingAudioButton({required this.audioUrl, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.read(audioServiceProvider);

    return StreamBuilder<PlayerState>(
      stream: audioService.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = playerState?.playing ?? false;
        final isLoading =
            playerState?.processingState == ProcessingState.loading ||
            playerState?.processingState == ProcessingState.buffering;

        return FilledButton.icon(
          onPressed: () async {
            if (isPlaying) {
              await audioService.pause();
            } else {
              await audioService.playAyah(audioUrl);
            }
          },
          icon: isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white,
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20,
                ),
          label: Text(isPlaying
              ? AppTranslations.get('pause', lang)
              : AppTranslations.get('listen', lang)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryDarkButton,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        );
      },
    );
  }
}


/// Visual catalog per feeling — maps each id to a muted color accent
/// and a line-art glyph. Replaces the stock emoji with
/// typography-and-color-driven design so a Muslim opening the screen
/// in distress isn't met with a cartoon crying face.
///
/// Palette is intentionally muted — reflective/sacred tones, not
/// Instagram-loud. Glyphs are Material outline icons chosen for
/// metaphor (crescent-night for heaviness, wind for fear, etc.),
/// rendered at ~18px so they read as punctuation, not decoration.
class _FeelingVisual {
  final Color accent;
  final IconData icon;
  final String subtitle;

  const _FeelingVisual({
    required this.accent,
    required this.icon,
    required this.subtitle,
  });

  // All icons use the Material Rounded family for a single,
  // consistent visual weight — previously a mix of outlined/rounded/
  // filled variants made the picker feel assembled rather than
  // designed. Rounded is soft enough to feel emotional without being
  // childish.
  static const _map = {
    'low': _FeelingVisual(
      accent: Color(0xFF3C4563),
      icon: Icons.nights_stay_rounded,
      subtitle: 'When something weighs on you',
    ),
    'anxious': _FeelingVisual(
      accent: Color(0xFF5C7082),
      icon: Icons.air_rounded,
      subtitle: "When the mind won't settle",
    ),
    'angry': _FeelingVisual(
      accent: Color(0xFF8B4543),
      icon: Icons.local_fire_department_rounded,
      subtitle: "When there's fire in your chest",
    ),
    'grateful': _FeelingVisual(
      accent: AppColors.accent,
      icon: Icons.auto_awesome_rounded,
      subtitle: "When you want to say thank you",
    ),
    'confused': _FeelingVisual(
      accent: Color(0xFF6B8474),
      icon: Icons.blur_on_rounded,
      subtitle: "When you can't find the edges",
    ),
    'lonely': _FeelingVisual(
      accent: Color(0xFF6B557A),
      icon: Icons.waves_rounded,
      subtitle: "When no one else is there",
    ),
    'hopeful': _FeelingVisual(
      accent: Color(0xFFB07C6E),
      icon: Icons.wb_twilight_rounded,
      subtitle: "When something is beginning",
    ),
    'lost': _FeelingVisual(
      accent: AppColors.primary,
      icon: Icons.explore_rounded,
      subtitle: "When you need a direction",
    ),
    'exploring': _FeelingVisual(
      accent: Color(0xFF7A7466),
      icon: Icons.auto_stories_rounded,
      subtitle: "Just sitting with the Quran",
    ),
  };

  static _FeelingVisual forId(String id) =>
      _map[id] ??
      const _FeelingVisual(
        accent: AppColors.primary,
        icon: Icons.circle_rounded,
        subtitle: '',
      );
}

/// A single row in the "what are you carrying" picker. Full-width
/// tap target, a 3-pixel left accent bar in the feeling's color, a
/// calm line-art glyph, the state as a single word in typographic
/// weight, and a short italic framing underneath. No emoji, no
/// caricature — just room for the user to recognize themselves.
class _FeelingRow extends StatelessWidget {
  final FeelingAyah feeling;
  final bool selected;
  final bool isDark;
  final VoidCallback? onTap;
  final String label;
  final int index;

  const _FeelingRow({
    required this.feeling,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.label,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _FeelingVisual.forId(feeling.id);
    final accent = visual.accent;
    final baseSurface = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.08)
                  : baseSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.4)
                    : theme.colorScheme.outline.withValues(alpha: 0.08),
                width: 0.8,
              ),
              // Very subtle lift — the card was disappearing into the
              // cream background without this. 2% black at 6px blur
              // reads as "intentional surface" not "Material card."
              boxShadow: selected
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Accent bar — the feeling's color, always present.
                  // 3px of hue is enough to make the row feel intentional
                  // without loudness.
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 16, 0, 16),
                    // Tinted circle badge behind the icon. Gives every
                    // glyph the same visual weight regardless of how
                    // dense the underlying icon is (a moon and a
                    // compass otherwise read at very different sizes).
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        visual.icon,
                        size: 20,
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (visual.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              visual.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 500.ms,
          delay: (80 * index).ms,
        );
  }
}

/// Slim chip shown above the ayah result, replacing the old
/// "[emoji] Feeling low" prefix chip. Uses the feeling's accent
/// color as a small dot so the color continuity from picker → result
/// is readable without cartoon.
class _FeelingResultChip extends StatelessWidget {
  final FeelingAyah feeling;
  final String label;

  const _FeelingResultChip({required this.feeling, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _FeelingVisual.forId(feeling.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: visual.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: visual.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: visual.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
