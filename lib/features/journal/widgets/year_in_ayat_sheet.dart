import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/features/journal/widgets/year_in_ayat_share_card.dart';

// Date formatting helpers + Hijri year label live in journal_screen.dart
// alongside the rest of the journal’s date utilities, so the imports below
// re-export them through the screens module.
import 'package:tadabbur/features/journal/screens/journal_screen.dart'
    show formatShortDate, hijriYearLabel;

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
class YearInAyatBanner extends ConsumerWidget {
  final List<JournalEntry> entries;

  const YearInAyatBanner({super.key, required this.entries});

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
                        'Tap to see your year with the Quran',
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
                      'Your year with the Quran',
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
                  label: 'days with the Quran',
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
