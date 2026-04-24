import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/features/journal/widgets/activity_heatmap.dart';
import 'package:tadabbur/features/journal/widgets/year_in_ayat_share_card.dart';
import 'package:tadabbur/features/reflection/screens/reflection_screen.dart';

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

  /// When set, only entries of this tier show in the list. `null`
  /// means "all tiers". Drives the filter chip row under the search
  /// bar — essential once a user has hundreds of entries and wants
  /// to focus on just their deeper reflections.
  ReflectionTier? _tierFilter;

  /// How the journal list is organized. `time` groups entries by
  /// month (reads as a diary). `surah` groups entries by chapter of
  /// the Qur'an and sorts within each by verse order (reads as a
  /// commentary on the Qur'an). Both lenses show the same entries —
  /// only the grouping changes.
  _JournalLens _lens = _JournalLens.time;

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

    List<JournalEntry> entries;
    if (_searchQuery.isEmpty) {
      entries = allEntries;
    } else {
      final q = _searchQuery.toLowerCase();
      entries = allEntries.where((e) {
        return (e.responseText?.toLowerCase().contains(q) ?? false) ||
            e.translationText.toLowerCase().contains(q) ||
            e.verseKey.contains(q);
      }).toList();
    }

    // Apply the tier filter on top of search — search narrows by
    // content, tier narrows by depth. Both can be active together.
    if (_tierFilter != null) {
      entries = entries.where((e) => e.tier == _tierFilter).toList();
    }

    // Partition pinned entries into their own section. Pinned lives
    // above the chronological stream so the user's anchor points
    // don't disappear into the years. Unpinned list is what feeds
    // the month grouping.
    final pinnedEntries = entries.where((e) => e.isPinned).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final unpinnedEntries = entries.where((e) => !e.isPinned).toList();

    // Build a sparse "on this day" set — entries from prior years on
    // the same month+day as today. Only surfaced as a banner above
    // the list when there's a prior entry to show; silent otherwise.
    final now = DateTime.now();
    final onThisDay = allEntries
        .where((e) =>
            e.completedAt.year != now.year &&
            e.completedAt.month == now.month &&
            e.completedAt.day == now.day)
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    // Flatten entries + month headers into a single list for the
    // SliverList. This gives us "sticky-feeling" month headers that
    // pin inside the flow without needing a sliver-per-month (which
    // would explode widget counts at 3000+ entries). Performance is
    // linear in entries shown, not in total history.
    final grouped = _lens == _JournalLens.time
        ? _groupByMonth(unpinnedEntries)
        : _groupBySurah(unpinnedEntries);

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

            // ── Year in Ayat review ──
            // Surfaces during the last two weeks of the year and the
            // first two weeks of the new year, as a warm reminder of
            // what the user sat with. Hidden the rest of the year.
            // Stats computed locally from the journal — no server call.
            if (_searchQuery.isEmpty &&
                _YearInAyatBanner.isInWindow() &&
                allEntries.isNotEmpty)
              SliverToBoxAdapter(
                child: _YearInAyatBanner(entries: allEntries),
              ),

            // ── "On this day" — the journal-as-moat moment ──
            // Only appears when the user has a reflection from a
            // previous year on today's date. This is the feature
            // that makes year-2 of using Tadabbur dramatically more
            // valuable than year-1, and that no other Quran app can
            // ever deliver.
            if (_searchQuery.isEmpty && onThisDay.isNotEmpty)
              SliverToBoxAdapter(
                child: _OnThisDayBanner(
                  entries: onThisDay,
                  onTap: (entry) =>
                      _openEntryDetail(context, entry, ref),
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
            if (allEntries.isNotEmpty && hasContent) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.edit_note_rounded,
                  title: t('your_reflections'),
                  count: entries.length,
                ),
              ),
              // Tier filter chips — let the user focus on just their
              // deeper reflections (or light acknowledgements) without
              // losing anything. Essential for scanning a long
              // journal; harmless when the journal is small.
              SliverToBoxAdapter(
                child: _TierFilterChips(
                  current: _tierFilter,
                  onChanged: (t) {
                    setState(() => _tierFilter = t);
                  },
                ),
              ),
              // Lens toggle — switch between Time and Qur'an grouping.
              // "Time" reads the journal as a diary; "Qur'an" reads it
              // as a commentary on the text. Same entries either way.
              SliverToBoxAdapter(
                child: _LensToggle(
                  current: _lens,
                  onChanged: (l) => setState(() => _lens = l),
                ),
              ),
            ],

            // Pinned section — renders above the month-grouped stream
            // so user-anchored reflections stay accessible regardless
            // of how far they're buried chronologically. Hidden when
            // no pins; quietly compact when there are a few.
            if (pinnedEntries.isNotEmpty)
              SliverToBoxAdapter(
                child: _PinnedSection(
                  entries: pinnedEntries,
                  lang: lang,
                  onTap: (e) => _openEntryDetail(context, e, ref),
                ),
              ),

            // Empty tier-filter result: show a gentle note instead of
            // an abrupt "no reflections" state — the journal has
            // content, the filter just hid it.
            if (allEntries.isNotEmpty &&
                entries.isEmpty &&
                _searchQuery.isEmpty &&
                _tierFilter != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Text(
                    'No ${_tierFilter!.name} entries yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.45),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

            // Entries grouped by month. The list interleaves month
            // headers with entry cards so scrolling through years
            // always has temporal landmarks. At 3000 entries this
            // still renders in O(n_visible) — SliverList lazy-builds.
            if (entries.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = grouped[index];
                    if (item.isHeader) {
                      if (item.surahNumber != null) {
                        return _SurahHeader(
                          surahNumber: item.surahNumber!,
                          count: item.surahCount ?? 0,
                        );
                      }
                      return _MonthHeader(date: item.monthDate!);
                    }
                    final entry = item.entry!;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: GestureDetector(
                        onTap: () => _openEntryDetail(context, entry, ref),
                        child: _JournalCard(
                          entry: entry,
                          lang: lang,
                          showDate: true,
                          collapsed: true,
                        ),
                      ),
                    );
                  },
                  childCount: grouped.length,
                ),
              ),

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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      expand: false,
      builder: (ctx, controller) => _EntryDetailSheet(
        entry: entry,
        controller: controller,
      ),
    ),
  );
}

/// World-class reflection detail sheet.
///
/// The current reflection is the anchor, but the strongest thing
/// Tadabbur can show is *continuity*: if the user has touched this
/// verse before, we surface those priors inline. No other Quran app
/// can do this — because nobody else accumulates the data. The view
/// is a reactive Consumer so the priors strip updates whenever new
/// entries land (OAuth hydrate, new save, etc.).
class _EntryDetailSheet extends ConsumerWidget {
  final JournalEntry entry;
  final ScrollController controller;

  const _EntryDetailSheet({
    required this.entry,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    final arabicFont = ref.watch(arabicFontProvider);
    final arabicFontSize = ref.watch(arabicFontSizeProvider);
    final allEntries = ref.watch(journalProvider);
    final useHijri = ref.watch(useHijriDatesProvider);

    // Priors = every other reflection the user has written on this
    // exact verse, newest first. The current entry is excluded so we
    // don't mirror it in the "before" strip.
    final priors = allEntries
        .where((e) => e.verseKey == entry.verseKey && e.id != entry.id)
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final surahNum = int.tryParse(entry.verseKey.split(':').first) ?? 0;
    final ayahNum = entry.verseKey.split(':').last;
    final surahName = (surahNum > 0 && surahNum <= 114)
        ? kSurahNames[surahNum]
        : 'Surah $surahNum';

    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ──
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header: date on one line, surah:ayah on the next ──
          Center(
            child: Text(
              formatLongDate(entry.completedAt, useHijri: useHijri),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  surahName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ayah $ayahNum',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // ── Arabic ayah — breathing space, same weight as daily screen ──
          Text(
            entry.arabicText,
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: arabicFont == 'AmiriQuran' ? 'AmiriQuran' : null,
              fontSize: arabicFontSize * 0.88,
              color: theme.colorScheme.onSurface,
              height: 2.1,
            ),
          ),

          const SizedBox(height: 18),

          // ── Translation ──
          Text(
            '"${_cleanTranslation(entry.translationText)}"',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
              height: 1.7,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 28),

          // ── Tier badge + user reflection block ──
          _DetailReflectionBlock(entry: entry, lang: lang),

          // ── Priors strip: the journal-as-moat moment ──
          if (priors.isNotEmpty) ...[
            const SizedBox(height: 32),
            _PriorsStrip(priors: priors, currentDate: entry.completedAt),
          ],

          const SizedBox(height: 32),

          // ── Actions ──
          _EntryActions(entry: entry),
        ],
      ),
    );
  }
}

/// The tier-stamped block that holds the user's words (or the
/// dignified acknowledge line when they wrote nothing). Used inside
/// the entry detail sheet — distinct from the list-view summary
/// block which shares the same spirit but has a different layout.
///
/// Two visual modes:
///   - acknowledge → italic framing line, no text input
///   - respond/reflect → the user's writing in notebook typography
class _DetailReflectionBlock extends StatelessWidget {
  final JournalEntry entry;
  final String lang;

  const _DetailReflectionBlock({required this.entry, required this.lang});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (tierLabel, tierIcon, tierColor) = _tierMeta(entry.tier, theme);
    final hasText =
        entry.responseText != null && entry.responseText!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tierColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier label — quiet but present
          Row(
            children: [
              Icon(tierIcon, size: 14, color: tierColor),
              const SizedBox(width: 6),
              Text(
                tierLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tierColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (entry.promptText != null && hasText) ...[
            Text(
              '"${entry.promptText!}"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tierColor.withValues(alpha: 0.85),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (hasText)
            Text(
              entry.responseText!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.75,
                fontSize: 15.5,
              ),
            )
          else
            Text(
              'A moment of presence with this ayah.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  (String, IconData, Color) _tierMeta(ReflectionTier tier, ThemeData theme) {
    switch (tier) {
      case ReflectionTier.acknowledge:
        return (
          'ACKNOWLEDGED',
          Icons.favorite_border_rounded,
          AppColors.tier1,
        );
      case ReflectionTier.respond:
        return (
          'RESPONDED',
          Icons.chat_bubble_outline_rounded,
          AppColors.tier2,
        );
      case ReflectionTier.reflect:
        return (
          'REFLECTED',
          Icons.auto_awesome_outlined,
          AppColors.tier3,
        );
    }
  }
}

/// Inline strip showing prior reflections the user has written on
/// the same verse. The moment that turns Tadabbur from "another
/// Quran app with nice design" into "a record of your relationship
/// with the Quran over your lifetime."
class _PriorsStrip extends StatelessWidget {
  final List<JournalEntry> priors;
  final DateTime currentDate;

  const _PriorsStrip({required this.priors, required this.currentDate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              "YOU'VE SAT WITH THIS AYAH BEFORE",
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Show up to 3 priors — more than that clutters a contemplative
        // surface. The journal list proper holds the full history.
        for (final p in priors.take(3)) ...[
          _PriorCard(prior: p, currentDate: currentDate),
          const SizedBox(height: 8),
        ],
        if (priors.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${priors.length - 3} more in your journal',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

class _PriorCard extends StatelessWidget {
  final JournalEntry prior;
  final DateTime currentDate;

  const _PriorCard({required this.prior, required this.currentDate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ago = _humanAgo(prior.completedAt, currentDate);
    final text = (prior.responseText != null &&
            prior.responseText!.trim().isNotEmpty)
        ? prior.responseText!
        : 'Acknowledged this ayah';
    final (_, tierIcon, tierColor) = _tierVisual(prior.tier);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tierIcon, size: 12, color: tierColor),
              const SizedBox(width: 6),
              Text(
                ago,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  static (String, IconData, Color) _tierVisual(ReflectionTier tier) {
    switch (tier) {
      case ReflectionTier.acknowledge:
        return ('Acknowledged', Icons.favorite_border_rounded, AppColors.tier1);
      case ReflectionTier.respond:
        return ('Responded', Icons.chat_bubble_outline_rounded, AppColors.tier2);
      case ReflectionTier.reflect:
        return ('Reflected', Icons.auto_awesome_outlined, AppColors.tier3);
    }
  }

  static String _humanAgo(DateTime then, DateTime now) {
    final days = now.difference(then).inDays;
    if (days == 0) return 'Earlier today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) {
      final w = days ~/ 7;
      return '$w ${w == 1 ? "week" : "weeks"} ago';
    }
    if (days < 365) {
      final m = days ~/ 30;
      return '$m ${m == 1 ? "month" : "months"} ago';
    }
    final y = days ~/ 365;
    return '$y ${y == 1 ? "year" : "years"} ago';
  }
}

/// Single action: write another reflection on this same verse. The
/// ReflectionScreen carries the thesis — "sit with this ayah" — so
/// re-entering it is the right way to deepen an entry rather than
/// editing the past text. Past reflections are *history*, not drafts.
class _EntryActions extends ConsumerWidget {
  final JournalEntry entry;
  const _EntryActions({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Watch the live entry state so the pin icon reflects toggles in
    // real time — the passed-in [entry] is a snapshot from when the
    // sheet opened.
    final live = ref
        .watch(journalProvider)
        .firstWhere((e) => e.id == entry.id, orElse: () => entry);
    final pinned = live.isPinned;

    return Row(
      children: [
        // Primary action: write another reflection on this verse.
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () async {
              Navigator.of(context).pop();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReflectionScreen(
                    ayah: _ayahFromEntry(entry),
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: theme.colorScheme.primary,
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Reflect again'),
          ),
        ),
        const SizedBox(width: 10),
        // Secondary action: pin / unpin. Uses the same tonal style
        // so it reads as a peer of "Reflect again" rather than a
        // buried icon button. Accent-colored when pinned.
        Material(
          color: pinned
              ? AppColors.accent.withValues(alpha: 0.15)
              : theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              HapticFeedback.lightImpact();
              await ref
                  .read(journalProvider.notifier)
                  .togglePin(entry.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Icon(
                pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                size: 20,
                color: pinned
                    ? AppColors.accentDark
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Ayah _ayahFromEntry(JournalEntry e) {
    final parts = e.verseKey.split(':');
    return Ayah(
      id: 0,
      verseKey: e.verseKey,
      surahNumber: int.tryParse(parts.first) ?? 1,
      ayahNumber: int.tryParse(parts.last) ?? 1,
      textUthmani: e.arabicText,
      textSimple: e.arabicText,
      translationText: e.translationText,
      juzNumber: 0,
      hizbNumber: 0,
      pageNumber: 0,
    );
  }
}

// ═══════════════════════════════════════════════════
// Bookmark Detail
// ═══════════════════════════════════════════════════

void _openBookmarkDetail(
    BuildContext context, Bookmark bookmark, WidgetRef ref) {
  final theme = Theme.of(context);
  final arabicFont = ref.read(arabicFontProvider);
  final arabicFontSize = ref.read(arabicFontSizeProvider);
  final useHijri = ref.read(useHijriDatesProvider);

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
              formatMediumDate(bookmark.bookmarkedAt, useHijri: useHijri),
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

/// Short form of a date ("Apr 24" / "24 Dhū al-Qa'dah"), Hijri-aware.
String formatShortDate(DateTime date, {required bool useHijri}) {
  if (useHijri) {
    final h = HijriCalendar.fromDate(date);
    return '${h.hDay} ${h.longMonthName}';
  }
  return DateFormat('MMM d').format(date);
}

/// Medium form ("April 24, 2026" / "24 Dhū al-Qa'dah 1447"),
/// Hijri-aware.
String formatMediumDate(DateTime date, {required bool useHijri}) {
  if (useHijri) {
    final h = HijriCalendar.fromDate(date);
    return '${h.hDay} ${h.longMonthName} ${h.hYear}';
  }
  return DateFormat('MMMM d, yyyy').format(date);
}

/// Long form with weekday ("Friday, 24 April 2026" /
/// "Friday, 24 Dhū al-Qa'dah 1447"), Hijri-aware. The weekday stays
/// in the device's locale either way — Hijri doesn't reindex days of
/// the week, they're the same seven days.
String formatLongDate(DateTime date, {required bool useHijri}) {
  if (useHijri) {
    final h = HijriCalendar.fromDate(date);
    final weekday = DateFormat('EEEE').format(date);
    return '$weekday, ${h.hDay} ${h.longMonthName} ${h.hYear}';
  }
  return DateFormat('EEEE, d MMMM yyyy').format(date);
}

/// Hijri-year label for a Gregorian year. A Gregorian year typically
/// spans two Hijri years (~354 days each) so we render a range like
/// `1446–1447 AH` when they differ, or a single `1446 AH` when the
/// whole year falls inside one Hijri year (rare at these edges).
/// Used in the Year-in-Ayat header so a Muslim's year is visible in
/// both calendars — Ramadan, Dhul-Hijjah, and Muharram only show up
/// in the Hijri lens.
String hijriYearLabel(int gregorianYear) {
  final start = HijriCalendar.fromDate(DateTime(gregorianYear, 1, 1));
  final end = HijriCalendar.fromDate(DateTime(gregorianYear, 12, 31));
  if (start.hYear == end.hYear) return '${start.hYear} AH';
  return '${start.hYear}–${end.hYear} AH';
}

class _JournalCard extends ConsumerWidget {
  final JournalEntry entry;
  final String lang;
  final bool showDate;
  /// When true, long reflection text is truncated to ~2 lines with
  /// an ellipsis — the card is a summary, the detail sheet is where
  /// the full reflection lives. Keeps the list scannable at 3000+
  /// entries without hiding information.
  final bool collapsed;

  const _JournalCard({
    required this.entry,
    required this.lang,
    this.showDate = true,
    this.collapsed = false,
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

  String _relativeDate(DateTime date, bool useHijri) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(entryDay).inDays;

    if (diff == 0) return AppTranslations.get('today_label', lang);
    if (diff == 1) return AppTranslations.get('yesterday_label', lang);
    if (diff < 7) return '$diff ${AppTranslations.get('days_ago', lang)}';
    return formatShortDate(date, useHijri: useHijri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final useHijri = ref.watch(useHijriDatesProvider);
    final dateStr = _relativeDate(entry.completedAt, useHijri);
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
              maxLines: collapsed ? 2 : null,
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
  /// Null = show full text (used in the detail sheet). When set, the
  /// response text is capped with an ellipsis — list cards use this
  /// to stay scannable while long reflections remain fully readable
  /// in the detail view.
  final int? maxLines;

  const _ReflectionBlock({
    required this.promptText,
    required this.responseText,
    this.maxLines,
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
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
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


/// Which axis the journal list is organized along.
enum _JournalLens { time, surah }

/// Lightweight row in the grouped journal list. Three flavors:
/// month header (time lens), surah header (surah lens), or an entry.
/// A discriminated item type keeps the SliverList's builder simple
/// and lets us render thousands of entries without building a widget
/// per entry up-front.
class _JournalGroupItem {
  final bool isHeader;
  final DateTime? monthDate;
  final int? surahNumber;
  final int? surahCount;
  final JournalEntry? entry;

  const _JournalGroupItem.monthHeader(DateTime date)
      : isHeader = true,
        monthDate = date,
        surahNumber = null,
        surahCount = null,
        entry = null;

  const _JournalGroupItem.surahHeader(int surah, int count)
      : isHeader = true,
        monthDate = null,
        surahNumber = surah,
        surahCount = count,
        entry = null;

  const _JournalGroupItem.entry(JournalEntry e)
      : isHeader = false,
        monthDate = null,
        surahNumber = null,
        surahCount = null,
        entry = e;
}

/// Group entries by calendar month and interleave month-header items.
/// Entries arrive newest-first from the notifier; we preserve that
/// order. Headers are inserted whenever the month+year pair changes.
List<_JournalGroupItem> _groupByMonth(List<JournalEntry> entries) {
  if (entries.isEmpty) return const [];
  final sorted = [...entries]
    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  final out = <_JournalGroupItem>[];
  DateTime? lastMonth;
  for (final e in sorted) {
    final m = DateTime(e.completedAt.year, e.completedAt.month);
    if (lastMonth == null || m != lastMonth) {
      out.add(_JournalGroupItem.monthHeader(m));
      lastMonth = m;
    }
    out.add(_JournalGroupItem.entry(e));
  }
  return out;
}

/// Group entries by Qur'an chapter (surah) and, within each, order
/// by verse number so the list reads as the user's commentary on
/// that surah. Surahs appear in their canonical order (Al-Fatiha
/// first, An-Nas last) because that's how Muslims mentally navigate
/// the Qur'an — not by how recently they engaged with each surah.
List<_JournalGroupItem> _groupBySurah(List<JournalEntry> entries) {
  if (entries.isEmpty) return const [];
  final bySurah = <int, List<JournalEntry>>{};
  for (final e in entries) {
    final surah = int.tryParse(e.verseKey.split(':').first) ?? 0;
    (bySurah[surah] ??= []).add(e);
  }
  // Sort ayat within a surah by ayah number ascending (the reading
  // order). If two entries share a verse key, the newer reflection
  // comes first so scrolling a surah reads as "most recent first
  // within each verse."
  for (final list in bySurah.values) {
    list.sort((a, b) {
      final ay = int.tryParse(a.verseKey.split(':').last) ?? 0;
      final by = int.tryParse(b.verseKey.split(':').last) ?? 0;
      if (ay != by) return ay.compareTo(by);
      return b.completedAt.compareTo(a.completedAt);
    });
  }
  final out = <_JournalGroupItem>[];
  final surahs = bySurah.keys.toList()..sort();
  for (final s in surahs) {
    final list = bySurah[s]!;
    out.add(_JournalGroupItem.surahHeader(s, list.length));
    for (final e in list) {
      out.add(_JournalGroupItem.entry(e));
    }
  }
  return out;
}

/// Month section header — the temporal landmark that keeps a
/// long-tenure journal navigable. Renders as quiet small-caps label
/// with a subtle underline ("APRIL 2026 ─────"), not a loud card.
class _MonthHeader extends ConsumerWidget {
  final DateTime date;

  const _MonthHeader({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final useHijri = ref.watch(useHijriDatesProvider);
    final now = DateTime.now();
    String label;
    if (useHijri) {
      // Render the month header in the Islamic calendar. For a Quran
      // journal this lets section labels like "Ramadan 1447" carry
      // spiritual weight that "March 2026" can't.
      final h = HijriCalendar.fromDate(date);
      final hNow = HijriCalendar.now();
      final sameMonth = h.hMonth == hNow.hMonth && h.hYear == hNow.hYear;
      label = sameMonth
          ? 'This month'
          : '${h.longMonthName} ${h.hYear}'.toUpperCase();
    } else {
      label = (date.year == now.year && date.month == now.month)
          ? 'This month'
          : date.year == now.year
              ? DateFormat('MMMM').format(date).toUpperCase()
              : DateFormat('MMMM yyyy').format(date).toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 0.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of tier filter chips. Lives above the entry list.
/// Null selection = "All" — tapping All again is a no-op, tapping
/// the current tier again clears to All (standard toggle behavior).
class _TierFilterChips extends StatelessWidget {
  final ReflectionTier? current;
  final ValueChanged<ReflectionTier?> onChanged;

  const _TierFilterChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = <(ReflectionTier?, String, IconData)>[
      (null, 'All', Icons.all_inclusive_rounded),
      (ReflectionTier.acknowledge, 'Acknowledged', Icons.favorite_border_rounded),
      (ReflectionTier.respond, 'Responded', Icons.chat_bubble_outline_rounded),
      (ReflectionTier.reflect, 'Reflected', Icons.auto_awesome_outlined),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (tier, label, icon) = options[i];
          final selected = current == tier;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(selected && tier != null ? null : tier);
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 13,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Banner showing a prior-year entry on today's calendar date.
///
/// The single most powerful feature for a years-spanning Quran journal
/// — "1 year ago today, you reflected on Ar-Rahman 55:13" — and the
/// one no other Quran app can deliver, because nobody else
/// accumulates the data. Shows the most-recent prior entry; if
/// multiple prior years exist, the most recent is surfaced with a
/// count ("+2 more from years past").
class _OnThisDayBanner extends StatelessWidget {
  final List<JournalEntry> entries;
  final ValueChanged<JournalEntry> onTap;

  const _OnThisDayBanner({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final hero = entries.first;
    final years = DateTime.now().year - hero.completedAt.year;
    final agoLabel = years == 1
        ? '1 year ago today'
        : years > 1
            ? '$years years ago today'
            : 'Earlier today'; // defensive — shouldn't hit for this banner
    final preview = (hero.responseText?.trim().isNotEmpty ?? false)
        ? hero.responseText!.trim()
        : _cleanTranslation(hero.translationText);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(hero),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withValues(alpha: 0.08),
                  AppColors.accent.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 13,
                      color: AppColors.accentDark.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      agoLabel.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.accentDark.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You reflected on ${surahNameFromKey(hero.verseKey)} ${hero.verseKey}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (entries.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+ ${entries.length - 1} more from years past',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.accentDark.withValues(alpha: 0.65),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinned section above the month-grouped stream. Renders pinned
/// entries as compact cards with a quiet "PINNED" header. Capped at
/// a reasonable count so a user who pins everything doesn't turn
/// the pinned section into a second journal — when there are more
/// than [_maxVisiblePins], we show the first few and hint at the
/// rest via the tail count.
class _PinnedSection extends StatelessWidget {
  final List<JournalEntry> entries;
  final String lang;
  final ValueChanged<JournalEntry> onTap;

  static const _maxVisiblePins = 5;

  const _PinnedSection({
    required this.entries,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = entries.take(_maxVisiblePins).toList();
    final overflow = entries.length - visible.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin_rounded,
                  size: 12,
                  color: AppColors.accentDark.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'PINNED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accentDark.withValues(alpha: 0.8),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 0.5,
                    color: AppColors.accent.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
          for (final entry in visible) ...[
            GestureDetector(
              onTap: () => onTap(entry),
              child: _JournalCard(
                entry: entry,
                lang: lang,
                showDate: true,
                collapsed: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (overflow > 0)
            // Tappable overflow footer — opens a bottom sheet with
            // ALL pinned entries. Without this, users who pin more
            // than the visible cap have 15+ reflections that are
            // effectively invisible.
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _PinnedSheet.show(context, entries, lang, onTap),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        '+ $overflow more pinned',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accentDark.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.accentDark.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Surah section header for the Qur'an-lens grouping. Shows the
/// surah name, its number in parentheses, and the reflection count
/// for that surah. Same visual weight as month headers so the two
/// lenses feel like variations of the same layout rather than two
/// different screens.
class _SurahHeader extends StatelessWidget {
  final int surahNumber;
  final int count;

  const _SurahHeader({required this.surahNumber, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (surahNumber >= 1 && surahNumber <= 114)
        ? kSurahNames[surahNumber]
        : 'Surah $surahNumber';
    final label = '$surahNumber · ${name.toUpperCase()}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 reflection' : '$count reflections',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 0.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lens toggle: Time vs. Qur'an. Sits below the tier filter chips.
/// Two-pill segmented control so the choice is visible but quiet.
class _LensToggle extends StatelessWidget {
  final _JournalLens current;
  final ValueChanged<_JournalLens> onChanged;

  const _LensToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          Text(
            'GROUP BY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 10),
          _LensPill(
            label: 'Time',
            icon: Icons.schedule_rounded,
            selected: current == _JournalLens.time,
            onTap: () => onChanged(_JournalLens.time),
          ),
          const SizedBox(width: 8),
          _LensPill(
            label: "Qur'an",
            icon: Icons.auto_stories_outlined,
            selected: current == _JournalLens.surah,
            onTap: () => onChanged(_JournalLens.surah),
          ),
        ],
      ),
    );
  }
}

class _LensPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LensPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// End-of-year review data, computed locally from the journal. Pure
/// function of `(year, entries)` so the sheet is cheap to render and
/// safe to rebuild as the user keeps reflecting during the window.
class YearStats {
  final int year;
  final int totalEntries;
  final int activeDays;
  final int longestStreak;
  final int surahsEngaged;
  final int topSurahNumber;
  final int topSurahCount;
  final int tier1;
  final int tier2;
  final int tier3;
  final JournalEntry? deepest;

  const YearStats({
    required this.year,
    required this.totalEntries,
    required this.activeDays,
    required this.longestStreak,
    required this.surahsEngaged,
    required this.topSurahNumber,
    required this.topSurahCount,
    required this.tier1,
    required this.tier2,
    required this.tier3,
    required this.deepest,
  });

  static YearStats compute(List<JournalEntry> entries, int year) {
    final inYear =
        entries.where((e) => e.completedAt.year == year).toList();
    if (inYear.isEmpty) {
      return YearStats(
        year: year,
        totalEntries: 0,
        activeDays: 0,
        longestStreak: 0,
        surahsEngaged: 0,
        topSurahNumber: 0,
        topSurahCount: 0,
        tier1: 0,
        tier2: 0,
        tier3: 0,
        deepest: null,
      );
    }
    // Unique days of practice.
    final daysSet = <String>{};
    final bySurah = <int, int>{};
    var tier1 = 0, tier2 = 0, tier3 = 0;
    JournalEntry? deepest;
    for (final e in inYear) {
      daysSet.add(
        '${e.completedAt.year}-${e.completedAt.month}-${e.completedAt.day}',
      );
      final s = int.tryParse(e.verseKey.split(':').first) ?? 0;
      if (s > 0) bySurah[s] = (bySurah[s] ?? 0) + 1;
      switch (e.tier) {
        case ReflectionTier.acknowledge:
          tier1++;
        case ReflectionTier.respond:
          tier2++;
        case ReflectionTier.reflect:
          tier3++;
      }
      if ((e.responseText?.length ?? 0) >
          (deepest?.responseText?.length ?? 0)) {
        deepest = e;
      }
    }
    // Compute longest consecutive-day streak within the year.
    final sortedDays = daysSet
        .map((s) {
          final parts = s.split('-').map(int.parse).toList();
          return DateTime(parts[0], parts[1], parts[2]);
        })
        .toList()
      ..sort();
    var longest = 1;
    var current = 1;
    for (var i = 1; i < sortedDays.length; i++) {
      final diff = sortedDays[i].difference(sortedDays[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else if (diff > 1) {
        current = 1;
      }
    }
    if (sortedDays.isEmpty) longest = 0;

    // Most-reflected surah.
    var topSurah = 0;
    var topCount = 0;
    bySurah.forEach((s, c) {
      if (c > topCount) {
        topSurah = s;
        topCount = c;
      }
    });

    return YearStats(
      year: year,
      totalEntries: inYear.length,
      activeDays: daysSet.length,
      longestStreak: longest,
      surahsEngaged: bySurah.length,
      topSurahNumber: topSurah,
      topSurahCount: topCount,
      tier1: tier1,
      tier2: tier2,
      tier3: tier3,
      deepest: deepest,
    );
  }
}

/// Gold-accented banner that appears only in the year-end window
/// (mid-December through mid-January). Tapping opens the full
/// review sheet. Hidden the rest of the year — we only invite the
/// user to look back when there's enough perspective to look with.
class _YearInAyatBanner extends ConsumerWidget {
  final List<JournalEntry> entries;

  const _YearInAyatBanner({required this.entries});

  /// True from Dec 15 → Jan 15. Covers the actual turn-of-year plus
  /// a week on either side so a user who opens the app on New Year's
  /// Eve and a user who opens it mid-January both see the review.
  static bool isInWindow() {
    final now = DateTime.now();
    return (now.month == 12 && now.day >= 15) ||
        (now.month == 1 && now.day <= 15);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    // In Jan 1–15, the review shows the *previous* calendar year;
    // in Dec 15–31 it shows the current year.
    final year = now.month == 1 ? now.year - 1 : now.year;
    final stats = YearStats.compute(entries, year);
    if (stats.totalEntries == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => YearInAyatSheet.show(context, stats),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withValues(alpha: 0.18),
                  AppColors.accent.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.accentDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR YEAR IN AYAT · ${stats.year}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              AppColors.accentDark.withValues(alpha: 0.85),
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stats.totalEntries} reflections · '
                        '${stats.surahsEngaged} surahs',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to see your year with the Qur\'an',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color:
                      AppColors.accentDark.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full year-review sheet. Opened from the banner. Walks the user
/// through their year in four calm sections: headline numbers, the
/// surah they kept returning to, tier breakdown, and the deepest
/// reflection.
class YearInAyatSheet extends ConsumerWidget {
  final YearStats stats;

  const YearInAyatSheet({super.key, required this.stats});

  static Future<void> show(BuildContext context, YearStats stats) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => YearInAyatSheet(stats: stats),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final useHijri = ref.watch(useHijriDatesProvider);
    final s = stats;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your year with the Qur\'an',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.year} · ${hijriYearLabel(s.year)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.accentDark.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Share button — captures the year as a PNG card and
              // hands it to the platform share sheet. Only meaningful
              // once the year has at least one reflection; otherwise
              // the card would be empty and a little sad.
              if (s.totalEntries > 0)
                IconButton(
                  tooltip: 'Share your year',
                  onPressed: () => openYearInAyatShareSheet(
                    context: context,
                    gregorianYear: s.year,
                    hijriYearLabel: hijriYearLabel(s.year),
                    totalReflections: s.totalEntries,
                    activeDays: s.activeDays,
                    longestStreak: s.longestStreak,
                    surahsEngaged: s.surahsEngaged,
                    topSurahNumber: s.topSurahNumber,
                    topSurahCount: s.topSurahCount,
                  ),
                  icon: Icon(
                    Icons.ios_share_rounded,
                    size: 20,
                    color: AppColors.accentDark.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Headline numbers ──
          Row(
            children: [
              Expanded(
                child: _YearStat(
                  value: '${s.totalEntries}',
                  label: 'reflections',
                ),
              ),
              Expanded(
                child: _YearStat(
                  value: '${s.activeDays}',
                  label: 'days with the Qur\'an',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _YearStat(
                  value: '${s.longestStreak}',
                  label: s.longestStreak == 1
                      ? 'longest streak'
                      : 'day longest streak',
                ),
              ),
              Expanded(
                child: _YearStat(
                  value: '${s.surahsEngaged}',
                  label: 'surahs engaged',
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Container(
            height: 0.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 24),

          // ── Most-returned-to surah ──
          if (s.topSurahNumber > 0 && s.topSurahCount > 0) ...[
            Text(
              'THE SURAH YOU KEPT RETURNING TO',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              kSurahNames[s.topSurahNumber],
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.accentDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${s.topSurahCount} ${s.topSurahCount == 1 ? "reflection" : "reflections"} this year',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 0.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 24),
          ],

          // ── Tier breakdown ──
          Text(
            'HOW YOU ENGAGED',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 12),
          _TierRow(
              label: 'Acknowledged',
              count: s.tier1,
              icon: Icons.favorite_border_rounded,
              color: AppColors.tier1),
          const SizedBox(height: 8),
          _TierRow(
              label: 'Responded',
              count: s.tier2,
              icon: Icons.chat_bubble_outline_rounded,
              color: AppColors.tier2),
          const SizedBox(height: 8),
          _TierRow(
              label: 'Reflected',
              count: s.tier3,
              icon: Icons.auto_awesome_outlined,
              color: AppColors.tier3),

          // ── Deepest reflection highlight ──
          if (s.deepest != null &&
              (s.deepest!.responseText?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 32),
            Container(
              height: 0.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 24),
            Text(
              'YOUR DEEPEST REFLECTION',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                s.deepest!.responseText!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${surahNameFromKey(s.deepest!.verseKey)} ${s.deepest!.verseKey} · '
              '${formatShortDate(s.deepest!.completedAt, useHijri: useHijri)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],

          const SizedBox(height: 40),
          Center(
            child: Text(
              'May these be written in your scales.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.accentDark.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearStat extends StatelessWidget {
  final String value;
  final String label;

  const _YearStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _TierRow({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet showing every pinned reflection. Opened from the
/// "+ N more pinned" footer in `_PinnedSection` when there are more
/// pins than fit in the compact top-of-journal view.
class _PinnedSheet extends StatelessWidget {
  final List<JournalEntry> entries;
  final String lang;
  final ValueChanged<JournalEntry> onTap;

  const _PinnedSheet({
    required this.entries,
    required this.lang,
    required this.onTap,
  });

  static Future<void> show(
    BuildContext context,
    List<JournalEntry> entries,
    String lang,
    ValueChanged<JournalEntry> onTap,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => _PinnedSheet(
          entries: entries,
          lang: lang,
          onTap: (e) {
            Navigator.of(context).pop();
            onTap(e);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: AppColors.accentDark.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pinned reflections',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    entries.length == 1
                        ? '1'
                        : '${entries.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: entries.length,
            separatorBuilder: (context, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final e = entries[i];
              return GestureDetector(
                onTap: () => onTap(e),
                child: _JournalCard(
                  entry: e,
                  lang: lang,
                  showDate: true,
                  collapsed: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
