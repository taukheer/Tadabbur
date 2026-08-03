import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/editorial_content.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';

class UnderstandingLayers extends ConsumerWidget {
  final EditorialContent? editorial;
  final bool showContext;
  final bool showScholar;
  final VoidCallback onToggleContext;
  final VoidCallback onToggleScholar;

  const UnderstandingLayers({
    super.key,
    this.editorial,
    required this.showContext,
    required this.showScholar,
    required this.onToggleContext,
    required this.onToggleScholar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (editorial == null) return const SizedBox.shrink();
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    return Column(
      children: [
        // Historical Context
        _RevealableSection(
          icon: Icons.history_edu_rounded,
          title: t('historical_context'),
          tapToRevealLabel: t('tap_to_reveal'),
          content: editorial!.historicalContext,
          isRevealed: showContext,
          onTap: onToggleContext,
          accentColor: Theme.of(context).statInk,
        ),
        const SizedBox(height: 12),

        // Scholar's Reflection
        _RevealableSection(
          icon: Icons.menu_book_rounded,
          title: t('scholar_reflection'),
          tapToRevealLabel: t('tap_to_reveal'),
          subtitle: editorial!.scholarName,
          content: editorial!.scholarReflection,
          isRevealed: showScholar,
          onTap: onToggleScholar,
          accentColor: Theme.of(context).brandInk,
        ),
      ],
    );
  }
}

class _RevealableSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String tapToRevealLabel;
  final String? subtitle;
  final String content;
  final bool isRevealed;
  final VoidCallback onTap;
  final Color accentColor;

  const _RevealableSection({
    required this.icon,
    required this.title,
    required this.tapToRevealLabel,
    this.subtitle,
    required this.content,
    required this.isRevealed,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRevealed
              ? accentColor.withValues(alpha: 0.06)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRevealed
                ? accentColor.withValues(alpha: 0.15)
                : theme.colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: accentColor.withValues(alpha: 0.8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accentColor,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isRevealed ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            if (isRevealed) ...[
              const SizedBox(height: 16),
              Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.inkAt(0.8),
                  height: 1.7,
                  fontSize: 15,
                ),
              ).animate().fadeIn(duration: 400.ms),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                tapToRevealLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  // "Tap to reveal" is the affordance for the whole
                  // card — it was the faintest text on the screen at
                  // 1.7:1. It stays visually quiet through italics and
                  // size, not through near-invisibility.
                  color: accentColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
