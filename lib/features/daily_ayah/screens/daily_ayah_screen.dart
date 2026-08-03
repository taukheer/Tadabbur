import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/constants/app_constants.dart';
import 'package:tadabbur/core/layout/breakpoints.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/models/tafsir_option.dart';
import 'package:tadabbur/core/widgets/golden_stroke.dart';
import 'package:tadabbur/core/widgets/sajdah_glyph.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/core/theme/arabic_fonts.dart';
import 'package:tadabbur/features/daily_ayah/providers/daily_ayah_provider.dart';
import 'package:tadabbur/features/daily_ayah/widgets/ayah_skeleton.dart';
import 'package:tadabbur/features/daily_ayah/widgets/share_card.dart';
import 'package:tadabbur/features/feelings/screens/feelings_screen.dart';
import 'package:tadabbur/features/reflection/screens/reflection_screen.dart';

class DailyAyahScreen extends ConsumerStatefulWidget {
  const DailyAyahScreen({super.key});

  @override
  ConsumerState<DailyAyahScreen> createState() => _DailyAyahScreenState();
}

class _DailyAyahScreenState extends ConsumerState<DailyAyahScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When the ayah switches (user advanced to the next verse), snap
    // the scroll back to the top. Otherwise the new verse loads at
    // whatever scroll position the previous one was left at — usually
    // the bottom of the page where the "I felt this" button lives —
    // which buries the new verse below the fold.
    ref.listen<String?>(
      dailyAyahProvider.select((s) => s.ayah?.verseKey),
      (previous, next) {
        if (previous != null && next != null && previous != next) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        }
      },
    );

    final state = ref.watch(dailyAyahProvider);
    final progress = ref.watch(userProgressProvider);
    final profile = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    // The loaded branch assumes state.ayah is non-null. The notifier
    // only emits loadingState=loaded after a successful fetch (or a
    // cache restore that produced an Ayah), so this should always hold —
    // but guarding here keeps the screen from throwing if a future
    // refactor lets the state drift into an intermediate shape.
    final ayah = state.ayah;
    final isDay0 = progress.totalAyatCompleted == 0;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: state.loadingState == AyahLoadingState.loading
            ? const AyahSkeleton()
            : state.loadingState == AyahLoadingState.error || ayah == null
                ? _buildError(theme, state.errorMessage, ref)
                : Stack(
                    children: [
                      _buildContent(context, ref, state, ayah, progress,
                          profile, theme),
                      // Always-visible identity bar on day-1+. On day 0
                      // the welcome card teaches the ritual and the
                      // in-flow surah pill carries identity, so the
                      // sticky bar would compete; we suppress it there.
                      if (!isDay0)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildStickyIdentityBar(
                              state, ayah, theme,
                              theme.brightness == Brightness.dark),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStickyIdentityBar(
    DailyAyahState state,
    Ayah ayah,
    ThemeData theme,
    bool isDark,
  ) {
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);
    return Container(
      // Fully opaque so the hijri row + Today chip + bookmark scrolling
      // behind don't ghost through and create a "double-layered" look.
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '${_surahName(ayah.surahNumber)}  •  ${t('ayah')} ${ayah.ayahNumber}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.warmInk,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.revelationType != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: state.isMakki
                    ? AppColors.makkiSurface
                    : AppColors.madaniSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.isMakki ? 'Makki' : 'Madani',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: state.isMakki
                      ? AppColors.makkiText
                      : AppColors.madaniText,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme, String? message, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final headline = AppTranslations.get('could_not_load', lang);
    final detail = (message != null && message.trim().isNotEmpty) ? message : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.inkAt(0.7))),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.inkAt(0.45))),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(dailyAyahProvider.notifier).loadDailyAyah(),
              child: Text(AppTranslations.get('try_again', lang)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DailyAyahState state,
    Ayah ayah,
    dynamic progress,
    UserProfile? profile,
    ThemeData theme,
  ) {
    final lang = ref.watch(languageProvider);
    final editorial = state.editorial;
    final words = state.words.where((w) => w.charTypeName == 'word').toList();
    final isSalahMotivated = profile?.isSalahMotivated ?? false;
    final arabicFontSize = ref.watch(arabicFontSizeProvider);
    final arabicFontId = ref.watch(arabicFontProvider);
    String t(String key) => AppTranslations.get(key, lang);

    // Day-0 = user has never completed an ayah. We strip optional
    // depth content (theme hook, scholar reflection, Read more link)
    // on day-0 so the primary green button is visible without scroll —
    // the welcome card tells the user "tap the green button" and the
    // button must actually be reachable above the fold.
    final isDay0 = progress.totalAyatCompleted == 0;

    // Audio URL is resolved by the provider via the QF recitations endpoint,
    // with a verses.quran.com fallback when the recitations call fails.
    final liveAudioUrl = state.audioUrl;

    // Only show thematic hook when we have editorial content (verified, not guessed)
    final ayahTheme = editorial != null
        ? _detectTheme(ayah.translationText ?? '')
            ?? _detectTheme(editorial.historicalContext)
            ?? _detectTheme(editorial.scholarReflection)
        : null;

    // Check if returning after a gap (no guilt, just welcome back)
    final lastCompleted = progress.lastCompletedAt as DateTime?;
    final daysSinceLastVisit = lastCompleted != null
        ? DateTime.now().difference(lastCompleted).inDays
        : 0;

    // Yesterday's journal entry for continuity
    final journal = ref.watch(journalProvider);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayEntry = journal.where((e) =>
        e.completedAt.year == yesterday.year &&
        e.completedAt.month == yesterday.month &&
        e.completedAt.day == yesterday.day).toList();
    final hasYesterdayReflection = yesterdayEntry.isNotEmpty;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Top spacer doubles as room for the always-visible sticky
          // identity bar on day-1+. Without the extra inset, the hijri
          // row would render underneath the sticky and clip at top.
          SizedBox(height: isDay0 ? 16 : 56),

          // === NOTIFICATION PERMISSION BANNER ===
          // Renders only when the OS reports notifications are off,
          // giving users who skipped/denied the permission prompt a
          // one-tap recovery path. Self-hides once permission is
          // granted (provider re-evaluates).
          const _NotificationPermissionBanner(),

          // === IDENTITY + HIJRI + DAY COUNTER + BOOKMARK ===
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Row(
              children: [
                // Hijri date on the leading edge — the Islamic calendar
                // is the canonical date for a Quran app; showing it
                // first signals that intent before anything else.
                Text(
                  _hijriToday(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.inkAt(0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                // "Today" framing — always present so new users see the
                // daily-ritual context on first paint, even before
                // they've completed an ayah. Once they have a streak,
                // the day number rides along as " · Day N".
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.brandInk.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    progress.totalAyatCompleted > 0
                        ? '${t('today_label')}  •  ${t('day_label')} ${progress.dayNumber}'
                        : t('today_label'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.brandInkAt(0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _BookmarkButton(
                  // Keying on verseKey forces a fresh Element when the
                  // user advances to the next ayah, so the bookmark
                  // state can't leak across verses.
                  key: ValueKey('bookmark-${ayah.verseKey}'),
                  verseKey: ayah.verseKey,
                  arabicText: ayah.textUthmani,
                  translationText: ayah.translationText ?? '',
                ),
              ],
            ),
          ),

          // === DAY-0 INSTRUCTIONAL CARD — embedded teaching, no
          // onboarding flow. Shown only on the very first session so
          // newcomers (especially non-tech-savvy users) immediately
          // understand the ritual without a tutorial they'd skip. Auto-
          // disappears once they complete their first ayah.
          if (progress.totalAyatCompleted == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: _DayZeroWelcomeCard(theme: theme, t: t)
                  .animate()
                  .fadeIn(duration: 700.ms, delay: 200.ms)
                  .slideY(begin: -0.05, end: 0, duration: 700.ms),
            ),

          // === YESTERDAY'S CONTINUITY — "you reflected on..." ===
          if (hasYesterdayReflection && !state.todayCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 4, 32, 8),
              child: Text(
                t('welcome_back'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.inkAt(0.3),
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ).animate().fadeIn(duration: 600.ms),
            ),

          // === WELCOME BACK (after longer gap, no guilt) ===
          if (daysSinceLastVisit >= 3 && progress.totalAyatCompleted > 0 && !hasYesterdayReflection)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 4, 32, 8),
              child: Text(
                t('welcome_back'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.brandInkAt(0.4),
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(duration: 800.ms),
            ),

          // Spacer before the in-flow surah identity pill — only on
          // day 0 where the pill renders below the welcome card. On
          // day-1+ the always-visible sticky bar at the top is the
          // identity and the in-flow pill would just duplicate it.
          if (isDay0) const SizedBox(height: 12),

          // === SURAH IDENTITY PILL — name · ayah · juz · revelation type ===
          // Rendered in-flow on day 0 only (paired with the welcome
          // card). On day-1+, the sticky bar at the top of the screen
          // provides the same identity always-visible.
          if (isDay0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.warmSurfaceInk,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_surahName(ayah.surahNumber)}  •  ${t('ayah')} ${ayah.ayahNumber}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.warmInk,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      fontSize: 12,
                    ),
                  ),
                  if (ayah.juzNumber != null) ...[
                    Text(
                      '  •  Juz ${ayah.juzNumber}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.warmInkAt(0.6),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (state.revelationType != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: state.isMakki
                            ? AppColors.makkiSurface
                            : AppColors.madaniSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        state.isMakki ? 'Makki' : 'Madani',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: state.isMakki
                              ? AppColors.makkiText
                              : AppColors.madaniText,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 500.ms),

          // === SAJDAH (kept separate — it's a verse-level marker, not identity) ===
          if (state.isSajdahVerse) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.sajdahSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SajdahGlyph(
                    size: 11,
                    color: AppColors.sajdahText,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Sajdah',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.sajdahText,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          ],

          // === THEMATIC HOOK — creates instant curiosity ===
          // Hidden on day 0 to keep the screen short enough that the
          // primary green button is visible without scrolling.
          if (ayahTheme != null && !isDay0) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                '${t('today_ayah_about')} $ayahTheme',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.brandInkAt(0.45),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
          ],

          const SizedBox(height: 32),

          // === THE AYAH — full screen presence ===
          // Gentle right-to-left entrance that mirrors Arabic reading
          // direction. A ShaderMask wipe + scroll-parallax combo was
          // tried before and caused a vertical jump on first load; this
          // is a pure horizontal slide + fade so layout never shifts.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              ayah.textUthmani,
              key: ValueKey('ayah-${ayah.verseKey}'),
              locale: const Locale('ar'),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: ArabicFonts.getStyle(
                arabicFontId,
                fontSize: ayah.textUthmani.length > 100
                    ? arabicFontSize * 0.65
                    : ayah.textUthmani.length > 50
                        ? arabicFontSize * 0.8
                        : arabicFontSize,
              ).copyWith(color: theme.colorScheme.onSurface),
            ),
          )
              .animate(key: ValueKey('ayah-anim-${ayah.verseKey}'))
              .fadeIn(duration: 900.ms, delay: 150.ms, curve: Curves.easeOut)
              .slideX(
                begin: 0.08,
                end: 0,
                duration: 900.ms,
                delay: 150.ms,
                curve: Curves.easeOutCubic,
              ),

          // === GOLDEN STROKE — ink-drying moment after reflection ===
          // Keyed on verse so it replays once per newly-completed ayah,
          // not on every rebuild within the same verse.
          if (state.todayCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GoldenStroke(
                key: ValueKey('stroke-${ayah.verseKey}'),
                color: AppColors.accent,
                width: 180,
              ),
            ),

          // === TRANSLITERATION (optional) ===
          if (ref.watch(showTransliterationProvider) && words.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
              child: Text(
                ref.watch(ayahTransliterationProvider),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.inkAt(0.35),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  height: 1.6,
                  letterSpacing: 0.3,
                ),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

          const SizedBox(height: 20),

          // === TRANSLATION — the access point for most users, given
          // full body weight + high contrast. Italic / heavy quote marks
          // removed: translation should speak at a normal voice, not
          // whisper from behind decoration.
          if (ayah.translationText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                ayah.translationText!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.inkAt(0.82),
                  height: 1.55,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 400.ms),

          const SizedBox(height: 14),

          // === LISTEN — slim outlined button pre-completion. After
          // the user has marked the ayah complete, this collapses into
          // a small icon-only row (with Read more + Share) so the
          // completion celebration below is the visual center, not a
          // menu of next actions.
          if (state.todayCompleted)
            _PostCompletionIconRow(
              audioUrl: liveAudioUrl,
              ayah: ayah,
              dayNumber: progress.dayNumber,
              lang: lang,
              onTafsir: () =>
                  _showTafsir(context, ref, ayah.verseKey, lang),
            ).animate().fadeIn(duration: 500.ms, delay: 500.ms)
          else
            _AudioButton(audioUrl: liveAudioUrl, ref: ref)
                .animate()
                .fadeIn(duration: 500.ms, delay: 500.ms),

          // === SALAH CONNECTION ===
          if (isSalahMotivated && ayah.surahNumber == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
              child: Text(
                t('recite_every'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.brandInkAt(0.4),
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 14),

          // === CURATED INSIGHT — only when we have an editorial layer
          // with a reflective one-liner. Raw QF tafsir summaries are
          // chain-of-narrator content (isnad) and read as scholarly
          // footnotes — they don't belong on the daily landing screen.
          // The full tafsir is one tap away behind "Read more" below.
          // Suppressed on day 0 so the screen is short enough for the
          // primary green button to land above the fold.
          if (!isDay0 &&
              editorial != null &&
              editorial.scholarReflection.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                _shortMeaning(editorial.scholarReflection),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.inkAt(0.55),
                  height: 1.55,
                  fontSize: 13,
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            if (editorial.scholarName.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  'Drawing on ${editorial.scholarName}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.inkAt(0.28),
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 750.ms),
            ],
            const SizedBox(height: 8),
          ],

          // === TAFSIR ON DEMAND — guide, not lecture ===
          // Hidden on day 0 — depth content can be discovered after the
          // user has completed their first reflection. The day-0 path
          // is intentionally minimal: read → reflect → tap.
          // Also hidden post-completion, since the icon row above
          // already includes a Read-more entry point.
          if (!isDay0 && !state.todayCompleted)
            TextButton.icon(
              onPressed: () => _showTafsir(context, ref, ayah.verseKey, lang),
              icon: Icon(
                Icons.auto_stories_outlined,
                size: 15,
                color: theme.brandInkAt(0.4),
              ),
              label: Text(
                t('read_more'),
                style: TextStyle(
                  color: theme.brandInkAt(0.4),
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 700.ms),

          const SizedBox(height: 14),

          // === REFLECTION CTA — the core product ===
          if (!state.todayCompleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _InlineReflection(
                ayah: ayah,
                editorial: editorial,
                profile: profile,
                onFullReflection: () => _openReflection(context, state, editorial),
              ),
            )
          else ...[
            _CompletedState(
              totalAyat: progress.totalAyatCompleted,
              dayNumber: progress.dayNumber,
              surahNumber: ayah.surahNumber,
              ayahNumber: ayah.ayahNumber,
              isSalahMotivated: isSalahMotivated,
              theme: theme,
            ),
            // Share was here. Moved up into the icon row that appears
            // right under the verse on completion — keeps all the
            // re-engagement affordances together as light icons rather
            // than scattered text buttons below the celebration.

            // "Need guidance for how you feel?" was here. Removed —
            // it's a separate discovery feature (find-ayah-by-emotion)
            // and stapling it to the completion screen as a 5th CTA
            // turned the finish line into a "now what?" menu. The
            // feelings entry point should live somewhere the user
            // discovers it as its own mode, not appended to the daily
            // ritual.
          ],

          // === EXPLORE BY FEELING — discovery entry ===
          // Quiet text link visible day 1+ only. Placed at the very
          // bottom of the page so it doesn't compete with today's
          // verse + reflection, but stays discoverable for users who
          // want to browse the Quran emotionally outside the daily
          // ritual. Suppressed on day 0 to keep the welcome path
          // minimal and focused on first completion.
          if (!isDay0) ...[
            const SizedBox(height: 28),
            Center(
              child: TextButton.icon(
                onPressed: () => _openFeelingMode(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                icon: Icon(
                  Icons.favorite_border_rounded,
                  size: 14,
                  color: theme.warmInkAt(0.6),
                ),
                label: Text(
                  t('explore_feeling'),
                  style: TextStyle(
                    color: theme.warmInkAt(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],

          // === BOTTOM SPACING ===
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  static String _surahName(int num) =>
      num > 0 && num <= 114 ? kSurahNames[num] : 'Surah $num';

  /// Extract first sentence only — keep it light.
  static String _shortMeaning(String context) {
    final trimmed = context.trim();
    if (trimmed.isEmpty) return trimmed;
    final sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.isNotEmpty ? sentences.first : trimmed;
  }

  /// Push the full-screen tafsir route. Previously this opened a
  /// modal bottom sheet at 60% height which (a) wasted 40% of the
  /// viewport, (b) had no visible barrier, and (c) had no obvious
  /// close affordance. A reading view should occupy the full screen
  /// — every serious reading app does this (Apple Books, Kindle,
  /// Notion). Back arrow in the AppBar handles dismissal.
  static void _showTafsir(
    BuildContext context,
    WidgetRef ref,
    String verseKey,
    String lang,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => TafsirScreen(
          verseKey: verseKey,
          lang: lang,
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  /// Format today's Hijri date as e.g. "15 Ramaḍān 1447".
  /// Uses the `hijri` package's English month names; the diacritic on
  /// Ramaḍān is left untouched so the name reads correctly.
  static String _hijriToday() {
    final h = HijriCalendar.now();
    return '${h.hDay} ${h.longMonthName} ${h.hYear}';
  }

  static String? _detectTheme(String translation) {
    final t = translation.toLowerCase();
    if (t.contains('mercy') || t.contains('merciful') || t.contains('compassion') || t.contains('rahm')) return 'mercy';
    if (t.contains('patience') || t.contains('patient') || t.contains('steadfast') || t.contains('persever')) return 'patience';
    if (t.contains('trust') || t.contains('rely') || t.contains('tawakkul') || t.contains('depend')) return 'trust in Allah';
    if (t.contains('prayer') || t.contains('worship') || t.contains('prostrat') || t.contains('salah')) return 'worship';
    if (t.contains('grateful') || t.contains('thank') || t.contains('praise') || t.contains('hamd')) return 'gratitude';
    if (t.contains('forgiv') || t.contains('repent') || t.contains('pardon') || t.contains('tawbah')) return 'forgiveness';
    if (t.contains('taqwa') || t.contains('god-conscious') || t.contains('piety')) return 'God-consciousness';
    if (t.contains('guide') || t.contains('guidance') || t.contains('path') || t.contains('straight')) return 'guidance';
    if (t.contains('just') || t.contains('justice') || t.contains('fair') || t.contains('equit')) return 'justice';
    if (t.contains('death') || t.contains('hereafter') || t.contains('judgment') || t.contains('resurrection') || t.contains('apocal')) return 'the hereafter';
    if (t.contains('provision') || t.contains('sustain') || t.contains('rizq') || t.contains('wealth')) return 'provision';
    if (t.contains('knowledge') || t.contains('wisdom') || t.contains('understand') || t.contains('reflect')) return 'reflection';
    if (t.contains('love') || t.contains('beloved')) return 'love';
    if (t.contains('family') || t.contains('parent') || t.contains('child') || t.contains('orphan')) return 'family';
    if (t.contains('creation') || t.contains('created') || t.contains('heaven') || t.contains('earth') || t.contains('sign')) return 'creation';
    if (t.contains('faith') || t.contains('belief') || t.contains('believ') || t.contains('iman')) return 'faith';
    if (t.contains('truth') || t.contains('sinceri') || t.contains('honest')) return 'truth';
    if (t.contains('unity') || t.contains('ummah') || t.contains('community') || t.contains('together')) return 'unity';
    if (t.contains('prophet') || t.contains('messenger') || t.contains('moses') || t.contains('jesus') || t.contains('abraham')) return 'the prophets';
    if (t.contains('covenant') || t.contains('promise') || t.contains('contract') || t.contains('pledge')) return 'covenant';
    if (t.contains('struggle') || t.contains('trial') || t.contains('test') || t.contains('hardship')) return 'trials';
    if (t.contains('light') || t.contains('darkness') || t.contains('illumin')) return 'light and guidance';
    if (t.contains('power') || t.contains('sovereign') || t.contains('dominion') || t.contains('authority')) return 'divine sovereignty';
    if (t.contains('obey') || t.contains('obedien') || t.contains('submit') || t.contains('command')) return 'obedience';
    if (t.contains('hypocri') || t.contains('disbeliev') || t.contains('deny') || t.contains('reject')) return 'sincerity';
    if (t.contains('reward') || t.contains('paradise') || t.contains('garden') || t.contains('punish') || t.contains('fire')) return 'accountability';
    if (t.contains('moral') || t.contains('character') || t.contains('noble') || t.contains('virtue')) return 'character';
    if (t.contains('rememb') || t.contains('dhikr') || t.contains('mindful')) return 'remembrance';
    return null;
  }

  /// Browse ayat by feeling — a separate discovery mode (not part of
  /// the daily ritual). Entry point lives at the bottom of the Today
  /// screen for day-1+ users so it's reachable without competing with
  /// the day's verse + reflection above.
  void _openFeelingMode(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const FeelingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _openReflection(BuildContext context, DailyAyahState state, dynamic editorial) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReflectionScreen(ayah: state.ayah!, editorial: editorial),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// === INLINE REFLECTION — the question lives on the same page ===

class _InlineReflection extends ConsumerStatefulWidget {
  final dynamic ayah;
  final dynamic editorial;
  final UserProfile? profile;
  final VoidCallback onFullReflection;

  const _InlineReflection({
    required this.ayah,
    required this.editorial,
    this.profile,
    required this.onFullReflection,
  });

  @override
  ConsumerState<_InlineReflection> createState() => _InlineReflectionState();
}

class _InlineReflectionState extends ConsumerState<_InlineReflection> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journal = ref.watch(journalProvider);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);
    // Day-0 = the user has never completed an ayah. We use this flag
    // to (a) relabel the primary button to a more explicit verb and
    // (b) pulse it so the first-time eye finds the destination.
    final isDay0 = ref.watch(userProgressProvider).totalAyatCompleted == 0;
    // Rotate between light *question* prompts when no editorial content.
    // 'sit_moment' was removed from the rotation — it duplicated the
    // primary button ("I felt this") and made the card read as two
    // labels for one action.
    final lightPrompts = [
      t('what_stood_out'),
      t('what_stayed'),
    ];
    final fallbackPrompt =
        lightPrompts[widget.ayah.ayahNumber % lightPrompts.length];
    // Day-0 always uses the short fallback question. Editorial
    // `tier2Prompt` is a deep contemplative paragraph (3-4 lines) and
    // bloats the reflection card so the green button drops below the
    // fold on the very screen meant to teach the user where to tap.
    // Depth content unlocks from day 1.
    final prompt = isDay0
        ? fallbackPrompt
        : (widget.editorial?.tier2Prompt ?? fallbackPrompt);

    // Show a previous reflection only:
    // - If there are 5+ written entries (meaningful history)
    // - Only on the first ayah of the day (not on every continue)
    // - Pick one from at least 3 days ago (not recent)
    final writtenEntries = journal
        .where((e) =>
            e.responseText != null &&
            e.responseText!.isNotEmpty &&
            DateTime.now().difference(e.completedAt).inDays >= 3)
        .toList();
    // Gated on !isDay0 too — if a returning user wipes local progress
    // but their journal cloud-syncs back, we'd otherwise show "you
    // reflected earlier…" on the very screen that's framed as a fresh
    // start. The day-0 narrative ("you're new!") must not be broken by
    // restored memory cards.
    final showMemory = !isDay0 &&
        writtenEntries.length >= 3 &&
        journal.length >= 5 &&
        (journal.length % 5 == 0); // Show every 5th ayah
    final previousEntry = showMemory
        ? writtenEntries[DateTime.now().day % writtenEntries.length]
        : null;

    return Column(
      children: [
        // === PREVIOUS ENTRY MEMORY (after Day 3) ===
        if (previousEntry != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.warmSurfaceLightInk,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.warmBorderInk.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Text(
                  t('earlier_paused'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.warmInkAt(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  previousEntry.responseText!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.inkAt(0.5),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
        ],

        // === REFLECTION CTA — borderless so it reads as a continuation
        // of the verse, not a separate "follow-up" surface. Keeps a
        // whisper of green background to mark it as the destination.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: theme.brandInk.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.inkPrimary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Primary action. Day-0 users get:
              //   1. The clearer verb "Mark today complete" — "I felt
              //      this" is evocative but vague to a first-timer.
              //   2. A slow scale pulse drawing the eye here. After
              //      first completion, the pulse stops (no anxiety
              //      ambient motion for repeat users) and the label
              //      reverts to "I felt this".
              _PulsingPrimaryButton(
                enabled: isDay0,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _acknowledge,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brandFill,
                      foregroundColor: theme.onBrandInk,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isDay0 ? t('mark_today_complete') : t('i_felt_this'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Secondary — softer, for those who want to go deeper
              TextButton(
                onPressed: widget.onFullReflection,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  t('write_one_line'),
                  style: TextStyle(
                    // Deliberately quiet, but not invisible: 40% of the
                    // dark emerald reads fine on cream and disappears
                    // entirely on the navy, so dark mode gets a higher
                    // floor.
                    color: theme.brandInk.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.75 : 0.4,
                    ),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
      ],
    );
  }

  Future<void> _acknowledge() async {
    setState(() => _saving = true);
    try {
      final entry = JournalEntry(
        id: const Uuid().v4(),
        verseKey: widget.ayah.verseKey,
        arabicText: widget.ayah.textUthmani,
        translationText: widget.ayah.translationText ?? '',
        tier: ReflectionTier.acknowledge,
        completedAt: DateTime.now(),
        streakDay: ref.read(userProgressProvider).totalAyatCompleted + 1,
        // Pin the language the translation was rendered in, so the
        // journal can hide it later if the user switches their app
        // language to something else (an Arabic user shouldn't see a
        // Tamil translation on their own past entries).
        translationLang: ref.read(languageProvider),
      );
      // Haptic feedback — the moment lands
      HapticFeedback.mediumImpact();

      await ref.read(journalProvider.notifier).addEntry(entry);
      await ref
          .read(userProgressProvider.notifier)
          .completeAyah(widget.ayah.verseKey as String);
      ref.read(dailyAyahProvider.notifier).markCompleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }
}

// === WORD BY WORD — collapsible ===

// === TRUNCATED SCHOLAR TEXT — 2-3 sentences with "Read more" ===

class _TruncatedScholarText extends StatefulWidget {
  final String text;
  final String scholarName;
  final ThemeData theme;
  const _TruncatedScholarText({
    required this.text,
    required this.scholarName,
    required this.theme,
  });

  @override
  State<_TruncatedScholarText> createState() => _TruncatedScholarTextState();
}

class _TruncatedScholarTextState extends State<_TruncatedScholarText> {
  bool _expanded = false;

  String get _shortText {
    // Take first 2 sentences
    final sentences = widget.text.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length <= 2) return '"${widget.text}"';
    return '"${sentences.take(2).join(' ')}..."';
  }

  bool get _isLong {
    return widget.text.split(RegExp(r'(?<=[.!?])\s+')).length > 2;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _expanded ? '"${widget.text}"' : _shortText,
          style: widget.theme.textTheme.bodyMedium?.copyWith(
            color: widget.theme.inkAt(0.65),
            height: 1.7,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (_isLong && !_expanded) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Text(
              'Read more',
              style: widget.theme.textTheme.labelSmall?.copyWith(
                color: widget.theme.warmInkAt(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// === AUDIO BUTTON — reactive play/pause ===

class _AudioButton extends ConsumerStatefulWidget {
  final String? audioUrl;
  final WidgetRef ref;

  const _AudioButton({required this.audioUrl, required this.ref});

  @override
  ConsumerState<_AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends ConsumerState<_AudioButton> {
  @override
  Widget build(BuildContext context) {
    if (widget.audioUrl == null) return const SizedBox.shrink();

    final audioService = ref.read(audioServiceProvider);
    final lang = ref.watch(languageProvider);

    return StreamBuilder<PlayerState>(
      stream: audioService.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = playerState?.playing ?? false;
        final isLoading =
            playerState?.processingState == ProcessingState.loading ||
            playerState?.processingState == ProcessingState.buffering;

        final theme = Theme.of(context);
        return Semantics(
          button: true,
          label: isPlaying ? 'Pause Quran recitation' : 'Play Quran recitation',
          child: OutlinedButton.icon(
            onPressed: () => _toggleAudio(audioService, isPlaying),
            icon: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: theme.brandInkAt(0.7),
                    ),
                  )
                : Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 18,
                  ),
            label: Text(isPlaying
                ? AppTranslations.get('pause', lang)
                : AppTranslations.get('listen', lang)),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.brandInkAt(0.8),
              side: BorderSide(
                color: theme.brandInkAt(0.25),
                width: 1,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleAudio(dynamic audioService, bool isPlaying) async {
    if (isPlaying) {
      await audioService.pause();
    } else {
      try {
        await audioService.playAyah(widget.audioUrl!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio failed: $e')),
          );
        }
      }
    }
  }
}

class _CompletedState extends ConsumerWidget {
  final int totalAyat;
  final int dayNumber;
  final int surahNumber;
  final int ayahNumber;
  final bool isSalahMotivated;
  final ThemeData theme;

  const _CompletedState({
    required this.totalAyat,
    required this.dayNumber,
    required this.surahNumber,
    required this.ayahNumber,
    required this.isSalahMotivated,
    required this.theme,
  });

  String _t(String key, WidgetRef ref) =>
      AppTranslations.get(key, ref.watch(languageProvider));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);
    final milestoneKey = _getMilestoneKey(dayNumber, totalAyat);

    // Detect surah completion: current ayah is 1 means we just moved to a new surah
    final currentAyahInProgress =
        int.tryParse(progress.currentVerseKey.split(':').last) ?? 1;
    final currentSurahInProgress =
        int.tryParse(progress.currentVerseKey.split(':').first) ?? 1;
    final justCompletedSurah = currentAyahInProgress == 1 && totalAyat > 0;
    final completedSurahNumber =
        justCompletedSurah ? currentSurahInProgress - 1 : null;
    final completedSurahName = completedSurahNumber != null &&
            completedSurahNumber > 0 &&
            completedSurahNumber <= 114
        ? kSurahNames[completedSurahNumber]
        : null;
    final nextSurahName =
        currentSurahInProgress > 0 && currentSurahInProgress <= 114
            ? kSurahNames[currentSurahInProgress]
            : null;

    // Special: Al-Fatiha completion + salah bridge
    final completedFatiha =
        completedSurahNumber == 1 && isSalahMotivated;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Checkmark was here. Removed — the golden stroke under the
          // Arabic verse already marks "done", and "You showed up
          // today. This counts." carries the celebration in copy.
          // Adding a generic check icon styled like the other circular
          // icon buttons above made it read as a disabled fourth
          // button rather than a celebration mark.
          const SizedBox(height: 12),

          // === SURAH COMPLETION MOMENT ===
          if (justCompletedSurah && completedSurahName != null) ...[
            Text(
              '${_t("completed_surah", ref)} $completedSurahName',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.brandInk,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
            const SizedBox(height: 6),
            Text(
              '$totalAyat ${_t('ayat', ref)} · ${_t('day_label', ref)} $dayNumber',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.inkAt(0.4),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
          ] else ...[
            // Just the warm line — no redundant count
          ],

          const SizedBox(height: 6),

          // Milestone or identity-reinforcing line
          Text(
            milestoneKey != null
                ? _t(milestoneKey, ref)
                : _getIdentityMessage(dayNumber, ref),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.inkAt(0.4),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

          // Day identity
          if (dayNumber > 1) ...[
            const SizedBox(height: 14),
            Text(
              '${_t("day_label", ref)} $dayNumber',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                fontSize: 11,
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
          ],

          // Micro-action
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.warmSurfaceLightInk,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _t('keep_ayah', ref),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.warmInkAt(0.8),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

          // Continuity hint — bumped from alpha 0.2 to 0.4 so the
          // copy is legible on bright screens for older users. 0.2
          // was borderline unreadable in daylight.
          const SizedBox(height: 12),
          Text(
            _t('continue_return', ref),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.inkAt(0.4),
              fontSize: 12,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

          // === RATE PROMPT — 3+ days of practice, emotional framing ===
          // Eligibility (active days, snooze, already-rated) lives in
          // ratePromptProvider; the widget renders only when it says so.
          if (ref.watch(ratePromptProvider))
            _RatePrompt(ref: ref)
                .animate().fadeIn(duration: 500.ms, delay: 700.ms),

          // === SALAH BRIDGE — after completing Al-Fatiha ===
          if (completedFatiha) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.brandInk.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.brandInk.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                'You now understand every word of Al-Fatiha.\n\nYou will say it 17 times today in prayer. Listen for it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.brandInkAt(0.7),
                  height: 1.7,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // === CONTINUE OPTIONS ===
          if (justCompletedSurah && nextSurahName != null) ...[
            // Primary: Continue to next surah
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref.read(dailyAyahProvider.notifier).loadNextAyah();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryButtonFill,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue to $nextSurahName',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            const SizedBox(height: 10),
            // Secondary: Choose different surah
            TextButton(
              onPressed: () => _showSurahPicker(context, ref),
              child: Text(
                _t('choose_different', ref),
                style: TextStyle(
                  color: theme.brandInkAt(0.5),
                  fontSize: 13,
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 700.ms),
          ],
          // Regular advance: a tertiary text link, not a button.
          // The full-prominence "Next ayah →" pill was demoting the
          // daily-ritual thesis ("one verse a day. that's it."). A
          // quiet text link satisfies users who want to read more in
          // one session while keeping the visual hierarchy honest:
          // checkmark + warm copy is the celebration, this is just
          // an opt-in path, not the expected next step.
          if (!justCompletedSurah) ...[
            // The SizedBox(24) above already separates the celebration
            // copy from the continue options. No extra spacer here —
            // adding one stacked ~52px of empty space between "Continue,
            // or return tomorrow." and the Next ayah link.
            TextButton(
              onPressed: () {
                ref.read(dailyAyahProvider.notifier).loadNextAyah();
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                // The translation value already includes the arrow
                // glyph (e.g., "Next ayah →"), so don't append another.
                _t('next_ayah', ref),
                style: TextStyle(
                  color: theme.brandInkAt(0.45),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ).animate().fadeIn(duration: 800.ms),
    );
  }

  void _showSurahPicker(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: kAdaptiveSheetConstraints,      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_t('choose_different', ref),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: 114,
                itemBuilder: (context, index) {
                  final surahNum = index + 1;
                  final name = surahNum <= 114
                      ? kSurahNames[surahNum]
                      : 'Surah $surahNum';
                  return ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: theme.warmSurfaceInk,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('$surahNum',
                            style: const TextStyle(
                              color: Color(0xFF8B7355),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            )),
                      ),
                    ),
                    title: Text(name),
                    onTap: () async {
                      await ref
                          .read(userProgressProvider.notifier)
                          .setStartingVerse('$surahNum:1');
                      ref.read(dailyAyahProvider.notifier).loadNextAyah();
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a translation key for milestone messages, or null.
  static String? _getMilestoneKey(int dayNum, int ayatCount) {
    // Ayat-based milestones
    if (ayatCount == 1) return 'first_ayah_msg';
    if (ayatCount == 50) return 'milestone_50';
    if (ayatCount == 100) return 'milestone_100';

    // Day-based milestones (only on actual calendar days)
    if (dayNum == 3) return 'milestone_day3';
    if (dayNum == 7) return 'milestone_week1';
    if (dayNum == 14) return 'milestone_week2';
    if (dayNum == 30) return 'milestone_day30';
    if (dayNum == 365) return 'milestone_year';

    return null;
  }

  /// Identity-reinforcing messages — not milestones, just quiet affirmations.
  String _getIdentityMessage(int dayNum, WidgetRef ref) {
    if (dayNum <= 1) return _t('showed_up', ref);

    // Vary messages to avoid repetition, reinforce identity
    final messages = [
      _t('showed_up', ref),
      _t('come_back', ref),
    ];
    return messages[dayNum % messages.length];
  }
}

/// Bottom sheet that loads and displays tafsir for a verse. The
/// scholar is picked once in Settings and persisted per language;
/// the sheet itself is a single-focus reading surface — no pickers,
/// no decisions to make every time "Read more" is tapped.
// === TAFSIR SCREEN (full-screen route) ===
//
// Replaces the prior modal bottom sheet. Reading content needs the
// whole viewport — a half-modal made the content feel like an
// interruption rather than a destination. AppBar gives back +
// title + actions slot; the body is a wide reading column with
// classical typography metrics (16px / line-height 1.7).
class TafsirScreen extends ConsumerStatefulWidget {
  final String verseKey;
  final String lang;

  const TafsirScreen({
    super.key,
    required this.verseKey,
    required this.lang,
  });

  @override
  ConsumerState<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends ConsumerState<TafsirScreen> {
  String? _tafsirText;
  String? _error;
  bool _loading = true;
  late TafsirOption _selected;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(localStorageProvider);
    final normalizedLang = widget.lang == 'ar' ? 'ar' : 'en';
    final preferredSlug = storage.getPreferredTafsirSlug(normalizedLang);
    _selected = resolveTafsirFor(normalizedLang, preferredSlug);
    _loadTafsir();
  }

  Future<void> _loadTafsir() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quranApi = ref.read(quranApiProvider);
      final text = await quranApi.getTafsir(_selected.slug, widget.verseKey);
      if (mounted) {
        setState(() {
          // Strip HTML, collapse whitespace, and insert a space when a
          // sentence-ending punctuation lands flush against the next
          // sentence's capital letter (QDC payload sometimes loses the
          // space). Same logic as the prior sheet.
          _tafsirText = text
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAllMapped(
                RegExp(r'([a-z."\x27\)])([A-Z])'),
                (m) => '${m[1]} ${m[2]}',
              )
              .trim();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surahName = surahNameFromKey(widget.verseKey);
    final isRtl = widget.lang == 'ar';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(
          color: theme.inkAt(0.75),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selected.shortNameForHeader(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '$surahName  ·  ${widget.verseKey}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.inkAt(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        titleSpacing: 4,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.brandInk,
                  strokeWidth: 1.6,
                ),
              )
            : _error != null
                ? _buildError(theme)
                : Center(
                    child: ConstrainedBox(
                      // Cap reading column at ~620px on tablets so long
                      // lines don't fatigue the eye. Classical reading
                      // metric (60-75 characters per line).
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Source attribution — small, italic, trust
                            // signal. Tells the user who they're reading
                            // before the words begin.
                            Text(
                              _selected.mufassir,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.inkAt(0.5),
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Divider(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.08),
                              height: 1,
                            ),
                            const SizedBox(height: 20),
                            // Tafsir body. Justify isn't supported well
                            // in Flutter Arabic/English mix, so we leave
                            // alignment as start. Generous line-height
                            // for sustained reading.
                            Text(
                              _tafsirText ?? '',
                              textDirection:
                                  isRtl ? TextDirection.rtl : TextDirection.ltr,
                              textAlign: TextAlign.start,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.inkAt(0.86),
                                height: 1.7,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 36,
              color: theme.inkAt(0.3),
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load tafsir',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.inkAt(0.7),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _loadTafsir,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.brandInk,
                side: BorderSide(
                  color: theme.brandInkAt(0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 10),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// Convenience extension: AppBar title uses a shortened form of the
// `fullName` for cleaner chrome ("Tafsir Ibn Kathir" instead of
// "Tafsir Ibn Kathir (Abridged)").
extension _TafsirOptionDisplay on TafsirOption {
  String shortNameForHeader() {
    final name = fullName;
    final paren = name.indexOf('(');
    if (paren > 0) return name.substring(0, paren).trim();
    return name;
  }
}

class _TafsirSheet extends ConsumerStatefulWidget {
  final String verseKey;
  final String lang;
  final ScrollController scrollController;

  const _TafsirSheet({
    required this.verseKey,
    required this.lang,
    required this.scrollController,
  });

  @override
  ConsumerState<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends ConsumerState<_TafsirSheet> {
  String? _tafsirText;
  String? _error;
  bool _loading = true;
  bool _expanded = false;
  late TafsirOption _selected;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(localStorageProvider);
    final normalizedLang = widget.lang == 'ar' ? 'ar' : 'en';
    final preferredSlug = storage.getPreferredTafsirSlug(normalizedLang);
    _selected = resolveTafsirFor(normalizedLang, preferredSlug);
    _loadTafsir();
  }

  Future<void> _loadTafsir() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quranApi = ref.read(quranApiProvider);
      final text = await quranApi.getTafsir(_selected.slug, widget.verseKey);
      if (mounted) {
        setState(() {
          _tafsirText = text
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAllMapped(
                RegExp(r'([a-z."\x27\)])([A-Z])'),
                (m) => '${m[1]} ${m[2]}',
              )
              .trim();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              Icon(Icons.auto_stories_outlined,
                  size: 20, color: theme.brandInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selected.fullName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.verseKey,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.warmInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Mufassir attribution — small, italic. Transparent about who
          // we're hearing from and builds trust with users who know
          // their scholars. (Scholar chosen via Settings.)
          Text(
            _selected.mufassir,
            textAlign: TextAlign.left,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.inkAt(0.5),
              fontStyle: FontStyle.italic,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFE8E0D4)),
          const SizedBox(height: 8),

          // Content — summarized first, expandable
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1B5E20),
                      strokeWidth: 1.5,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          'Could not load tafsir',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.inkAt(0.4),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: widget.scrollController,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Summary (first ~3-5 sentences)
                              Text(
                                _getSummary(_tafsirText ?? ''),
                                textDirection: widget.lang == 'ar'
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.inkAt(0.7),
                                  height: 1.8,
                                  fontSize: 14,
                                ),
                              ),
                              // Expand/collapse for full tafsir
                              if (!_expanded && _hasMore(_tafsirText ?? '')) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: TextButton(
                                    onPressed: () => setState(() => _expanded = true),
                                    child: Text(
                                      widget.lang == 'ar' ? 'عرض التفسير الكامل' : 'View full tafsir',
                                      style: TextStyle(
                                        color: theme.brandInkAt(0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (_expanded) ...[
                                const SizedBox(height: 12),
                                const Divider(color: Color(0xFFE8E0D4)),
                                const SizedBox(height: 12),
                                Text(
                                  _tafsirText ?? '',
                                  textDirection: widget.lang == 'ar'
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.inkAt(0.6),
                                    height: 1.8,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Extract first 3-5 sentences as summary.
  String _getSummary(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?،؟])\s+'));
    final summary = sentences.take(4).join(' ');
    return summary.length < text.length ? '$summary...' : text;
  }

  /// Check if text has more than the summary.
  bool _hasMore(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?،؟])\s+'));
    return sentences.length > 4;
  }
}

/// Gentle rate prompt — surfaced once the user has practised on three
/// or more distinct days, dismissible, emotional framing.
///
/// This is a soft pre-prompt, not the store sheet itself. Only a "yes"
/// escalates to the OS review flow, so users who wouldn't rate the app
/// never spend one of the platform's limited prompt quotas (StoreKit
/// allows three per year and silently swallows the rest).
///
/// Visibility and persistence live in [ratePromptProvider]; this widget
/// only renders and reports the answer.
class _RatePrompt extends StatelessWidget {
  final WidgetRef ref;
  const _RatePrompt({required this.ref});

  String _t(String key) =>
      AppTranslations.get(key, ref.read(languageProvider));

  /// Escalate to the platform review flow. Falls back to the store
  /// listing when the in-app sheet isn't available (no Play Store on
  /// the device, or StoreKit has already spent its quota this year) so
  /// a user who said yes still lands somewhere they can leave a star.
  Future<void> _requestReview() async {
    final reviewer = InAppReview.instance;
    try {
      if (await reviewer.isAvailable()) {
        await reviewer.requestReview();
      } else {
        // iOS needs the numeric App Store ID to build the listing URL;
        // Android ignores it and derives the Play Store URL from the
        // package name.
        await reviewer.openStoreListing(appStoreId: AppConstants.appStoreId);
      }
    } catch (e) {
      // Never let a store-kit failure surface to the user — they've
      // already given us the goodwill signal, which is what mattered.
      SyncReporter.report('review', e, severity: SyncSeverity.quiet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.warmSurfaceLightInk,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.warmBorderInk.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Text(
              _t('rate_question'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.inkPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(ratePromptProvider.notifier).snooze(),
                    child: Text(
                      _t('rate_not_now'),
                      style: TextStyle(
                        color: theme.inkAt(0.3),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      // Persist "done" first — if StoreKit crashes or
                      // the user force-quits inside the sheet, the
                      // prompt must not come back.
                      await ref.read(ratePromptProvider.notifier).markRated();
                      await _requestReview();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brandFill,
                      foregroundColor: theme.onBrandInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(_t('rate_yes'),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// === BOOKMARK BUTTON — toggle bookmark on current ayah ===

class _BookmarkButton extends ConsumerWidget {
  final String verseKey;
  final String arabicText;
  final String translationText;

  const _BookmarkButton({
    super.key,
    required this.verseKey,
    required this.arabicText,
    required this.translationText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);
    final isBookmarked = bookmarks.any((b) => b.verseKey == verseKey);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: isBookmarked ? 'Remove bookmark' : 'Bookmark this ayah',
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(bookmarkProvider.notifier).toggle(
                verseKey: verseKey,
                arabicText: arabicText,
                translationText: translationText,
              );
          if (!isBookmarked) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Ayah bookmarked'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        // The visible label is just an icon; screen readers need to
        // hear the action + current state explicitly.
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isBookmarked
                ? theme.brandInk.withValues(alpha: 0.08)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isBookmarked
                  ? theme.brandInk.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              // Include verseKey in the key so the AnimatedSwitcher
              // transitions correctly when the user advances to a
              // different ayah (even if the bookmarked-ness happens
              // to match the previous verse's state).
              key: ValueKey('$verseKey-$isBookmarked'),
              size: 20,
              color: isBookmarked
                  ? theme.brandInk
                  : theme.inkAt(0.45),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// === POST-COMPLETION ICON ROW ===
//
// Replaces the inline Listen + Read more + Share entries with a single
// row of icon-only buttons after the user has marked today's ayah
// complete. The verse is already engaged with at this point — these
// become quiet re-engagement affordances rather than primary CTAs.
class _PostCompletionIconRow extends ConsumerWidget {
  final String? audioUrl;
  final Ayah ayah;
  final int dayNumber;
  final String lang;
  final VoidCallback onTafsir;

  const _PostCompletionIconRow({
    required this.audioUrl,
    required this.ayah,
    required this.dayNumber,
    required this.lang,
    required this.onTafsir,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final audioService = ref.read(audioServiceProvider);
    final iconColor = theme.brandInkAt(0.55);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (audioUrl != null)
          StreamBuilder<PlayerState>(
            stream: audioService.playerStateStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data?.playing ?? false;
              return _CircleIconButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: iconColor,
                tooltip: isPlaying
                    ? AppTranslations.get('pause', lang)
                    : AppTranslations.get('listen', lang),
                onTap: () async {
                  if (isPlaying) {
                    await audioService.pause();
                  } else {
                    try {
                      await audioService.playAyah(audioUrl!);
                    } catch (_) {}
                  }
                },
              );
            },
          ),
        const SizedBox(width: 18),
        _CircleIconButton(
          icon: Icons.auto_stories_outlined,
          color: iconColor,
          tooltip: AppTranslations.get('read_more', lang),
          onTap: onTafsir,
        ),
        const SizedBox(width: 18),
        _CircleIconButton(
          icon: Icons.share_outlined,
          color: iconColor,
          tooltip: AppTranslations.get('share_ayah', lang),
          onTap: () => openShareCardSheet(
            context: context,
            ayah: ayah,
            dayNumber: dayNumber,
            lang: lang,
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

// === NOTIFICATION PERMISSION BANNER ===
//
// Soft amber banner that appears on the home screen when the OS
// reports notifications are off for this app. One tap re-prompts for
// permission. If the user previously dismissed the system prompt with
// "don't ask again", the re-prompt is a no-op — in that case we show
// a snackbar pointing them to OS Settings (one screen-tap deeper, but
// at least they know where to go). Hidden completely when permissions
// are granted; non-blocking and doesn't compete with the verse.
class _NotificationPermissionBanner extends ConsumerWidget {
  const _NotificationPermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsEnabledProvider);
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (enabled) {
        if (enabled) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final lang = ref.watch(languageProvider);
        String t(String key) => AppTranslations.get(key, lang);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Material(
            color: AppColors.makkiSurface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final notif = ref.read(notificationServiceProvider);
                final granted = await notif.requestPermission();
                // Refresh state so the banner re-evaluates.
                // ignore: unused_result
                ref.refresh(notificationsEnabledProvider);
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('notif_blocked_open_settings')),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 18,
                      color: AppColors.makkiText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t('notif_banner_tap_to_enable'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.makkiText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.makkiText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// === PULSING PRIMARY BUTTON ===
//
// Wraps the day-0 primary CTA in a slow scale pulse (1.0 → 1.018) that
// loops with reverse, giving the eye a soft "look here" cue without
// the anxiety of a faster animation. Disabled (no pulse, plain pass-
// through) once the user has completed their first ayah so it doesn't
// become ambient motion for repeat users.
class _PulsingPrimaryButton extends StatelessWidget {
  final bool enabled;
  final Widget child;
  const _PulsingPrimaryButton({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.018, 1.018),
          duration: 1400.ms,
          curve: Curves.easeInOut,
        );
  }
}

// === DAY-0 WELCOME CARD ===
//
// Three numbered steps that teach the daily ritual in-flow. Shown only
// on the user's very first session (progress.totalAyatCompleted == 0)
// and disappears forever once they complete their first ayah. No
// jargon, no emoji, no onboarding flow — designed so a 60-year-old
// first-time user understands what to do without reading a manual,
// and a 25-year-old skim-reader can parse it in two seconds.
class _DayZeroWelcomeCard extends StatelessWidget {
  final ThemeData theme;
  final String Function(String) t;

  const _DayZeroWelcomeCard({required this.theme, required this.t});

  @override
  Widget build(BuildContext context) {
    final bg = theme.warmSurfaceLightInk;
    final border = theme.warmBorderInk.withValues(alpha: 0.5);
    final textColor = theme.warmInk;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('how_today_works'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          _Step(num: '1', text: t('step_read_verse'), color: textColor, theme: theme),
          const SizedBox(height: 8),
          _Step(num: '2', text: t('step_sit_with_it'), color: textColor, theme: theme),
          const SizedBox(height: 8),
          _Step(num: '3', text: t('step_tap_green'), color: textColor, theme: theme),
          const SizedBox(height: 12),
          Text(
            t('closing_one_verse'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.65),
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String num;
  final String text;
  final Color color;
  final ThemeData theme;

  const _Step({
    required this.num,
    required this.text,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            num,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
