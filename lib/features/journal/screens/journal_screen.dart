import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';

/// All 114 surah names for display.
const _surahNames = [
  '', 'Al-Fatiha', 'Al-Baqarah', 'Ali Imran', 'An-Nisa', 'Al-Maidah',
  "Al-An'am", "Al-A'raf", 'Al-Anfal', 'At-Tawbah', 'Yunus',
  'Hud', 'Yusuf', "Ar-Ra'd", 'Ibrahim', 'Al-Hijr',
  'An-Nahl', 'Al-Isra', 'Al-Kahf', 'Maryam', 'Ta-Ha',
  'Al-Anbiya', 'Al-Hajj', "Al-Mu'minun", 'An-Nur', 'Al-Furqan',
  "Ash-Shu'ara", 'An-Naml', 'Al-Qasas', 'Al-Ankabut', 'Ar-Rum',
  'Luqman', 'As-Sajdah', 'Al-Ahzab', 'Saba', 'Fatir',
  'Ya-Sin', 'As-Saffat', 'Sad', 'Az-Zumar', 'Ghafir',
  'Fussilat', 'Ash-Shura', 'Az-Zukhruf', 'Ad-Dukhan', 'Al-Jathiyah',
  'Al-Ahqaf', 'Muhammad', 'Al-Fath', 'Al-Hujurat', 'Qaf',
  'Adh-Dhariyat', 'At-Tur', 'An-Najm', 'Al-Qamar', 'Ar-Rahman',
  "Al-Waqi'ah", 'Al-Hadid', 'Al-Mujadilah', 'Al-Hashr', 'Al-Mumtahanah',
  'As-Saff', "Al-Jumu'ah", 'Al-Munafiqun', 'At-Taghabun', 'At-Talaq',
  'At-Tahrim', 'Al-Mulk', 'Al-Qalam', 'Al-Haqqah', "Al-Ma'arij",
  'Nuh', 'Al-Jinn', 'Al-Muzzammil', 'Al-Muddaththir', 'Al-Qiyamah',
  'Al-Insan', 'Al-Mursalat', "An-Naba'", "An-Nazi'at", 'Abasa',
  'At-Takwir', 'Al-Infitar', 'Al-Mutaffifin', 'Al-Inshiqaq', 'Al-Buruj',
  'At-Tariq', "Al-A'la", 'Al-Ghashiyah', 'Al-Fajr', 'Al-Balad',
  'Ash-Shams', 'Al-Layl', 'Ad-Duha', 'Ash-Sharh', 'At-Tin',
  'Al-Alaq', 'Al-Qadr', 'Al-Bayyinah', 'Az-Zalzalah', 'Al-Adiyat',
  "Al-Qari'ah", 'At-Takathur', 'Al-Asr', 'Al-Humazah', 'Al-Fil',
  'Quraysh', "Al-Ma'un", 'Al-Kawthar', 'Al-Kafirun', 'An-Nasr',
  'Al-Masad', 'Al-Ikhlas', 'Al-Falaq', 'An-Nas',
];

/// Clean trailing dashes, footnote refs (e.g. ".2"), and whitespace from translations.
String _cleanTranslation(String text) {
  return text
      .replaceAll(RegExp(r'\.\d+'), '')  // Remove ".2", ".1" footnote refs
      .replaceAll(RegExp(r'\s*-\s*$'), '') // Remove trailing " -"
      .trim();
}

String _surahNameFromKey(String verseKey) {
  final surah = int.tryParse(verseKey.split(':').first) ?? 1;
  return (surah > 0 && surah < _surahNames.length)
      ? _surahNames[surah]
      : 'Surah $surah';
}

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(journalProvider);
    final bookmarks = ref.watch(bookmarkProvider);
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    List<JournalEntry> entries = _searchQuery.isEmpty
        ? allEntries
        : ref.read(journalProvider.notifier).search(_searchQuery);

    // Filter bookmarks by search query too
    final filteredBookmarks = _searchQuery.isEmpty
        ? bookmarks
        : bookmarks.where((b) {
            final q = _searchQuery.toLowerCase();
            return b.translationText.toLowerCase().contains(q) ||
                b.arabicText.contains(q) ||
                b.verseKey.contains(q);
          }).toList();

    final bool hasContent = allEntries.isNotEmpty || bookmarks.isNotEmpty;
    final bool isEmpty = entries.isEmpty && filteredBookmarks.isEmpty;
    final progress = ref.watch(userProgressProvider);
    final streak = progress.currentStreak;

    // Continuity cue: did the user reflect yesterday?
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final reflectedYesterday = allEntries.any((e) =>
        e.completedAt.year == yesterday.year &&
        e.completedAt.month == yesterday.month &&
        e.completedAt.day == yesterday.day);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + streak on one row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          t('your_journal'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const Spacer(),
                        // Streak badge — human language
                        if (streak > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  streak >= 7 ? '🔥' : '✦',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$streak ${streak == 1 ? t('day_showing_up') : t('days_showing_up')}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Tagline — short enough to never wrap awkwardly
                    Text(
                      t('journal_tagline'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3),
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    if (hasContent) ...[
                      const SizedBox(height: 12),
                      Text(
                        allEntries.isEmpty
                            ? '${bookmarks.length} ${t('saved_count')}'
                            : allEntries.length < 5
                                ? '${allEntries.length} ${allEntries.length == 1 ? t('reflection_count') : t('reflections_count')}  ·  ${bookmarks.length} ${t('saved_count')}'
                                : '${allEntries.length} ${t('reflected_times_suffix')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Continuity cue (animated fade-in) ──
            if (reflectedYesterday && _searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warmSurfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warmBorder.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '☀️',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t('reflected_yesterday'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.warmBrown.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 600.ms,
                    curve: Curves.easeOut,
                  ),
                ),
              ),

            // ── Search ──
            if (hasContent)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) setState(() => _searchQuery = v);
                      });
                    },
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: t('search_journal'),
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.25),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.25),
                      ),
                      filled: true,
                      fillColor: AppColors.warmSurface.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Empty state (both empty) ──
            if (isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          size: 36,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allEntries.isEmpty && _searchQuery.isEmpty
                              ? t('journal_begins')
                              : t('no_match'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ═══════════════════════════════════════════
            // SECTION 1: YOUR REFLECTIONS
            // ═══════════════════════════════════════════
            if (entries.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.edit_note_rounded,
                  title: t('your_reflections'),
                  count: entries.length,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: GestureDetector(
                        onTap: () =>
                            _openEntryDetail(context, entries[index], ref),
                        child: _JournalCard(
                          entry: entries[index],
                          lang: lang,
                          showDate: index == 0 ||
                              !_isSameDay(entries[index].completedAt,
                                  entries[index - 1].completedAt),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: 500.ms,
                            delay: (60 * index).clamp(0, 300).ms,
                          ),
                    );
                  },
                  childCount: entries.length,
                ),
              ),
            ],

            // ═══════════════════════════════════════════
            // SECTION 2: SAVED AYAHS (BOOKMARKS)
            // ═══════════════════════════════════════════
            if (filteredBookmarks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Strong visual break — line + spacing
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Divider(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.08),
                        thickness: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      icon: Icons.bookmark_rounded,
                      title: t('saved_ayahs'),
                      count: filteredBookmarks.length,
                    ),
                  ],
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: GestureDetector(
                        onTap: () => _openBookmarkDetail(
                            context, filteredBookmarks[index], ref),
                        child: _BookmarkCardCompact(
                          bookmark: filteredBookmarks[index],
                          lang: lang,
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: 500.ms,
                            delay: (60 * index).clamp(0, 300).ms,
                          ),
                    );
                  },
                  childCount: filteredBookmarks.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═══════════════════════════════════════════════════
// Section Header
// ═══════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.warmBrown.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warmSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.warmBrown.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Journal Entry Detail
// ═══════════════════════════════════════════════════

void _openEntryDetail(
    BuildContext context, JournalEntry entry, WidgetRef ref) {
  final theme = Theme.of(context);
  final lang = ref.read(languageProvider);
  final arabicFont = ref.read(arabicFontProvider);
  final arabicFontSize = ref.read(arabicFontSizeProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Date
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(entry.completedAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),

            const SizedBox(height: 24),

            // Arabic text
            Text(
              entry.arabicText,
              locale: const Locale('ar'),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabicFont == 'AmiriQuran' ? 'AmiriQuran' : null,
                fontSize: arabicFontSize * 0.85,
                color: AppColors.textPrimaryLight,
                height: 2.2,
              ),
            ),

            const SizedBox(height: 16),

            // Translation
            Text(
              '"${_cleanTranslation(entry.translationText)}"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 12),

            // Verse reference
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                entry.verseKey,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warmBrown,
                ),
              ),
            ),

            // Reflection
            if (entry.responseText != null &&
                entry.responseText!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Divider(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.06)),
              const SizedBox(height: 16),

              // Prompt
              if (entry.promptText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '"${entry.promptText!}"',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.accentDark,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),

              // User's words
              Text(
                entry.responseText!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  height: 1.8,
                  fontSize: 16,
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Text(
                AppTranslations.get('i_felt_this', lang),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════
// Bookmark Detail
// ═══════════════════════════════════════════════════

void _openBookmarkDetail(
    BuildContext context, Bookmark bookmark, WidgetRef ref) {
  final theme = Theme.of(context);
  final arabicFont = ref.read(arabicFontProvider);
  final arabicFontSize = ref.read(arabicFontSizeProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Date
            Text(
              DateFormat('MMMM d, yyyy').format(bookmark.bookmarkedAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.35),
              ),
            ),

            const SizedBox(height: 24),

            // Arabic text
            Text(
              bookmark.arabicText,
              locale: const Locale('ar'),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily:
                    arabicFont == 'AmiriQuran' ? 'AmiriQuran' : null,
                fontSize: arabicFontSize * 0.85,
                color: AppColors.textPrimaryLight,
                height: 2.2,
              ),
            ),

            const SizedBox(height: 16),

            // Translation
            if (bookmark.translationText.isNotEmpty)
              Text(
                '"${_cleanTranslation(bookmark.translationText)}"',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),

            const SizedBox(height: 12),

            // Verse reference
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                bookmark.verseKey,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warmBrown,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Remove bookmark
            Consumer(builder: (context, ref, _) {
              return TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(bookmarkProvider.notifier)
                      .remove(bookmark.verseKey);
                  Navigator.of(context).pop();
                },
                icon: Icon(
                  Icons.bookmark_remove_rounded,
                  size: 18,
                  color: theme.colorScheme.error.withValues(alpha: 0.6),
                ),
                label: Text(
                  AppTranslations.get('remove_bookmark', ref.watch(languageProvider)),
                  style: TextStyle(
                    color:
                        theme.colorScheme.error.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════
// Journal Card
// ═══════════════════════════════════════════════════

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;
  final String lang;
  final bool showDate;

  const _JournalCard({
    required this.entry,
    required this.lang,
    this.showDate = true,
  });

  IconData get _tierIcon {
    switch (entry.tier) {
      case ReflectionTier.acknowledge:
        return Icons.favorite_outline_rounded;
      case ReflectionTier.respond:
        return Icons.chat_bubble_outline_rounded;
      case ReflectionTier.reflect:
        return Icons.edit_outlined;
    }
  }


  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(entryDay).inDays;

    if (diff == 0) return AppTranslations.get('today_label', lang);
    if (diff == 1) return AppTranslations.get('yesterday_label', lang);
    if (diff < 7) return '$diff ${AppTranslations.get('days_ago', lang)}';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = _relativeDate(entry.completedAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warmBorder.withValues(alpha: 0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + tier icon
          Row(
            children: [
              if (showDate)
                Text(
                  dateStr,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Spacer(),
              Icon(
                _tierIcon,
                size: 14,
                color: AppColors.warmBrown.withValues(alpha: 0.4),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Arabic text
          Center(
            child: Text(
              entry.arabicText,
              locale: const Locale('ar'),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 20,
                color: AppColors.textPrimaryLight,
                height: 1.8,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 8),

          // Translation
          Center(
            child: Text(
              '"${_cleanTranslation(entry.translationText)}"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 10),

          // Surah pill
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_surahNameFromKey(entry.verseKey)}  ·  ${entry.verseKey}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warmBrown,
                  fontSize: 11,
                ),
              ),
            ),
          ),

          // Prompt + response
          if (entry.responseText != null &&
              entry.responseText!.isNotEmpty) ...[
            const SizedBox(height: 16),

            if (entry.promptText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '"${entry.promptText!}"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.accentDark,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),

            Text(
              entry.responseText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.7),
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Bookmark Card — Compact (reference feel, not primary)
// ═══════════════════════════════════════════════════

class _BookmarkCardCompact extends ConsumerWidget {
  final Bookmark bookmark;
  final String lang;

  const _BookmarkCardCompact({required this.bookmark, required this.lang});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warmSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warmBorder.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: English meaning + bookmark icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bookmark accent
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.bookmark_rounded,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),

              // English meaning (primary)
              Expanded(
                child: Text(
                  bookmark.translationText.isNotEmpty
                      ? _cleanTranslation(bookmark.translationText)
                      : bookmark.arabicText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.7),
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Chevron
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Surah reference + small Arabic
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Row(
              children: [
                // Surah · verse key
                Text(
                  '${_surahNameFromKey(bookmark.verseKey)}  ·  ${bookmark.verseKey}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warmBrown.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 12),
                // Arabic snippet (faded, spiritual anchor)
                Expanded(
                  child: Text(
                    bookmark.arabicText,
                    locale: const Locale('ar'),
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 12,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.2),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
