import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);
    final journal = ref.watch(journalProvider);
    final theme = Theme.of(context);

    // Calculate tier breakdown
    final tier1Count =
        journal.where((e) => e.tier == ReflectionTier.acknowledge).length;
    final tier2Count =
        journal.where((e) => e.tier == ReflectionTier.respond).length;
    final tier3Count =
        journal.where((e) => e.tier == ReflectionTier.reflect).length;

    // Parse current surah
    final currentSurah =
        int.tryParse(progress.currentVerseKey.split(':').first) ?? 1;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Journey',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 4),
              Text(
                'Progress is personal. No comparisons.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

              const SizedBox(height: 28),

              // Streak card
              _StreakCard(
                currentStreak: progress.currentStreak,
                longestStreak: progress.longestStreak,
                streakFreezes: progress.streakFreezes,
              ).animate().fadeIn(duration: 500.ms, delay: 150.ms),

              const SizedBox(height: 20),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.auto_stories_rounded,
                      value: '${progress.totalAyatCompleted}',
                      label: 'Ayat Completed',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.edit_note_rounded,
                      value: '${progress.totalReflections}',
                      label: 'Reflections',
                      color: AppColors.statIndigo,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 250.ms),

              const SizedBox(height: 20),

              // Current position
              _PositionCard(
                currentVerseKey: progress.currentVerseKey,
                currentSurah: currentSurah,
              ).animate().fadeIn(duration: 500.ms, delay: 350.ms),

              const SizedBox(height: 20),

              // Reflection breakdown
              _ReflectionBreakdown(
                tier1: tier1Count,
                tier2: tier2Count,
                tier3: tier3Count,
                total: journal.length,
              ).animate().fadeIn(duration: 500.ms, delay: 450.ms),

              const SizedBox(height: 20),

              // Quran progress bar
              _QuranProgressBar(
                totalAyat: progress.totalAyatCompleted,
                totalInQuran: 6236,
              ).animate().fadeIn(duration: 500.ms, delay: 550.ms),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final int streakFreezes;

  const _StreakCard({
    required this.currentStreak,
    required this.longestStreak,
    required this.streakFreezes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Text(
                '$currentStreak',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.streakOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'day streak',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.streakOrange.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniStat(
                label: 'Longest',
                value: '$longestStreak days',
              ),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: AppColors.streakOrange.withValues(alpha: 0.15),
              ),
              _MiniStat(
                label: 'Freezes',
                value: '$streakFreezes available',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.streakOrange.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.streakOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final String currentVerseKey;
  final int currentSurah;

  const _PositionCard({
    required this.currentVerseKey,
    required this.currentSurah,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.place_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Position',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Surah $currentSurah, Ayah ${currentVerseKey.split(':').last}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currentVerseKey,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionBreakdown extends StatelessWidget {
  final int tier1;
  final int tier2;
  final int tier3;
  final int total;

  const _ReflectionBreakdown({
    required this.tier1,
    required this.tier2,
    required this.tier3,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reflection Breakdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _TierRow(
            label: 'Acknowledged',
            count: tier1,
            total: total,
            color: AppColors.info,
            icon: Icons.favorite_rounded,
          ),
          const SizedBox(height: 10),
          _TierRow(
            label: 'Responded',
            count: tier2,
            total: total,
            color: AppColors.tierAmber,
            icon: Icons.short_text_rounded,
          ),
          const SizedBox(height: 10),
          _TierRow(
            label: 'Reflected',
            count: tier3,
            total: total,
            color: AppColors.primary,
            icon: Icons.edit_note_rounded,
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _TierRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: color.withValues(alpha: 0.1),
              color: color,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuranProgressBar extends StatelessWidget {
  final int totalAyat;
  final int totalInQuran;

  const _QuranProgressBar({
    required this.totalAyat,
    required this.totalInQuran,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = totalAyat / totalInQuran;
    final percentage = (fraction * 100).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quran Journey',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '$totalAyat / $totalInQuran ayat',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.08),
              color: AppColors.primary,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage% — one ayah at a time',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primary.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
