import 'package:flutter/material.dart';

import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/features/journal/screens/journal_screen.dart'
    show JournalCard;

/// Bottom sheet showing every pinned reflection. Opened from the
/// "+ N more pinned" footer in `_PinnedSection` when there are more
/// pins than fit in the compact top-of-journal view.
class PinnedSheet extends StatelessWidget {
  final List<JournalEntry> entries;
  final String lang;
  final ValueChanged<JournalEntry> onTap;

  const PinnedSheet({
    super.key,
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
        builder: (_, controller) => PinnedSheet(
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
                child: JournalCard(
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
