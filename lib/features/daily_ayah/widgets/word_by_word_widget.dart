import 'package:flutter/material.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/word.dart';
import 'package:tadabbur/core/providers/app_providers.dart';

class WordByWordWidget extends ConsumerWidget {
  final List<Word> words;
  final bool visible;

  const WordByWordWidget({
    super.key,
    required this.words,
    this.visible = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    // Filter out end markers, keep only actual words
    final actualWords =
        words.where((w) => w.charTypeName == 'word').toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brandInk.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate_rounded,
                size: 18,
                color: theme.brandInkAt(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                AppTranslations.get('word_by_word', lang),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 4,
            runSpacing: 12,
            textDirection: TextDirection.rtl,
            alignment: WrapAlignment.center,
            children: actualWords.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;
              return _WordCard(word: word)
                  .animate()
                  .fadeIn(
                    duration: 400.ms,
                    delay: (100 * index).ms,
                    curve: Curves.easeOut,
                  )
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 400.ms,
                    delay: (100 * index).ms,
                  );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }
}

class _WordCard extends StatelessWidget {
  final Word word;

  const _WordCard({required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word.textUthmani,
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 20,
              color: theme.colorScheme.onSurface,
              height: 1.6,
            ),
          ),
          if (word.transliteration != null) ...[
            const SizedBox(height: 2),
            Text(
              word.transliteration!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.inkAt(0.4),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              word.translation ?? '',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
