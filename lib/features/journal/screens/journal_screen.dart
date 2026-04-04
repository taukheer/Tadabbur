import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';

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

    List<JournalEntry> entries = _searchQuery.isEmpty
        ? allEntries
        : ref.read(journalProvider.notifier).search(_searchQuery);

    return Scaffold(
      backgroundColor: const Color(0xFFFEFDF8),
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
                            'Your Journal',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            allEntries.isEmpty
                                ? 'Your spiritual autobiography'
                                : '${allEntries.length} ${allEntries.length == 1 ? 'entry' : 'entries'}  ·  Your spiritual autobiography',
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
                      hintText: 'Search your reflections...',
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
                      fillColor: const Color(0xFFF5F0E8).withValues(alpha: 0.5),
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
                              ? 'Your journal begins with your first ayah.'
                              : 'No reflections match your search.',
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
                      child: _JournalCard(entry: entries[index])
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

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;

  const _JournalCard({required this.entry});

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
          color: const Color(0xFFE8E0D4).withValues(alpha: 0.5),
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
                color: const Color(0xFF8B7355).withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                _tierLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8B7355).withValues(alpha: 0.6),
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
                color: Color(0xFF1A1A1A),
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
                color: const Color(0xFFF5F0E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_surahName(entry.verseKey)}  ·  ${entry.verseKey}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8B7355),
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
                    color: const Color(0xFFB8860B),
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
