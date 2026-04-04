import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/arabic_fonts.dart';
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
    final arabicFontSize = ref.watch(arabicFontSizeProvider);
    final arabicFontId = ref.watch(arabicFontProvider);
    final reciterPath = ref.watch(reciterPathProvider);

    // Build audio URL from Islamic Network CDN (uses absolute ayah number)
    final absAyahNum = _absoluteAyahNumber(ayah.surahNumber, ayah.ayahNumber);
    final bitrate = reciterPath == 'abdurrahmaansudais' ? '192' : '128';
    final liveAudioUrl =
        'https://cdn.islamic.network/quran/audio/$bitrate/ar.$reciterPath/$absAyahNum.mp3';

    // Detect theme from translation for the hook line
    final ayahTheme = _detectTheme(ayah.translationText ?? '');

    // Check if returning after a gap (no guilt, just welcome back)
    final lastCompleted = progress.lastCompletedAt as DateTime?;
    final daysSinceLastVisit = lastCompleted != null
        ? DateTime.now().difference(lastCompleted).inDays
        : 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // === QUIET DAY COUNTER ===
          if (progress.totalAyatCompleted > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Day ${progress.totalAyatCompleted + (state.todayCompleted ? 0 : 1)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    fontSize: 11,
                  ),
                ),
              ),
            ),

          // === WELCOME BACK (after gap, no guilt) ===
          if (daysSinceLastVisit >= 3 && progress.totalAyatCompleted > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
              child: Text(
                'Welcome back. Pick up where you left off.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(duration: 800.ms),
            ),

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
              'Today\'s ayah invites you to reflect on $ayahTheme',
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
              style: ArabicFonts.getStyle(arabicFontId, fontSize: arabicFontSize)
                  .copyWith(color: const Color(0xFF1A1A1A)),
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

          // === LISTEN — prominent, nudge above ===
          Column(
            children: [
              Text(
                'Start by listening',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              _AudioButton(audioUrl: liveAudioUrl, ref: ref),
            ],
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

          // === SALAH CONNECTION ===
          if (isSalahMotivated && ayah.surahNumber == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
              child: Text(
                'You recite this in every rak\'ah of every prayer.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),

          // === SHORT MEANING — 2 lines, between audio and reflection ===
          if (editorial != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
              child: Text(
                _shortMeaning(editorial.historicalContext),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

          const SizedBox(height: 24),

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

  /// Extract first 1-2 sentences as a short meaning.
  static String _shortMeaning(String context) {
    final sentences = context.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length <= 1) return context;
    return sentences.take(2).join(' ');
  }

  /// Convert surah:ayah to absolute ayah number (1-6236).
  static int _absoluteAyahNumber(int surah, int ayah) {
    const verseCounts = [
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
    int total = 0;
    for (int i = 1; i < surah && i < verseCounts.length; i++) {
      total += verseCounts[i];
    }
    return total + ayah;
  }

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
  bool _highlighted = false;

  @override
  void initState() {
    super.initState();
    // Auto-highlight "I felt this" after 5 seconds of inactivity
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_saving) {
        setState(() => _highlighted = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journal = ref.watch(journalProvider);
    final prompt = widget.editorial?.tier2Prompt as String? ??
        'Sit with this for a moment.';

    // Show a previous entry after Day 3 to build attachment
    final previousEntry = journal.length >= 3 ? journal.last : null;

    return Column(
      children: [
        // === PREVIOUS ENTRY MEMORY (after Day 3) ===
        if (previousEntry != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE8E0D4).withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'You wrote this ${_daysAgo(previousEntry.completedAt)}...',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF8B7355).withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  previousEntry.responseText ?? 'You felt this ayah.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
        ],

        // === REFLECTION CTA ===
        Container(
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
              Row(
                children: [
                  // "I felt this" — highlighted after 5s
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _highlighted
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1B5E20)
                                      .withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: FilledButton(
                        onPressed: _saving ? null : _acknowledge,
                        style: FilledButton.styleFrom(
                          backgroundColor: _highlighted
                              ? const Color(0xFF1B5E20)
                              : Colors.white,
                          foregroundColor: _highlighted
                              ? Colors.white
                              : const Color(0xFF1B5E20).withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: _highlighted
                              ? null
                              : BorderSide(
                                  color: const Color(0xFF1B5E20)
                                      .withValues(alpha: 0.15),
                                ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'I felt this',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onFullReflection,
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
                        'Write one line',
                        style: TextStyle(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
      ],
    );
  }

  String _daysAgo(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'earlier today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
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
      // Haptic feedback — the moment lands
      HapticFeedback.mediumImpact();

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

// === TRUNCATED SCHOLAR TEXT — 2-3 sentences with "Read more" ===

class _TruncatedScholarText extends StatefulWidget {
  final String text;
  final String scholarName;
  final ThemeData theme;

  const _TruncatedScholarText({
    required this.text,
    required this.scholarName,
    required this.theme,
  });

  @override
  State<_TruncatedScholarText> createState() => _TruncatedScholarTextState();
}

class _TruncatedScholarTextState extends State<_TruncatedScholarText> {
  bool _expanded = false;

  String get _shortText {
    // Take first 2 sentences
    final sentences = widget.text.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length <= 2) return '"${widget.text}"';
    return '"${sentences.take(2).join(' ')}..."';
  }

  bool get _isLong {
    return widget.text.split(RegExp(r'(?<=[.!?])\s+')).length > 2;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _expanded ? '"${widget.text}"' : _shortText,
          style: widget.theme.textTheme.bodyMedium?.copyWith(
            color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.65),
            height: 1.7,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (_isLong && !_expanded) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Text(
              'Read more',
              style: widget.theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8B7355).withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
    final completedFatiha = surahNumber == 2 && ayahNumber == 1 && totalAyat >= 7;
    final milestone = _getMilestoneMessage(totalAyat);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Checkmark with scale animation
          Icon(
            Icons.check_rounded,
            color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
            size: 32,
          )
              .animate()
              .scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),

          const SizedBox(height: 14),

          // === "Day X complete" ===
          Text(
            'Day $totalAyat complete',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF1B5E20),
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

          const SizedBox(height: 6),

          // === Warm emotional line ===
          Text(
            milestone ?? 'You showed up today. This counts.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

          // === Tomorrow anticipation ===
          const SizedBox(height: 16),
          Text(
            'Come back tomorrow for your next ayah.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              fontSize: 12,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

          // === SALAH BRIDGE — after completing Al-Fatiha ===
          if (completedFatiha && isSalahMotivated) ...[
            const SizedBox(height: 20),
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
                'You now understand every word of Al-Fatiha.\n\nYou will say it 17 times today in prayer. Listen for it.',
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

  static String? _getMilestoneMessage(int total) {
    if (total == 1) return 'Your first ayah. This is the beginning.';
    if (total == 3) return 'Day 3. You\'re building something.';
    if (total == 7) return 'One week. 7 ayat. You\'ve built something real.';
    if (total == 14) return 'Two weeks. This is becoming part of you.';
    if (total == 30) return 'Day 30. This is a habit now.';
    if (total == 50) return '50 ayat. Your journal is growing.';
    if (total == 100) return '100 ayat. You have built something no one can take from you.';
    if (total == 365) return 'One year. 365 ayat. Your spiritual autobiography.';
    return null;
  }
}
