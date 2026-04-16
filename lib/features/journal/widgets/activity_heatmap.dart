import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';

/// GitHub-style activity heatmap showing the user's Quran practice.
///
/// Each calendar day is a cell. Cells are colored by the number of
/// reflections written that day (none / light / medium / dark) so the
/// grid carries real signal, not just a binary "showed up or didn't".
/// Data source is local ([journalProvider] + progress) so the view
/// works for every auth type without a network call.
///
/// The visible window adapts to the user's history — new users see a
/// tight 12-week view, long-time users see up to 20. Prevents the
/// "mostly empty grid" problem on day 1 that makes the card feel like
/// a reminder of what you haven't done yet.
class ActivityHeatmap extends ConsumerStatefulWidget {
  const ActivityHeatmap({super.key});

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  /// The date the user most recently tapped on, if any. Drives the
  /// inline detail line under the header. Auto-clears after a short
  /// timeout so the streak summary comes back.
  DateTime? _tappedDate;
  int _tappedCount = 0;
  Timer? _tapTimer;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _onCellTap(DateTime date, int count, {required bool isFuture}) {
    if (isFuture) return;
    HapticFeedback.selectionClick();
    _tapTimer?.cancel();
    setState(() {
      _tappedDate = date;
      _tappedCount = count;
    });
    _tapTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _tappedDate = null;
        _tappedCount = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider);
    final progress = ref.watch(userProgressProvider);
    final theme = Theme.of(context);

    // Count reflections per calendar day (local time) so we can map
    // the counts to heatmap intensity levels. Using a Map<DateTime,int>
    // instead of a simple Set lets us show "2 reflections" on a day
    // the user reflected on multiple verses.
    final dayCounts = <DateTime, int>{};
    for (final entry in journal) {
      final d = DateTime(
        entry.completedAt.year,
        entry.completedAt.month,
        entry.completedAt.day,
      );
      dayCounts[d] = (dayCounts[d] ?? 0) + 1;
    }
    // Progress signal: user completed today's ayah even if they
    // haven't written a reflection. Ensures the cell lights up.
    if (progress.lastCompletedAt != null) {
      final d = progress.lastCompletedAt!;
      final date = DateTime(d.year, d.month, d.day);
      dayCounts[date] = (dayCounts[date] ?? 0).clamp(1, 999);
      // If already has a reflection count, keep that (don't override).
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff30 = today.subtract(const Duration(days: 30));
    final last30Active =
        dayCounts.keys.where((d) => !d.isBefore(cutoff30)).length;

    // Adaptive layout: cell size AND week-count scale with user
    // tenure so the grid always looks ~70% populated. A day-3 user
    // gets a 4-week view with chunky 16px cells (their three filled
    // squares anchor the composition); a day-200 user gets the full
    // GitHub-style sweep.
    final firstActivity = _earliestActivity(dayCounts);
    final daysActive = firstActivity == null
        ? 0
        : today.difference(firstActivity).inDays + 1;
    final layout = _HeatmapLayout.forDaysActive(daysActive);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.warmBorder.withValues(alpha: 0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Your practice',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              // "3 of 30 days" reads naturally as "active 3 out of
               // the last 30 days". The old "3 / 30 days" slash form
               // was ambiguous — streak? month target? days remaining?
              _StatChip(
                label: '$last30Active of 30',
                sublabel: 'days',
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Detail line: either the tapped-cell info (fades in for 3s)
          // or the streak summary. Swap via AnimatedSwitcher so the
          // transition feels intentional, not jumpy.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _tappedDate != null
                ? _DetailLine(
                    key: ValueKey('tap-${_tappedDate!.toIso8601String()}'),
                    date: _tappedDate!,
                    count: _tappedCount,
                  )
                : _StreakLine(
                    key: const ValueKey('streak'),
                    currentStreak: progress.currentStreak,
                    longestStreak: progress.longestStreak,
                  ),
          ),
          const SizedBox(height: 14),
          // Under two weeks of practice we show a horizontal week
          // strip instead of a sparse grid — heatmaps read well when
          // there's a shape to show; a 3-day journey has no shape yet,
          // so a "this week" row with date numbers and day letters
          // earns its space. The grid takes over at tier 2 when the
          // user has enough history to make a heatmap narrative.
          if (layout.isWeekStrip)
            _WeekStrip(
              today: today,
              dayCounts: dayCounts,
              onCellTap: _onCellTap,
            )
          else
            _Grid(
              layout: layout,
              today: today,
              dayCounts: dayCounts,
              onCellTap: _onCellTap,
            ),
          if (layout.showLegend) ...[
            const SizedBox(height: 12),
            _Legend(),
          ],
          const SizedBox(height: 18),
          // Subtle divider so the journey band reads as a second,
          // complementary story below the cadence view.
          Container(
            height: 0.5,
            color: AppColors.warmBorder.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          _QuranJourneyBand(
            currentVerseKey: progress.currentVerseKey,
            totalAyatCompleted: progress.totalAyatCompleted,
          ),
        ],
      ),
    );
  }
}

class _StreakLine extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  const _StreakLine({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _copyFor(currentStreak, longestStreak),
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppColors.warmBrown.withValues(alpha: 0.6),
        fontSize: 11,
        height: 1.4,
      ),
    );
  }

  /// Identity-driven streak copy. Replaces the clinical
  /// "1 day streak · longest 1" with language that rewards the user
  /// for who they are rather than what they've tallied. Milestone tiers
  /// match the notification service so the whole app tells one story.
  static String _copyFor(int current, int longest) {
    if (current == 0) {
      if (longest == 0) {
        return 'Light your first square. Today\'s the day.';
      }
      return 'The thread slipped. Come back — it\'s still yours.';
    }
    if (current == 1) {
      return longest > 1
          ? 'Back again. Day 1 of the next stretch.'
          : 'Day 1. The thread begins.';
    }
    if (current < 7) {
      return 'Day $current. The rhythm is forming.';
    }
    if (current == 7) {
      return 'One week. You\'re someone who returns.';
    }
    if (current < 14) {
      return 'Day $current · longest $longest. Keep the thread.';
    }
    if (current < 30) {
      return 'Day $current. Every square is your hand raised.';
    }
    if (current < 100) {
      return 'Day $current. This is who you are now.';
    }
    return 'Day $current. A quiet, deliberate life.';
  }
}

class _DetailLine extends StatelessWidget {
  final DateTime date;
  final int count;
  const _DetailLine({super.key, required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _formatDate(date);
    final right = count == 0
        ? 'no entry'
        : count == 1
            ? '1 reflection'
            : '$count reflections';
    return Text(
      '$label · $right',
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppColors.primary.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }
}

/// Horizontal "this week" strip for users under two weeks of practice.
///
/// Shows Mon–Sun cells with day letters above and date numbers inside.
/// Filled cells use the same color ramp as the heatmap so the
/// visualizations feel continuous when a user crosses the tier
/// boundary into the full grid.
class _WeekStrip extends StatelessWidget {
  final DateTime today;
  final Map<DateTime, int> dayCounts;
  final void Function(DateTime date, int count, {required bool isFuture})
      onCellTap;

  const _WeekStrip({
    required this.today,
    required this.dayCounts,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final offset = today.weekday - 1; // Monday = 0
    final weekStart = today.subtract(Duration(days: offset));
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var d = 0; d < 7; d++)
          _WeekStripCell(
            date: weekStart.add(Duration(days: d)),
            today: today,
            dayLabel: dayLabels[d],
            count: dayCounts[DateTime(
                  weekStart.add(Duration(days: d)).year,
                  weekStart.add(Duration(days: d)).month,
                  weekStart.add(Duration(days: d)).day,
                )] ??
                0,
            onTap: onCellTap,
          ),
      ],
    );
  }
}

class _WeekStripCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final String dayLabel;
  final int count;
  final void Function(DateTime date, int count, {required bool isFuture})
      onTap;

  const _WeekStripCell({
    required this.date,
    required this.today,
    required this.dayLabel,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayDate = DateTime(date.year, date.month, date.day);
    final isFuture = dayDate.isAfter(today);
    final isToday = dayDate == today;
    final bg = _colorForCount(count: count, isFuture: isFuture);

    // Text color: white on filled cells for legibility, muted warm
    // brown on empty/future cells.
    final Color textColor;
    if (isFuture) {
      textColor = AppColors.warmBrown.withValues(alpha: 0.3);
    } else if (count == 0) {
      textColor = AppColors.warmBrown.withValues(alpha: 0.55);
    } else {
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: () => onTap(dayDate, count, isFuture: isFuture),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dayLabel,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.warmBrown
                  .withValues(alpha: isToday ? 0.85 : 0.5),
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(
                      color: AppColors.accent.withValues(alpha: 0.9),
                      width: 1.5,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Heatmap grid + month labels.
///
/// Month labels are rendered in a [Stack] so each one is positioned by
/// absolute x offset rather than competing with column widths. This
/// prevents the "Dec → De/c" wrapping that happens when a 3-letter
/// label is clamped to a single cell width.
class _Grid extends StatelessWidget {
  final _HeatmapLayout layout;
  final DateTime today;
  final Map<DateTime, int> dayCounts;
  final void Function(DateTime date, int count, {required bool isFuture})
      onCellTap;

  const _Grid({
    required this.layout,
    required this.today,
    required this.dayCounts,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final rightmostWeekStart = _weekStart(today);
    final weeks = layout.weeks;
    final columnWidth = layout.columnWidth;
    // Honour the user's system font scale so labels measured here match
    // what the Text widget will actually paint.
    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle = TextStyle(
      color: AppColors.warmBrown.withValues(alpha: 0.55),
      fontSize: 9,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    );

    // Minimum visible gutter between adjacent month labels, in
    // post-scale logical pixels. Small enough to allow dense ranges
    // like Jan/Feb/Mar on a wide layout, large enough to stop labels
    // from visually touching.
    const labelGutter = 6.0;

    double measureLabel(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      return painter.size.width;
    }

    // Build week columns (oldest → newest).
    final dayColumns = <Widget>[];
    // Track where each month first appears so we can position a label
    // aligned to that column's left edge. We also track the trailing
    // edge of the last placed label so adjacent months don't collide
    // into "JanFeb" when a short month lands next to its neighbour.
    final monthLabels = <Widget>[];
    int? lastMonth;
    double lastLabelRight = double.negativeInfinity;

    for (var w = weeks - 1; w >= 0; w--) {
      final weekStart =
          rightmostWeekStart.subtract(Duration(days: 7 * w));

      if (weekStart.month != lastMonth) {
        final columnIndexFromLeft = (weeks - 1 - w);
        final x = columnIndexFromLeft * columnWidth;
        final label = _monthAbbr(weekStart.month);
        final labelWidth = measureLabel(label);
        // Only place a label if its left edge clears the previous
        // label's trailing edge plus the gutter. Driven by measured
        // width rather than a magic 32px so it still holds under
        // larger system font scales and low-DPI tablets where a
        // 3-letter label can widen to 35–40px.
        if (x >= lastLabelRight + labelGutter) {
          monthLabels.add(Positioned(
            left: x,
            top: 0,
            child: Text(label, style: labelStyle),
          ));
          lastLabelRight = x + labelWidth;
        }
        lastMonth = weekStart.month;
      }

      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        final dayDate = DateTime(day.year, day.month, day.day);
        final isFuture = dayDate.isAfter(today);
        final count = dayCounts[dayDate] ?? 0;
        final isToday = dayDate == today;
        cells.add(_Cell(
          size: layout.cellSize,
          gap: layout.cellGap,
          isFuture: isFuture,
          count: count,
          isToday: isToday,
          onTap: () => onCellTap(dayDate, count, isFuture: isFuture),
        ));
      }

      dayColumns.add(Padding(
        padding: EdgeInsets.only(right: layout.cellGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: cells,
        ),
      ));
    }

    // Weekday labels (Mon / Wed / Fri) only on grids wide enough to
    // benefit — a 4-week tier-1 view is too compact for them to help.
    final weekdayColumn = layout.showWeekdayLabels
        ? _buildWeekdayColumn(layout)
        : null;

    final gridContent = SizedBox(
      width: weeks * columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels overlay — Stack lets labels overflow their
          // source column so 3-letter abbreviations don't wrap to two
          // lines.
          SizedBox(
            height: 14,
            child: Stack(
              clipBehavior: Clip.none,
              children: monthLabels,
            ),
          ),
          const SizedBox(height: 4),
          Row(children: dayColumns),
        ],
      ),
    );

    // Narrow grids (tier 1, no weekday labels) are centered in the
    // card so the few filled cells sit at the visual focus point
    // instead of hugging one edge. Wider grids keep the GitHub-style
    // right-anchored scroll so "today" always lands at the right.
    if (weekdayColumn == null) {
      return Center(child: gridContent);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        weekdayColumn,
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            physics: const BouncingScrollPhysics(),
            // Right padding gives today's cell breathing room against
            // the card's right border so the heatmap doesn't feel
            // clipped. Left padding is small — labels align with the
            // column gutter.
            padding: const EdgeInsets.only(right: 6, left: 2),
            child: gridContent,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayColumn(_HeatmapLayout layout) {
    const weekdayLabels = ['Mon', 'Wed', 'Fri'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            height: layout.cellSize,
            margin: EdgeInsets.only(bottom: layout.cellGap),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 8),
            child: (i == 0 || i == 2 || i == 4)
                ? Text(
                    weekdayLabels[i ~/ 2],
                    style: TextStyle(
                      color: AppColors.warmBrown.withValues(alpha: 0.55),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  static DateTime _weekStart(DateTime day) {
    final offset = day.weekday - 1;
    final local = DateTime(day.year, day.month, day.day);
    return local.subtract(Duration(days: offset));
  }

  static String _monthAbbr(int m) {
    const labels = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return labels[m];
  }
}

/// Finds the earliest calendar day the user has activity on. Used to
/// size the heatmap window so new users don't see a mostly-empty grid.
DateTime? _earliestActivity(Map<DateTime, int> dayCounts) {
  if (dayCounts.isEmpty) return null;
  var earliest = dayCounts.keys.first;
  for (final d in dayCounts.keys) {
    if (d.isBefore(earliest)) earliest = d;
  }
  return earliest;
}

/// Per-tier heatmap layout. Cell size AND week count scale with user
/// tenure so the grid always reads as ~70% populated. A day-3 user
/// gets a 4-week view with chunky 16px cells; a year-long veteran
/// gets a 40-week sweep with tight 9px cells.
class _HeatmapLayout {
  final int weeks;
  final double cellSize;
  final double cellGap;
  final bool showWeekdayLabels;
  final bool showLegend;
  final bool isWeekStrip;

  const _HeatmapLayout({
    required this.weeks,
    required this.cellSize,
    required this.cellGap,
    required this.showWeekdayLabels,
    required this.showLegend,
    this.isWeekStrip = false,
  });

  double get columnWidth => cellSize + cellGap;

  static _HeatmapLayout forDaysActive(int daysActive) {
    if (daysActive < 14) {
      // Week strip: 7 chunky cells with day letters + date numbers.
      // Cell dimensions here are unused by the strip itself (it has
      // its own sizing) but are kept for compatibility.
      return const _HeatmapLayout(
        weeks: 1,
        cellSize: 36,
        cellGap: 6,
        showWeekdayLabels: false,
        showLegend: false,
        isWeekStrip: true,
      );
    }
    if (daysActive < 60) {
      return const _HeatmapLayout(
        weeks: 10,
        cellSize: 13,
        cellGap: 3,
        showWeekdayLabels: true,
        showLegend: true,
      );
    }
    if (daysActive < 180) {
      return const _HeatmapLayout(
        weeks: 20,
        cellSize: 11,
        cellGap: 3,
        showWeekdayLabels: true,
        showLegend: true,
      );
    }
    return const _HeatmapLayout(
      weeks: 40,
      cellSize: 9,
      cellGap: 2,
      showWeekdayLabels: true,
      showLegend: true,
    );
  }
}

class _Cell extends StatelessWidget {
  final double size;
  final double gap;
  final bool isFuture;
  final int count;
  final bool isToday;
  final VoidCallback onTap;

  const _Cell({
    required this.size,
    required this.gap,
    required this.isFuture,
    required this.count,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _colorForCount(count: count, isFuture: isFuture);
    // Border radius tracks cell size so chunky cells don't look
    // over-square and tiny cells don't look mushy.
    final radius = (size * 0.22).clamp(2.0, 4.5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.only(bottom: gap),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: isToday
              ? Border.all(
                  color: AppColors.accent.withValues(alpha: 0.8),
                  width: 1,
                )
              : null,
        ),
      ),
    );
  }
}

/// Maps a day's reflection count to a heatmap cell color.
/// Ramp follows the same four stops shown in the [_Legend] — so the
/// visual intensity scale matches the legend (honest mapping, not
/// decorative).
Color _colorForCount({required int count, required bool isFuture}) {
  if (isFuture) {
    return AppColors.warmBorder.withValues(alpha: 0.15);
  }
  if (count == 0) {
    return AppColors.warmBorder.withValues(alpha: 0.3);
  }
  if (count == 1) {
    return AppColors.primary.withValues(alpha: 0.35);
  }
  if (count == 2) {
    return AppColors.primary.withValues(alpha: 0.6);
  }
  return AppColors.primary.withValues(alpha: 0.88);
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Less',
          style: TextStyle(
            fontSize: 9,
            color: AppColors.warmBrown.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: 6),
        _LegendCell(color: _colorForCount(count: 0, isFuture: false)),
        const SizedBox(width: 3),
        _LegendCell(color: _colorForCount(count: 1, isFuture: false)),
        const SizedBox(width: 3),
        _LegendCell(color: _colorForCount(count: 2, isFuture: false)),
        const SizedBox(width: 3),
        _LegendCell(color: _colorForCount(count: 3, isFuture: false)),
        const SizedBox(width: 6),
        Text(
          'More',
          style: TextStyle(
            fontSize: 9,
            color: AppColors.warmBrown.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _LegendCell extends StatelessWidget {
  final Color color;
  const _LegendCell({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// "Your journey through the Qur'an" — a thin progress bar spanning
/// all 6,236 ayat, with a gold pin at the user's current verse.
///
/// Unlike the heatmap (which is about cadence), this band is about
/// *content*: how far through the Qur'an you've walked. It scales
/// from day 1 (a single pin at the far left) to a lifetime of reading
/// (a nearly-full bar) without ever going visually empty — the
/// horizon is always full, and your place on it is always shown.
class _QuranJourneyBand extends StatelessWidget {
  final String currentVerseKey;
  final int totalAyatCompleted;

  const _QuranJourneyBand({
    required this.currentVerseKey,
    required this.totalAyatCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = currentVerseKey.split(':');
    final currentSurah = int.tryParse(parts.first) ?? 1;
    final currentAyah = parts.length > 1
        ? (int.tryParse(parts[1]) ?? 1)
        : 1;

    // Current position as a fraction of the full Qur'an. Clamp to a
    // tiny visible minimum so day-1 users still see the pin on the
    // left edge rather than behind the track.
    final absPosition = absoluteAyahNumber(currentVerseKey);
    final positionFraction = (absPosition / kTotalAyat).clamp(0.0, 1.0);
    final filledFraction =
        (totalAyatCompleted / kTotalAyat).clamp(0.0, 1.0);

    final surahName = surahNameFromKey(currentVerseKey);
    final surahTotal = (currentSurah >= 1 && currentSurah <= 114)
        ? kSurahVerseCounts[currentSurah]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your journey',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const trackHeight = 4.0;
            const pinSize = 11.0;
            // Center the track vertically in a slightly taller box so
            // the pin (bigger than the track) has somewhere to sit.
            const boxHeight = pinSize + 2;

            // Pin position: clamp so it never clips the left/right
            // edges of the container on the extremes.
            final rawPinLeft = width * positionFraction - pinSize / 2;
            final pinLeft = rawPinLeft.clamp(0.0, width - pinSize);

            return SizedBox(
              height: boxHeight,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track
                  Container(
                    width: width,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: AppColors.warmBorder.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                  // Filled portion — total ayat completed so far.
                  Container(
                    width: (width * filledFraction)
                        .clamp(0.0, width),
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                  // Gold pin marking current position.
                  Positioned(
                    left: pinLeft,
                    child: Container(
                      width: pinSize,
                      height: pinSize,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        // Anchor labels: first and last surah of the Qur'an. These
        // don't move — they frame the journey.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Al-Fatiha',
              style: _anchorStyle,
            ),
            Text(
              'An-Nas',
              style: _anchorStyle,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Dynamic status line: where you are, right now.
        Text(
          surahTotal != null
              ? '$surahName · verse $currentAyah of $surahTotal · $totalAyatCompleted ayat touched'
              : '$surahName · $totalAyatCompleted ayat touched',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.primary.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static const _anchorStyle = TextStyle(
    fontSize: 10,
    color: Color(0xFF8B7355), // matches warmBrown at ~0.6 alpha
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sublabel;
  const _StatChip({required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            sublabel,
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
