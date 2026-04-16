import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/features/journal/widgets/activity_heatmap.dart';

/// Clean trailing dashes, footnote refs, and whitespace from translations.
/// Covers the few ways footnote numbers leak into cached translation
/// text so the render layer stays defensive even if the API parser
/// ever regresses.
String _cleanTranslation(String text) {
  return text
      .replaceAll(RegExp(r'\.\d+'), '')  // ".2", ".1" footnote refs
      // Word-glued digits (e.g. "Lord1 of") — only strip when the
      // digit is followed by whitespace, punctuation, or end.
      // Use `replaceAllMapped`; `replaceAll` treats `$1` as literal.
      .replaceAllMapped(
        RegExp(r'(\w)\d+(?=\s|[,.!?;:"]|$)'),
        (m) => m.group(1)!,
      )
      .replaceAll(RegExp(r'\s*-\s*$'), '') // trailing " -"
      .trim();
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          // Pull-to-refresh hydrates notes from QF so reflections the
          // user wrote on quran.com from another device get pulled in
          // on demand. Safe to call while already hydrating — the
          // notifier's concurrency guard reuses the in-flight Future.
          onRefresh: () =>
              ref.read(journalProvider.notifier).hydrateFromQF(),
          color: theme.colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
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
                        // Streak badge — human language. Hidden when
                        // the activity heatmap below is visible since
                        // it already carries the same streak info, and
                        // duplicating the number makes the header feel
                        // noisy. Still shown on the empty-state and
                        // search-result paths where the heatmap is not.
                        if (streak > 0 && (!hasContent || _searchQuery.isNotEmpty))
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

                    // Only surface a count line here when reflections
                    // are absent — bookmarks-only users need somewhere
                    // to see their count. With reflections, the
                    // "Your Reflections · N" section header carries
                    // the number; doubling it up reads as clutter.
                    if (hasContent && allEntries.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${bookmarks.length} ${t('saved_count')}',
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

            // ── Activity heatmap — the emotional proof of practice ──
            if (hasContent && _searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: const ActivityHeatmap(),
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
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Layered icon — outer ring + inner book.
                        // Feels like a held moment rather than a grey void.
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.04),
                          ),
                          child: Icon(
                            Icons.auto_stories_outlined,
                            size: 32,
                            color: AppColors.primary.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          allEntries.isEmpty && _searchQuery.isEmpty
                              ? t('journal_begins')
                              : t('no_match'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                            height: 1.5,
                          ),
                        ),
                        if (allEntries.isEmpty && _searchQuery.isEmpty) ...[
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.go('/home');
                            },
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 16),
                            label: Text(t('today')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ).animate().fadeIn(duration: 600.ms).slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOut,
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

  String get _tierLabel {
    switch (entry.tier) {
      case ReflectionTier.acknowledge:
        return 'Acknowledged';
      case ReflectionTier.respond:
        return 'Responded';
      case ReflectionTier.reflect:
        return 'Reflected';
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
    final response = entry.responseText?.trim() ?? '';
    final hasReflection = response.isNotEmpty;

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
          // Date · tier label · tier icon. The label tells the
          // *quality* of the entry (acknowledged / responded /
          // reflected) so scanning the journal reveals the user's
          // depth over time, not just their cadence.
          Row(
            children: [
              if (showDate)
                Text(
                  dateStr,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Spacer(),
              Icon(
                _tierIcon,
                size: 13,
                color: AppColors.warmBrown.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                _tierLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warmBrown.withValues(alpha: 0.55),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (hasReflection) ...[
            // HERO: the user's own words. Gold-accent left border and
            // darker typography signal "this is *your* voice" — the
            // ayah below is the context for these words.
            _ReflectionBlock(
              promptText: entry.promptText,
              responseText: response,
            ),
            const SizedBox(height: 18),
            // Ayah as context beneath. Divider makes the demotion
            // clear: below the line is what you were reflecting *on*.
            _AyahContext(entry: entry),
          ] else ...[
            // No reflection body — this is an "acknowledge" entry.
            // The ayah stays as the hero since the user chose to sit
            // with it silently. A small footer notes that choice.
            _AyahHero(entry: entry),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.warmBorder.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Text(
                'This spoke to me',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warmBrown,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hero block for entries where the user wrote a reflection. The
/// optional prompt appears as a small gold-accent quote above the
/// user's response so the reader sees both the question and the
/// answer, without the ayah competing for attention yet.
class _ReflectionBlock extends StatelessWidget {
  final String? promptText;
  final String responseText;

  const _ReflectionBlock({
    required this.promptText,
    required this.responseText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.accent.withValues(alpha: 0.6),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (promptText != null && promptText!.trim().isNotEmpty) ...[
            Text(
              promptText!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.accentDark.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
                height: 1.4,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            responseText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimaryLight,
              height: 1.65,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ayah as supporting context below a reflection. Compact — one line
/// of Arabic, one line of translation, and the reference pill.
class _AyahContext extends StatelessWidget {
  final JournalEntry entry;

  const _AyahContext({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translation = _cleanTranslation(entry.translationText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thin warm divider signals: below = context.
        Container(
          height: 0.5,
          color: AppColors.warmBorder.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 14),
        Text(
          entry.arabicText,
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontFamily: 'AmiriQuran',
            fontSize: 16,
            color: AppColors.textPrimaryLight,
            height: 1.9,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (translation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '"$translation"',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.warmSurface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${surahNameFromKey(entry.verseKey)} · ${entry.verseKey}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.warmBrown,
              fontSize: 10,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Ayah as hero (when no reflection text was written). Gets the
/// centered, larger treatment since the ayah itself is the subject.
class _AyahHero extends StatelessWidget {
  final JournalEntry entry;

  const _AyahHero({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translation = _cleanTranslation(entry.translationText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
              height: 1.9,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (translation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '"$translation"',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warmSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${surahNameFromKey(entry.verseKey)}  ·  ${entry.verseKey}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.warmBrown,
              fontSize: 11,
            ),
          ),
        ),
      ],
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
                  '${surahNameFromKey(bookmark.verseKey)}  ·  ${bookmark.verseKey}',
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
