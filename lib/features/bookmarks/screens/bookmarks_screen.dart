import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          // Pull-to-refresh hydrates bookmarks from QF so a user who
          // added a bookmark on quran.com from another device can
          // swipe down to pull it into the app. Safe to call while
          // already in-flight — the notifier's concurrency guard
          // reuses the running Future.
          onRefresh: () =>
              ref.read(bookmarkProvider.notifier).hydrateFromQF(),
          color: theme.colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Header
              SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('bookmarks'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bookmarks.isEmpty
                          ? t('saved_ayahs')
                          : '${bookmarks.length} ${bookmarks.length == 1 ? t('ayah_saved') : t('ayahs_saved')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Empty state
            if (bookmarks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border_rounded,
                          size: 36,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t('no_bookmarks'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('bookmark_hint'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.2),
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
                        onTap: () =>
                            _openBookmarkDetail(context, bookmarks[index], ref),
                        child: _BookmarkCard(
                          bookmark: bookmarks[index],
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
                  childCount: bookmarks.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

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
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.35),
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
                '"${bookmark.translationText}"',
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
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

            // Remove bookmark button
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
                  'Remove bookmark',
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

class _BookmarkCard extends ConsumerWidget {
  final Bookmark bookmark;
  final String lang;

  const _BookmarkCard({required this.bookmark, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final arabicFont = ref.watch(arabicFontProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warmSurfaceDark : AppColors.warmSurfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.warmBorderDark.withValues(alpha: 0.3)
              : AppColors.warmBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: verse key + date
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.warmSurface.withValues(alpha: 0.3)
                      : AppColors.warmSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  bookmark.verseKey,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warmBrown,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.bookmark_rounded,
                size: 16,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d').format(bookmark.bookmarkedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Arabic text (truncated)
          Text(
            bookmark.arabicText,
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: arabicFont == 'AmiriQuran' ? 'AmiriQuran' : null,
              fontSize: 20,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              height: 2.0,
            ),
          ),

          if (bookmark.translationText.isNotEmpty) ...[
            const SizedBox(height: 8),

            // Translation (truncated)
            Text(
              bookmark.translationText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
