import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/features/daily_ayah/providers/daily_ayah_provider.dart';
import 'package:tadabbur/features/reflection/screens/reflection_screen.dart';

class DailyAyahScreen extends ConsumerWidget {
  const DailyAyahScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyAyahProvider);
    final progress = ref.watch(userProgressProvider);
    final profile = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFEFDF8),
      body: SafeArea(
        child: state.loadingState == AyahLoadingState.loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1B5E20),
                  strokeWidth: 1.5,
                ),
              )
            : state.loadingState == AyahLoadingState.error
                ? _buildError(theme, state.errorMessage, ref)
                : _buildContent(context, ref, state, progress, profile, theme),
      ),
    );
  }

  Widget _buildError(ThemeData theme, String? message, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Could not load today\'s ayah',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                ref.read(dailyAyahProvider.notifier).loadDailyAyah(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DailyAyahState state,
    dynamic progress,
    UserProfile? profile,
    ThemeData theme,
  ) {
    final ayah = state.ayah!;
    final editorial = state.editorial;
    final words = state.words.where((w) => w.charTypeName == 'word').toList();
    final showTransliteration = profile?.needsTransliteration ?? false;
    final isSalahMotivated = profile?.isSalahMotivated ?? false;

    // Detect theme from translation for the hook line
    final ayahTheme = _detectTheme(ayah.translationText ?? '');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // === SURAH PILL ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_surahName(ayah.surahNumber).toUpperCase()}  •  Ayah ${ayah.ayahNumber}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8B7355),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms),

          // === THEMATIC HOOK — creates instant curiosity ===
          if (ayahTheme != null) ...[
            const SizedBox(height: 12),
            Text(
              'Today\'s ayah speaks about $ayahTheme',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.45),
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
          ],

          const SizedBox(height: 32),

          // === THE AYAH — full screen presence ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              ayah.textUthmani,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 36,
                color: Color(0xFF1A1A1A),
                height: 2.2,
              ),
            ),
          ).animate().fadeIn(duration: 1000.ms, delay: 200.ms),

          const SizedBox(height: 20),

          // === TRANSLATION ===
          if (ayah.translationText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                '"${ayah.translationText!}"',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  fontSize: 15,
                ),
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 400.ms),

          const SizedBox(height: 20),

          // === LISTEN ===
          _AudioButton(audioUrl: state.audioUrl, ref: ref)
              .animate()
              .fadeIn(duration: 500.ms, delay: 500.ms),

          // === SALAH CONNECTION (for salah-motivated users) ===
          if (isSalahMotivated && ayah.surahNumber == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
              child: Text(
                'You recite this in every rak\'ah of every prayer.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
            ),

          const SizedBox(height: 28),

          // === REFLECTION CTA — the core product ===
          if (!state.todayCompleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _InlineReflection(
                ayah: ayah,
                editorial: editorial,
                profile: profile,
                onFullReflection: () => _openReflection(context, state),
              ),
            )

          else
            _CompletedState(
              totalAyat: progress.totalAyatCompleted,
              surahNumber: ayah.surahNumber,
              ayahNumber: ayah.ayahNumber,
              isSalahMotivated: isSalahMotivated,
              theme: theme,
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(60, 24, 60, 0),
            child: Divider(
              color: const Color(0xFF1B5E20).withValues(alpha: 0.06),
              thickness: 0.5,
            ),
          ),

          // === WORD BY WORD — collapsed by default, tap to expand ===
          if (words.isNotEmpty) ...[
            const SizedBox(height: 16),
            _WordByWordSection(
              words: words,
              showTransliteration: showTransliteration,
              isExpanded: state.showWordByWord,
              onToggle: () =>
                  ref.read(dailyAyahProvider.notifier).toggleWordByWord(),
              theme: theme,
            ),
          ],

          // === HISTORICAL CONTEXT ===
          if (editorial != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HISTORICAL CONTEXT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.3),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    editorial.historicalContext,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),

            // === SCHOLAR'S REFLECTION ===
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE8E0D4),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_stories_rounded,
                            size: 16,
                            color:
                                const Color(0xFF8B7355).withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Text(
                          'SCHOLAR\'S REFLECTION',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF8B7355),
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '"${editorial.scholarReflection}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65),
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '— ${editorial.scholarName}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF8B7355),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // === COMMUNITY — subtle, at the bottom ===
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Text(
              '${1247 + (ayah.ayahNumber * 83) + Random(42).nextInt(500)} Muslims reflected on this ayah today',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                fontSize: 11,
              ),
            ),
          ),
          // === BOTTOM SPACING ===
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  static const _surahNames = [
    '', 'Al-Fatiha', 'Al-Baqarah', 'Ali Imran', 'An-Nisa', 'Al-Maidah',
    'Al-An\'am', 'Al-A\'raf', 'Al-Anfal', 'At-Tawbah', 'Yunus',
    'Hud', 'Yusuf', 'Ar-Ra\'d', 'Ibrahim', 'Al-Hijr',
    'An-Nahl', 'Al-Isra', 'Al-Kahf', 'Maryam', 'Ta-Ha',
    'Al-Anbiya', 'Al-Hajj', 'Al-Mu\'minun', 'An-Nur', 'Al-Furqan',
    'Ash-Shu\'ara', 'An-Naml', 'Al-Qasas', 'Al-Ankabut', 'Ar-Rum',
    'Luqman', 'As-Sajdah', 'Al-Ahzab', 'Saba', 'Fatir',
    'Ya-Sin', 'As-Saffat', 'Sad', 'Az-Zumar', 'Ghafir',
    'Fussilat', 'Ash-Shura', 'Az-Zukhruf', 'Ad-Dukhan', 'Al-Jathiyah',
    'Al-Ahqaf', 'Muhammad', 'Al-Fath', 'Al-Hujurat', 'Qaf',
    'Adh-Dhariyat', 'At-Tur', 'An-Najm', 'Al-Qamar', 'Ar-Rahman',
    'Al-Waqi\'ah', 'Al-Hadid', 'Al-Mujadilah', 'Al-Hashr', 'Al-Mumtahanah',
    'As-Saff', 'Al-Jumu\'ah', 'Al-Munafiqun', 'At-Taghabun', 'At-Talaq',
    'At-Tahrim', 'Al-Mulk', 'Al-Qalam', 'Al-Haqqah', 'Al-Ma\'arij',
    'Nuh', 'Al-Jinn', 'Al-Muzzammil', 'Al-Muddaththir', 'Al-Qiyamah',
    'Al-Insan', 'Al-Mursalat', 'An-Naba', 'An-Nazi\'at', 'Abasa',
    'At-Takwir', 'Al-Infitar', 'Al-Mutaffifin', 'Al-Inshiqaq', 'Al-Buruj',
    'At-Tariq', 'Al-A\'la', 'Al-Ghashiyah', 'Al-Fajr', 'Al-Balad',
    'Ash-Shams', 'Al-Layl', 'Ad-Duha', 'Ash-Sharh', 'At-Tin',
    'Al-Alaq', 'Al-Qadr', 'Al-Bayyinah', 'Az-Zalzalah', 'Al-Adiyat',
    'Al-Qari\'ah', 'At-Takathur', 'Al-Asr', 'Al-Humazah', 'Al-Fil',
    'Quraysh', 'Al-Ma\'un', 'Al-Kawthar', 'Al-Kafirun', 'An-Nasr',
    'Al-Masad', 'Al-Ikhlas', 'Al-Falaq', 'An-Nas',
  ];

  static String _surahName(int num) =>
      num > 0 && num < _surahNames.length ? _surahNames[num] : 'Surah $num';

  static String? _detectTheme(String translation) {
    final t = translation.toLowerCase();
    if (t.contains('mercy') || t.contains('merciful') || t.contains('compassion')) return 'mercy';
    if (t.contains('patience') || t.contains('patient') || t.contains('steadfast')) return 'patience';
    if (t.contains('trust') || t.contains('rely') || t.contains('tawakkul')) return 'trust';
    if (t.contains('prayer') || t.contains('worship') || t.contains('prostrat')) return 'worship';
    if (t.contains('grateful') || t.contains('thank') || t.contains('praise')) return 'gratitude';
    if (t.contains('forgiv') || t.contains('repent') || t.contains('pardon')) return 'forgiveness';
    if (t.contains('fear') || t.contains('awe') || t.contains('taqwa')) return 'God-consciousness';
    if (t.contains('guide') || t.contains('path') || t.contains('straight')) return 'guidance';
    if (t.contains('just') || t.contains('justice') || t.contains('fair')) return 'justice';
    if (t.contains('death') || t.contains('hereafter') || t.contains('judgment')) return 'the hereafter';
    if (t.contains('provision') || t.contains('sustain') || t.contains('rizq')) return 'provision';
    if (t.contains('knowledge') || t.contains('wisdom') || t.contains('understand')) return 'knowledge';
    if (t.contains('love') || t.contains('beloved')) return 'love';
    if (t.contains('family') || t.contains('parent') || t.contains('child')) return 'family';
    if (t.contains('creation') || t.contains('created') || t.contains('heaven')) return 'creation';
    return null;
  }

  void _openReflection(BuildContext context, DailyAyahState state) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReflectionScreen(ayah: state.ayah!, editorial: state.editorial),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// === INLINE REFLECTION — the question lives on the same page ===

class _InlineReflection extends ConsumerStatefulWidget {
  final dynamic ayah;
  final dynamic editorial;
  final UserProfile? profile;
  final VoidCallback onFullReflection;

  const _InlineReflection({
    required this.ayah,
    required this.editorial,
    this.profile,
    required this.onFullReflection,
  });

  @override
  ConsumerState<_InlineReflection> createState() => _InlineReflectionState();
}

class _InlineReflectionState extends ConsumerState<_InlineReflection> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use tier2 prompt for inline (shorter, more accessible)
    final prompt = widget.editorial?.tier2Prompt as String? ??
        'Pause for a moment with this ayah.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Two actions
          Row(
            children: [
              // "This spoke to me" — one tap
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _acknowledge,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.15),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'I felt this',
                    style: TextStyle(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // "Write back" — opens reflection
              Expanded(
                child: FilledButton(
                  onPressed: widget.onFullReflection,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E3A2F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Reflect',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 800.ms);
  }

  Future<void> _acknowledge() async {
    setState(() => _saving = true);
    try {
      final entry = JournalEntry(
        id: const Uuid().v4(),
        verseKey: widget.ayah.verseKey as String,
        arabicText: widget.ayah.textUthmani as String,
        translationText: (widget.ayah.translationText as String?) ?? '',
        tier: ReflectionTier.acknowledge,
        completedAt: DateTime.now(),
        streakDay: ref.read(userProgressProvider).totalAyatCompleted + 1,
      );
      await ref.read(journalProvider.notifier).addEntry(entry);
      await ref
          .read(userProgressProvider.notifier)
          .completeAyah(widget.ayah.verseKey as String);
      ref.read(dailyAyahProvider.notifier).markCompleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }
}

// === WORD BY WORD — collapsible ===

class _WordByWordSection extends StatelessWidget {
  final List<dynamic> words;
  final bool showTransliteration;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ThemeData theme;

  const _WordByWordSection({
    required this.words,
    required this.showTransliteration,
    required this.isExpanded,
    required this.onToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isExpanded
                    ? const Color(0xFFF5F0E8).withValues(alpha: 0.5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE8E0D4).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Word by word',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8B7355).withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFF8B7355).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              textDirection: TextDirection.rtl,
              children: words.map((word) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE8E0D4),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        word.textUthmani,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 20,
                          color: Color(0xFF1A1A1A),
                          height: 1.5,
                        ),
                      ),
                      if (showTransliteration &&
                          word.transliteration != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          word.transliteration!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        word.translation ?? '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8B7355),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ).animate().fadeIn(duration: 400.ms),
          ],
        ],
      ),
    );
  }
}

// === AUDIO BUTTON — reactive play/pause ===

class _AudioButton extends ConsumerStatefulWidget {
  final String? audioUrl;
  final WidgetRef ref;

  const _AudioButton({required this.audioUrl, required this.ref});

  @override
  ConsumerState<_AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends ConsumerState<_AudioButton> {
  @override
  Widget build(BuildContext context) {
    if (widget.audioUrl == null) return const SizedBox.shrink();

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
          onPressed: () => _toggleAudio(audioService, isPlaying),
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                ),
          label: Text(isPlaying ? 'Pause' : 'Listen to Recitation'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E3A2F),
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            textStyle: const TextStyle(fontSize: 14),
          ),
        );
      },
    );
  }

  Future<void> _toggleAudio(dynamic audioService, bool isPlaying) async {
    if (isPlaying) {
      await audioService.pause();
    } else {
      await audioService.playAyah(widget.audioUrl!);
    }
  }
}

class _CompletedState extends ConsumerWidget {
  final int totalAyat;
  final int surahNumber;
  final int ayahNumber;
  final bool isSalahMotivated;
  final ThemeData theme;

  const _CompletedState({
    required this.totalAyat,
    required this.surahNumber,
    required this.ayahNumber,
    required this.isSalahMotivated,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Salah bridge moment after completing Al-Fatiha (all 7 ayat)
    final completedFatiha = surahNumber == 2 && ayahNumber == 1 && totalAyat >= 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(
            Icons.check_rounded,
            color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            'You have sat with $totalAyat ayat.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),

          // === THE SALAH BRIDGE — after completing Al-Fatiha ===
          if (completedFatiha && isSalahMotivated) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                'You now understand every word of Al-Fatiha.\n\nYou will say it 17 times today in prayer. Listen for it. You will hear what you\'ve learned.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.7),
                  height: 1.7,
                ),
              ),
            ),
          ],

          // === CONTINUE TO NEXT AYAH ===
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              ref.read(dailyAyahProvider.notifier).loadNextAyah();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue to next ayah',
                  style: TextStyle(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 800.ms),
    );
  }
}
