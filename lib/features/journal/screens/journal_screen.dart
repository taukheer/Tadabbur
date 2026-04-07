import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(journalProvider);
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    List<JournalEntry> entries = _searchQuery.isEmpty
        ? allEntries
        : ref.read(journalProvider.notifier).search(_searchQuery);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('your_journal'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            allEntries.isEmpty
                                ? t('spiritual_auto')
                                : '${allEntries.length} ${allEntries.length == 1 ? t('entry') : t('entries')}  ·  ${t('spiritual_auto')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search
            if (allEntries.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: t('search_reflections'),
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

            // Empty state
            if (entries.isEmpty)
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
                          allEntries.isEmpty
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
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: GestureDetector(
                        onTap: () => _openEntryDetail(context, entries[index], ref),
                        child: _JournalCard(entry: entries[index], lang: lang),
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

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

void _openEntryDetail(BuildContext context, JournalEntry entry, WidgetRef ref) {
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
              width: 36, height: 4,
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

            // Arabic text — full, not truncated
            Text(
              entry.arabicText,
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

            // Translation — full
            Text(
              '"${entry.translationText}"',
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            if (entry.responseText != null && entry.responseText!.isNotEmpty) ...[
              const SizedBox(height: 24),

              Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),

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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
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

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;
  final String lang;

  const _JournalCard({required this.entry, required this.lang});

  String get _tierLabel {
    switch (entry.tier) {
      case ReflectionTier.acknowledge:
        return AppTranslations.get('acknowledged', lang);
      case ReflectionTier.respond:
        return AppTranslations.get('responded', lang);
      case ReflectionTier.reflect:
        return AppTranslations.get('reflected', lang);
    }
  }

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

  String _surahName(String verseKey) {
    final surah = int.tryParse(verseKey.split(':').first) ?? 1;
    // Simple mapping for Al-Fatiha MVP
    const names = {
      1: 'Al-Fatiha',
      2: 'Al-Baqarah',
      3: 'Ali Imran',
    };
    return names[surah] ?? 'Surah $surah';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        DateFormat('EEE, MMM d').format(entry.completedAt);

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
          // Date + tier
          Row(
            children: [
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
                size: 14,
                color: AppColors.warmBrown.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                _tierLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warmBrown.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Arabic text — centered
          Center(
            child: Text(
              entry.arabicText,
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
              '"${entry.translationText}"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                '${_surahName(entry.verseKey)}  ·  ${entry.verseKey}',
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

            // Prompt in amber
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

            // User's words
            Text(
              entry.responseText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
