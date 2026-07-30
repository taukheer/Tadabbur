import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/layout/breakpoints.dart';
import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/reciter.dart';
import 'package:tadabbur/core/models/tafsir_option.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/core/theme/arabic_fonts.dart';
import 'package:tadabbur/features/daily_ayah/providers/daily_ayah_provider.dart';
import 'package:tadabbur/features/journal/screens/journal_screen.dart'
    show hijriYearLabel;
import 'package:tadabbur/features/journal/widgets/year_in_ayat_sheet.dart';

/// Map from a Quran Foundation `recitations.id` (the value used in
/// `/recitations/{id}/by_chapter` audio calls) to the corresponding
/// `cdn.islamic.network` slug we use as the offline‑friendly fallback
/// path. Only Murattal recordings are mapped — Mujawwad and Muallim
/// styles share the same CDN slug as Murattal, which would mislead
/// users into thinking they picked one style when they're hearing
/// another.
const Map<int, String> _qfIdToCdnSlug = {
  7: 'alafasy',              // Mishari Rashid al-`Afasy (Murattal)
  6: 'husary',               // Mahmoud Khalil Al-Husary (Murattal)
  9: 'minshawi',             // Mohamed Siddiq al-Minshawi (Murattal)
  3: 'abdurrahmaansudais',   // Abdur-Rahman as-Sudais (Murattal)
  4: 'shaatree',             // Abu Bakr al-Shatri (Murattal)
  2: 'abdulbasitmurattal',   // AbdulBaset AbdulSamad (Murattal)
};

/// Reciters that exist on `cdn.islamic.network` but aren't published
/// in the QF reciter catalogue. They're appended to the displayed list
/// after the QF‑sourced rows. `qfId` is null so the audio resolver
/// skips the QF call and goes straight to the CDN fallback for these.
///
/// Saud Al-Shuraim was previously pinned to row 1 of the list — but
/// the app's default reciter is Mishari Rashid al-Afasy (defaultReciterId
/// = 7), so the pinned-first row never carried the ✓. That visual
/// mismatch ("why is the second name selected?") was confusing. With
/// Saud in the natural CDN tail, the first row is the actual default,
/// matching user expectation. Discoverability is unaffected since the
/// reciter picker is a bottom sheet — 2 taps reach any reciter.
const List<_ReciterOption> _cdnOnlyReciters = [
  _ReciterOption(
    qfId: null,
    cdnPath: 'muhammadayyoub',
    name: 'Muhammad Ayyub',
    style: 'Murattal',
  ),
  _ReciterOption(
    qfId: null,
    cdnPath: 'saoodshuraym',
    name: 'Saud Al-Shuraim',
    style: 'Murattal',
  ),
];

/// Hardcoded fallback used when the QF reciter catalogue can't be
/// fetched (offline first launch, transient API outage). Mirrors the
/// shape we'd build from QF — just without the live names/styles.
const List<_ReciterOption> _hardcodedReciters = [
  _ReciterOption(qfId: 7, cdnPath: 'alafasy',
      name: 'Mishary Rashid Alafasy', style: 'Murattal'),
  _ReciterOption(qfId: 6, cdnPath: 'husary',
      name: 'Mahmoud Khalil Al-Husary', style: 'Murattal'),
  _ReciterOption(qfId: 9, cdnPath: 'minshawi',
      name: 'Mohamed Siddiq El-Minshawi', style: 'Murattal'),
  _ReciterOption(qfId: 3, cdnPath: 'abdurrahmaansudais',
      name: 'Abdurrahman As-Sudais', style: 'Murattal'),
  _ReciterOption(qfId: 4, cdnPath: 'shaatree',
      name: 'Abu Bakr Ash-Shaatree', style: 'Murattal'),
  _ReciterOption(qfId: 2, cdnPath: 'abdulbasitmurattal',
      name: 'AbdulBaset AbdulSamad', style: 'Murattal'),
  ..._cdnOnlyReciters,
];

class _ReciterOption {
  final int? qfId;
  final String cdnPath;
  final String name;
  final String? style;
  const _ReciterOption({
    required this.qfId,
    required this.cdnPath,
    required this.name,
    this.style,
  });
}

/// Build the reciter list to display in Settings, sourced from the live
/// QF `/audio/reciters` response when available and falling back to the
/// hardcoded catalogue otherwise. Returns `(reciters, fromQf)` so the
/// UI can label the list as live‑sourced when it actually is.
({List<_ReciterOption> reciters, bool fromQf}) _buildReciterList(
  AsyncValue<List<Reciter>> async,
) {
  final qfList = async.maybeWhen(data: (l) => l, orElse: () => null);
  if (qfList == null || qfList.isEmpty) {
    return (reciters: _hardcodedReciters, fromQf: false);
  }

  // Map QF rows to displayable options, keeping only Murattal‑style
  // recordings (the CDN slug match is style‑agnostic — showing the
  // same slug under a "Mujawwad" label would mislead).
  final fromQf = <_ReciterOption>[];
  final seenIds = <int>{};
  for (final r in qfList) {
    final slug = _qfIdToCdnSlug[r.id];
    if (slug == null) continue;
    if (r.style != null && r.style != 'Murattal') continue;
    if (!seenIds.add(r.id)) continue;
    fromQf.add(_ReciterOption(
      qfId: r.id,
      cdnPath: slug,
      name: r.name,
      style: r.style,
    ));
  }

  // Order to match the hardcoded list (Mishary first, etc.) so reciter
  // ordering doesn't change at random when QF reorders its catalogue.
  const order = [7, 6, 9, 3, 4, 2];
  fromQf.sort((a, b) {
    final ai = order.indexOf(a.qfId ?? -1);
    final bi = order.indexOf(b.qfId ?? -1);
    if (ai == -1 && bi == -1) return 0;
    if (ai == -1) return 1;
    if (bi == -1) return -1;
    return ai.compareTo(bi);
  });

  return (
    reciters: [...fromQf, ..._cdnOnlyReciters],
    fromQf: true,
  );
}

const _fontSizes = [
  ('Small', 28.0),
  ('Medium', 36.0),
  ('Large', 44.0),
  ('Extra Large', 52.0),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);
    final storage = ref.watch(localStorageProvider);
    // Watch isLoggedInProvider so sign-out triggers a rebuild of the
    // settings tree — without this, `storage.authType` would still
    // look like quranFoundation until the user leaves and returns to
    // this tab (the provider returning the storage *instance* doesn't
    // notify on internal state mutations).
    ref.watch(isLoggedInProvider);
    final theme = Theme.of(context);

    final currentReciter = ref.watch(reciterPathProvider);
    final currentFontSize = ref.watch(arabicFontSizeProvider);
    final currentFont = ref.watch(arabicFontProvider);
    final currentSurah =
        int.tryParse(progress.currentVerseKey.split(':').first) ?? 1;
    final currentAyah =
        int.tryParse(progress.currentVerseKey.split(':').last) ?? 1;

    // Localization helper: shorthand wrapper around AppTranslations.get
    // so each label below stays a one-liner. Reading languageProvider
    // here makes the whole settings tree re-render on language change.
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('settings'),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),

              const SizedBox(height: 24),

              // === QF IDENTITY — visible sign of the OAuth connection ===
              // Only renders when the user is signed in via QF OAuth
              // *and* we have a profile on hand; for guest/Google/Apple
              // the row is silent so it can't mislead.
              _QfIdentityRow(ref: ref, theme: theme),

              // === ACCOUNT GROUP ===
              // For QF-authenticated users the identity row above
              // already carries the account info, so this block is
              // suppressed there (without the guard, _AccountTile falls
              // back to "Guest mode" on relaunch because authUserProvider
              // resets to null at cold start).
              if (storage.authType != AuthType.quranFoundation) ...[
                _GroupHeader(t('group_account'), theme),
                _SectionLabel(t('section_account'), theme),
                const SizedBox(height: 10),
                _AccountTile(ref: ref, theme: theme),
                const SizedBox(height: 28),
              ],

              // === READING GROUP ===
              // Reading-practice preferences: where you are in the
              // Quran, who recites, which scholar's tafsir loads on
              // tap, and whether transliteration appears. Daily
              // reminder lives here too because it's a reading-cadence
              // setting, not an OS-level toggle.
              _GroupHeader(t('group_reading'), theme),

              _SectionLabel(t('section_current_position'), theme),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showSurahPicker(context, ref, progress),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSurah > 0 && currentSurah <= 114
                                  ? kSurahNames[currentSurah]
                                  : 'Surah $currentSurah',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              t('settings_ayah_completed')
                                  .replaceAll('{ayah}', '$currentAyah')
                                  .replaceAll('{n}',
                                      '${progress.totalAyatCompleted}'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.primary
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        t('change'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.primary
                              .withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // === LANGUAGE ===
              _SectionLabel(t('section_language'), theme),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showLanguagePicker(context, ref, storage),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warmBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLanguages.getByCode(
                                      ref.watch(languageProvider))
                                  .nativeName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              AppLanguages.getByCode(
                                      ref.watch(languageProvider))
                                  .name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(t('change'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.primary
                                .withValues(alpha: 0.5),
                          )),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.primary
                              .withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // === RECITER ===
              // Collapsed to a single tap-to-change row matching the
              // Language pattern. Previously an inline vertical list
              // of 8 reciters took ~480px; the bottom-sheet picker
              // shows the same list in a focused modal.
              _SectionLabel(t('section_reciter'), theme),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final result =
                    _buildReciterList(ref.watch(qfRecitersProvider));
                final current = result.reciters.firstWhere(
                  (r) => r.cdnPath == currentReciter,
                  orElse: () => result.reciters.first,
                );
                return GestureDetector(
                  onTap: () => _showReciterPicker(
                      context, ref, storage, result.reciters, currentReciter),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.warmBorder, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            // "Murattal" subtitle dropped — 7 of 8
                            // reciters in our list are Murattal, so
                            // the label carries no information. Single
                            // name reads cleaner and matches the
                            // Language row pattern next to it.
                            current.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(t('change'),
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.primary
                                    .withValues(alpha: 0.5))),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.primary
                                .withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 28),

              // === DAILY REMINDER ===
              _SectionLabel(t('section_daily_reminder'), theme),
              const SizedBox(height: 10),
              _NotificationTile(ref: ref, theme: theme),

              const SizedBox(height: 28),

              // === TAFSIR SCHOLAR ===
              _SectionLabel(t('section_tafsir_scholar'), theme),
              const SizedBox(height: 10),
              _TafsirScholarTile(theme: theme),

              const SizedBox(height: 28),

              // === TRANSLITERATION ===
              _SectionLabel(t('section_transliteration'), theme),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.warmBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('show_transliteration'),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          Text(t('roman_script_label'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: ref.watch(showTransliterationProvider),
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) async {
                        await storage.setShowTransliteration(v);
                        ref.read(showTransliterationProvider.notifier).state = v;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // === DISPLAY GROUP ===
              // Visual preferences: dates calendar, Arabic font + size.
              // Anything that changes how content looks, not what
              // content is loaded.
              _GroupHeader(t('group_display'), theme),

              // === JOURNAL DATES ===
              _SectionLabel(t('section_journal_dates'), theme),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.warmBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('use_hijri_months'),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          Text(
                            t('hijri_months_hint'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: ref.watch(useHijriDatesProvider),
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) async {
                        await storage.setUseHijriDates(v);
                        ref.read(useHijriDatesProvider.notifier).state = v;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // === ARABIC FONT SIZE ===
              // Slider with discrete divisions instead of a chip group.
              // Four chips in a Wrap looked awkward (2 rows on most
              // phones) and treated size as a category. A slider says
              // "size is continuous and adjustable" which is the
              // accurate mental model.
              _SectionLabel(t('section_arabic_font_size'), theme),
              const SizedBox(height: 8),
              _FontSizeSlider(
                current: currentFontSize,
                fontSizes: _fontSizes,
                onChanged: (size) async {
                  await storage.setArabicFontSize(size);
                  ref.read(arabicFontSizeProvider.notifier).state = size;
                  ref
                      .read(firestoreServiceProvider)
                      .saveUserProfile(arabicFontSize: size)
                      .catchError((Object e) {
                    SyncReporter.report('font-size preference', e,
                        severity: SyncSeverity.quiet);
                  });
                },
                theme: theme,
                t: t,
              ),

              const SizedBox(height: 28),

              // === ARABIC FONT STYLE ===
              _SectionLabel(t('section_arabic_font'), theme),
              const SizedBox(height: 12),
              ...ArabicFonts.options.map((font) => GestureDetector(
                    onTap: () async {
                      await storage.setArabicFont(font.id);
                      ref.read(arabicFontProvider.notifier).state = font.id;
                      ref.read(firestoreServiceProvider)
                          .saveUserProfile(arabicFont: font.id)
                          .catchError((Object e) {
                        SyncReporter.report('font preference', e,
                            severity: SyncSeverity.quiet);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: currentFont == font.id
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: currentFont == font.id
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.warmBorder.withValues(alpha: 0.5),
                          width: currentFont == font.id ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(font.name,
                                        style: TextStyle(
                                          fontWeight: currentFont == font.id
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: currentFont == font.id
                                              ? AppColors.primary
                                              : theme.colorScheme.onSurface,
                                          fontSize: 14,
                                        )),
                                    const SizedBox(width: 8),
                                    Text(t(font.descriptionKey),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.35),
                                          fontSize: 11,
                                        )),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                                  locale: const Locale('ar'),
                                  textDirection: TextDirection.rtl,
                                  style: ArabicFonts.getStyle(font.id, fontSize: 22)
                                      .copyWith(
                                    color: AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (currentFont == font.id)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  )),

              const SizedBox(height: 28),

              // === ABOUT GROUP ===
              // Auxiliary surfaces: yearly summaries, feedback channel,
              // destructive account actions, app credits. Everything
              // the user is unlikely to touch on most visits.
              _GroupHeader(t('group_about'), theme),

              // === YEARLY REVIEWS ===
              // Year-in-Ayat summaries accessible year-round. The
              // journal tab surfaces the banner only during the
              // Dec 15 – Jan 15 window; users who want to revisit an
              // older review or peek mid-year come here.
              _SectionLabel(t('section_year_in_ayat'), theme),
              const SizedBox(height: 10),
              _YearlyReviewsTile(ref: ref, theme: theme),

              const SizedBox(height: 28),

              // === FEEDBACK ===
              _SectionLabel(t('section_feedback'), theme),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showFeedbackSheet(context, ref),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warmBorder, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('send_feedback'),
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                            Text(t('help_improve'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Delete Account — destructive action
              _DeleteAccountButton(theme: theme),

              const SizedBox(height: 40),

              // About — footer with brand statement. Alphas bumped
              // from 0.3 / 0.2 / 0.2 → 0.45 / 0.4 / 0.45 so the
              // "Free for every Muslim. Forever." line is legible on
              // bright phones and reads as an intentional sign-off
              // rather than fine print.
              Center(
                child: Column(
                  children: [
                    Text('Tadabbur', // brand name — not translated
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(t('app_built_on'),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4))),
                    const SizedBox(height: 2),
                    Text(t('app_free_forever'),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom-sheet picker for the active reciter. Mirrors the Language
  /// picker pattern so users learn one selection idiom for all
  /// preference sections. Persists both the QF reciter id (so the QF
  /// recitations API serves the right voice) and the CDN slug (used
  /// by the Islamic Network fallback when QF returns no files).
  void _showReciterPicker(
    BuildContext context,
    WidgetRef ref,
    dynamic storage,
    List<_ReciterOption> reciters,
    String currentReciterPath,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: kAdaptiveSheetConstraints,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  AppTranslations.get('section_reciter',
                      ref.read(languageProvider)),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: reciters.length,
                itemBuilder: (_, i) {
                  final r = reciters[i];
                  final selected = r.cdnPath == currentReciterPath;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () async {
                        await storage.setReciterPath(r.cdnPath);
                        if (r.qfId != null) {
                          await storage.setPreferredReciterId(r.qfId!);
                        }
                        ref.read(reciterPathProvider.notifier).state =
                            r.cdnPath;
                        ref
                            .read(firestoreServiceProvider)
                            .saveUserProfile(reciterPath: r.cdnPath)
                            .catchError((Object e) {
                          SyncReporter.report('reciter preference', e,
                              severity: SyncSeverity.quiet);
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.warmBorder
                                    .withValues(alpha: 0.5),
                            width: selected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: selected
                                          ? AppColors.primary
                                          : theme.colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (r.style != null && r.style!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        r.style!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(
      BuildContext context, WidgetRef ref, dynamic storage) {
    final theme = Theme.of(context);
    final currentLang = ref.read(languageProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: kAdaptiveSheetConstraints,      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
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
              child: Text(
                AppTranslations.get('translation_language', currentLang),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: AppLanguages.supported.length,
                itemBuilder: (context, index) {
                  final lang = AppLanguages.supported[index];
                  final isCurrent = currentLang == lang.code;
                  return ListTile(
                    title: Row(
                      children: [
                        Text(lang.nativeName,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isCurrent
                                  ? AppColors.primary
                                  : null,
                              fontSize: 16,
                            )),
                        const SizedBox(width: 10),
                        Text(lang.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                            )),
                      ],
                    ),
                    subtitle: lang.code != 'ar'
                        ? Text(lang.translationAuthor,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.25),
                              fontSize: 11,
                            ))
                        : null,
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 20)
                        : null,
                    onTap: () async {
                      await storage.setLanguage(lang.code);
                      ref.read(languageProvider.notifier).state = lang.code;
                      ref.read(firestoreServiceProvider)
                          .saveUserProfile(language: lang.code)
                          .catchError((Object e) {
                        SyncReporter.report('language preference', e,
                            severity: SyncSeverity.quiet);
                      });
                      // Reload ayah with new translation
                      ref.invalidate(dailyAyahProvider);
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

  void _showSurahPicker(
      BuildContext context, WidgetRef ref, dynamic progress) {
    final theme = Theme.of(context);
    final lang = ref.read(languageProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: kAdaptiveSheetConstraints,      backgroundColor: theme.colorScheme.surface,
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppTranslations.get('jump_to_surah', lang),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: 114,
                itemBuilder: (context, index) {
                  final surahNum = index + 1;
                  final name = kSurahNames[surahNum];
                  final isCurrent = progress.currentVerseKey
                      .startsWith('$surahNum:');
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primary
                                .withValues(alpha: 0.1)
                            : AppColors.warmSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('$surahNum',
                            style: TextStyle(
                              color: isCurrent
                                  ? AppColors.primary
                                  : AppColors.warmBrown,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            )),
                      ),
                    ),
                    title: Text(name,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isCurrent
                              ? AppColors.primary
                              : null,
                        )),
                    trailing: isCurrent
                        ? const Icon(Icons.place_rounded,
                            color: AppColors.primary, size: 18)
                        : null,
                    onTap: () async {
                      await ref
                          .read(userProgressProvider.notifier)
                          .setStartingVerse('$surahNum:1');
                      ref
                          .read(dailyAyahProvider.notifier)
                          .loadNextAyah();
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

  void _showFeedbackSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: kAdaptiveSheetConstraints,      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _FeedbackSheet(ref: ref),
      ),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  final WidgetRef ref;
  const _FeedbackSheet({required this.ref});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _controller = TextEditingController();
  String _category = 'general';
  bool _sending = false;
  bool _sent = false;

  static const _categories = [
    ('general', 'General', Icons.chat_bubble_outline_rounded),
    ('bug', 'Bug Report', Icons.bug_report_outlined),
    ('feature', 'Feature Request', Icons.lightbulb_outline_rounded),
    ('content', 'Content Issue', Icons.menu_book_outlined),
  ];

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);

    try {
      final storage = widget.ref.read(localStorageProvider);
      // Pull whatever identity we have so the feedback email isn't
      // anonymous. Order of preference for `display_name`/`email`:
      //   1. Google / Apple Sign-In (authUserProvider) — has them directly.
      //   2. Quran Foundation OAuth (qfProfileProvider) — uses our
      //      derived displayName + raw email/username.
      //   3. Guest mode — leaves both fields null; the email template
      //      just shows "(guest)" which is honest.
      final authUser = widget.ref.read(authUserProvider);
      final qfProfile = widget.ref.read(qfProfileProvider);
      final authType = storage.authType.name; // guest/google/quranFoundation

      String? displayName = authUser?.name;
      String? email = authUser?.email;
      if ((displayName == null || displayName.isEmpty) && qfProfile != null) {
        displayName = qfProfile.displayName;
      }
      if ((email == null || email.isEmpty) && qfProfile?.email != null) {
        email = qfProfile!.email;
      }
      final qfUsername = qfProfile?.username;

      // Writes to /feedback in Firestore. The collection's security
      // rule requires `request.auth != null` + a size cap; anonymous
      // Firebase Auth (wired in main.dart) satisfies the auth check
      // for every install. Viewable in Firebase Console at
      // tadabbur-492408 → Firestore → feedback. The `onFeedbackCreated`
      // Cloud Function emails the founder address with whichever
      // identity fields we managed to capture below.
      await FirebaseFirestore.instance.collection('feedback').add({
        'category': _category,
        'message': _controller.text.trim(),
        'user_id': storage.userId ?? 'guest',
        'auth_type': authType,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (qfUsername != null && qfUsername.isNotEmpty)
          'qf_username': qfUsername,
        'language': storage.language,
        'verse_key': storage.getProgress()?.currentVerseKey ?? '1:1',
        'created_at': FieldValue.serverTimestamp(),
        'platform': Theme.of(context).platform.name,
      });

      setState(() {
        _sent = true;
        _sending = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        final lang = widget.ref.read(languageProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppTranslations.get('feedback_send_failed', lang),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = widget.ref.read(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    if (_sent) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 56),
            const SizedBox(height: 20),
            Text(t('feedback_thanks_title'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 8),
            Text(t('feedback_thanks_subtitle'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                )),
            const SizedBox(height: 48),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(t('send_feedback'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
          Text(t('feedback_we_read'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              )),
          const SizedBox(height: 20),

          // Category chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final (id, label, icon) = c;
              final selected = _category == id;
              return GestureDetector(
                onTap: () => setState(() => _category = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.warmBorder,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16,
                          color: selected
                              ? AppColors.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? AppColors.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Text field
          TextField(
            controller: _controller,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            // The Send button's enabled state is derived from the
            // controller's current text. Without this setState, the
            // button only re-evaluates when something else triggers
            // a rebuild (e.g. tapping a category chip) — which makes
            // it look like Send is broken until the user pokes at
            // the chips.
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tell us what you think...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.warmBorder, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.warmBorder, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _sending || _controller.text.trim().isEmpty ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                    )
                  : Text(t('feedback_send_btn'),
                      style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _SectionLabel(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ));
  }
}

/// Slider control for Arabic font size. Snaps to the four canonical
/// sizes (Small → Extra Large) via `divisions: 3`. Visual tick marks +
/// labels underneath communicate the discrete choices, while the
/// slider gesture itself feels continuous to drag.
class _FontSizeSlider extends StatelessWidget {
  final double current;
  final List<(String, double)> fontSizes;
  final ValueChanged<double> onChanged;
  final ThemeData theme;
  final String Function(String) t;

  const _FontSizeSlider({
    required this.current,
    required this.fontSizes,
    required this.onChanged,
    required this.theme,
    required this.t,
  });

  String _localizedLabel(String label) {
    final key = switch (label) {
      'Small' => 'font_size_small',
      'Medium' => 'font_size_medium',
      'Large' => 'font_size_large',
      'Extra Large' => 'font_size_extra_large',
      _ => label,
    };
    return t(key);
  }

  @override
  Widget build(BuildContext context) {
    // Clamp to the discrete bucket; closest match by absolute diff.
    int index = 0;
    double bestDiff = double.infinity;
    for (var i = 0; i < fontSizes.length; i++) {
      final d = (fontSizes[i].$2 - current).abs();
      if (d < bestDiff) {
        bestDiff = d;
        index = i;
      }
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warmBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live preview of the selected size in Arabic — drag the
          // slider and watch the same Bismillah scale. The current
          // size name renders next to the preview so middle positions
          // (Medium / Large) are nameable, not just inferred.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'بِسْمِ ٱللَّهِ',
                  locale: const Locale('ar'),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: fontSizes[index].$2 * 0.6,
                    color: AppColors.primary.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _localizedLabel(fontSizes[index].$1),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor:
                  AppColors.primary.withValues(alpha: 0.15),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 9),
              tickMarkShape:
                  const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
              activeTickMarkColor: Colors.white,
              inactiveTickMarkColor:
                  AppColors.primary.withValues(alpha: 0.4),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: index.toDouble(),
              min: 0,
              max: (fontSizes.length - 1).toDouble(),
              divisions: fontSizes.length - 1,
              onChanged: (v) {
                final i = v.round();
                if (i != index) {
                  onChanged(fontSizes[i].$2);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _localizedLabel(fontSizes.first.$1),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                Text(
                  _localizedLabel(fontSizes.last.$1),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-level group header — one of four ("Account", "Reading",
/// "Display", "About"). Bigger and bolder than [_SectionLabel] so the
/// settings page reads as four visual blocks with section sub-rows
/// inside each, rather than a flat list of 13 same-level sections.
/// A short hairline divider sits underneath the label as a soft
/// horizontal anchor.
class _GroupHeader extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _GroupHeader(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;

  const _NotificationTile({required this.ref, required this.theme});

  @override
  Widget build(BuildContext context) {
    final notifService = ref.watch(notificationServiceProvider);
    final scheduled = notifService.getScheduledTime();
    final isEnabled = scheduled != null;
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);
    final timeStr = isEnabled
        ? TimeOfDay(hour: scheduled.hour, minute: scheduled.minute)
            .format(context)
        : 'Not set';

    // OS-level permission state. When false AND we have a scheduled
    // time, the alarm is armed internally but the OS will silently
    // suppress the notification — surface a warning row so the user
    // knows their reminder won't actually fire.
    final osEnabled = ref
        .watch(notificationsEnabledProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);
    final showOsBlockedWarning = isEnabled && !osEnabled;

    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickTime(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isEnabled
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.warmBorder,
                width: isEnabled ? 1 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: isEnabled
                      ? AppColors.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnabled
                            ? t('settings_daily_reminder_at')
                                .replaceAll('{time}', timeStr)
                            : t('set_daily_reminder'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isEnabled
                              ? AppColors.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        isEnabled
                            ? t('settings_ayah_waiting')
                            : t('set_daily_reminder_hint'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
                          fontStyle:
                              isEnabled ? FontStyle.italic : FontStyle.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  isEnabled ? t('change') : t('set_time'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        // OS-level "blocked" warning. The internal alarm is armed but
        // the OS will drop the notification at fire time — explain
        // that and offer a one-tap re-request. If the system prompt
        // returns denied again, fall back to a snackbar pointing the
        // user to OS Settings.
        if (showOsBlockedWarning) ...[
          const SizedBox(height: 8),
          Material(
            color: AppColors.makkiSurface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final granted = await notifService.requestPermission();
                // ignore: unused_result
                ref.refresh(notificationsEnabledProvider);
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('notif_blocked_snack')),
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.makkiText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('notif_blocked_title'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.makkiText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t('notif_blocked_subtitle'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.makkiText.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.makkiText.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final notifService = ref.read(notificationServiceProvider);
    final current = notifService.getScheduledTime();

    final picked = await showTimePicker(
      context: context,
      initialTime: current != null
          ? TimeOfDay(hour: current.hour, minute: current.minute)
          : const TimeOfDay(hour: 5, minute: 30),
      helpText: 'When should we remind you?',
    );

    if (picked != null) {
      final granted = await notifService.requestPermission();
      if (granted) {
        await notifService.scheduleDailyNotification(
          hour: picked.hour,
          minute: picked.minute,
        );
        ref.invalidate(notificationServiceProvider);
      }
    }
  }
}

class _AccountTile extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;

  const _AccountTile({required this.ref, required this.theme});

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authUserProvider);
    final isGuest = authUser == null;
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    if (isGuest) {
      return GestureDetector(
        onTap: () async {
          debugPrint('[Button] Settings: Sign in tapped');
          // Use the Quran Foundation OAuth flow — this populates the
          // User API access token so bookmarks, reflections, streaks
          // and activity-days sync to QF. The deep-link handler in
          // main.dart + app_router /oauth/callback finishes the flow
          // and updates authUserProvider when the browser returns.
          final qfAuth = ref.read(qfAuthServiceProvider);
          await qfAuth.launchLogin();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.warmBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('account_guest_mode'),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    Text(t('sign_in_journey'),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.35),
                            fontSize: 12)),
                  ],
                ),
              ),
              Text(t('sign_in_button'),
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primary.withValues(alpha: 0.6))),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: authUser.photoUrl != null
                ? NetworkImage(authUser.photoUrl!)
                : null,
            child: authUser.photoUrl == null
                ? Text(
                    authUser.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authUser.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    )),
                Text(authUser.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                        fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
              ref.read(authUserProvider.notifier).state = null;
            },
            child: Text(t('sign_out_button'),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.35))),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Delete Account — permanent account + data deletion
// ═══════════════════════════════════════════════════════════════

class _DeleteAccountButton extends ConsumerStatefulWidget {
  final ThemeData theme;
  const _DeleteAccountButton({required this.theme});

  @override
  ConsumerState<_DeleteAccountButton> createState() =>
      _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends ConsumerState<_DeleteAccountButton> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The "Account" sub-label that used to sit above the Delete
        // button was removed — it added a label level inside the
        // About group without earning its weight. The red destructive
        // styling on the button speaks for itself.
        GestureDetector(
          onTap: _deleting ? null : _confirmDelete,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('delete_account'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color:
                              theme.colorScheme.error.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('delete_account_hint'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_deleting)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          theme.colorScheme.error.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final lang = ref.read(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(t('delete_account_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _bullet(theme, 'Your account and profile'),
            _bullet(theme, 'All your reflections and journal'),
            _bullet(theme, 'All bookmarked ayahs'),
            _bullet(theme, 'Reading progress and streak'),
            _bullet(theme, 'All app preferences'),
            const SizedBox(height: 16),
            Text(
              'This cannot be undone.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(t('delete_forever')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.deleteAccount();

      // Reset providers
      if (mounted) {
        ref.read(authUserProvider.notifier).state = null;
        ref.read(isLoggedInProvider.notifier).state = false;
        ref.read(hasOnboardedProvider.notifier).state = false;

        // Navigate back to onboarding
        Navigator.of(context).popUntil((route) => route.isFirst);

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('account_deleted')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        final lang = ref.read(languageProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppTranslations.get('delete_account_failed', lang)}: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: theme.textTheme.bodySmall),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Identity row that makes the QF OAuth connection visible.
///
/// Settings is the natural home for "who am I signed in as" —
/// without this row, the only sign of OAuth was that bookmarks and
/// notes synced. Making identity visible reframes the app from "uses
/// QF auth" to "a window into your quran.com life." Renders as a
/// small, unobtrusive badge at the top of Settings; hidden entirely
/// for guest/Google/Apple sign-ins where the QF profile wouldn't
/// exist.
class _QfIdentityRow extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final ThemeData theme;

  const _QfIdentityRow({required this.ref, required this.theme});

  @override
  ConsumerState<_QfIdentityRow> createState() => _QfIdentityRowState();
}

class _QfIdentityRowState extends ConsumerState<_QfIdentityRow> {
  @override
  void initState() {
    super.initState();
    // Opportunistic refresh on screen open — if the cache is stale
    // (rename, new avatar, etc.) the row updates without user action.
    // No-op for non-QF users; no-op if the API call fails.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(qfProfileProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(localStorageProvider);
    if (storage.authType != AuthType.quranFoundation) {
      return const SizedBox.shrink();
    }
    final profile = ref.watch(qfProfileProvider);
    final name = profile?.displayName;
    if (name == null) return const SizedBox.shrink();

    final theme = widget.theme;
    final avatarUrl = profile?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              foregroundImage:
                  (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
              child: Text(
                name.characters.first.toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 12,
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Connected to quran.com',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Trailing overflow menu — only action today is Sign out.
            // Kept as a compact icon so the card stays tidy; a full
            // button would dominate the row.
            IconButton(
              onPressed: () => _confirmSignOut(context),
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              tooltip: 'Sign out',
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final theme = widget.theme;
    // Capture the messenger up front so we don't need to re-read
    // `context` across the async gap (see use_build_context_synchronously).
    final messenger = ScaffoldMessenger.of(context);
    final lang = ref.read(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('signout_confirm_title')),
        content: Text(
          t('signout_confirm_body'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(t('signout_btn')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Clear QF auth state: tokens, authType, userId revert to
    // pre-sign-in defaults. The Settings page will rebuild and, since
    // storage.authType is no longer quranFoundation, the ACCOUNT
    // section (with "Sign in to save your journey") re-appears —
    // giving the user a clear path back in.
    await ref.read(qfAuthServiceProvider).signOut();
    await ref.read(qfProfileProvider.notifier).clear();
    ref.read(authUserProvider.notifier).state = null;
    // isLoggedIn watches storage.authToken, which is now null —
    // surface that change through the provider for any widget that
    // reads it directly.
    ref.read(isLoggedInProvider.notifier).state = false;

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(t('signout_success')),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


/// Settings row that reads the user's journal, lists each year that
/// has at least one reflection, and opens the `YearInAyatSheet` for
/// the tapped year. Keeps the Year-in-Ayat experience accessible
/// year-round — the journal's banner only surfaces in December /
/// early January, so a user who wants to see their 2025 in March
/// needs this path.
class _YearlyReviewsTile extends ConsumerWidget {
  final WidgetRef ref;
  final ThemeData theme;
  const _YearlyReviewsTile({required this.ref, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final entries = r.watch(journalProvider);
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warmBorder, width: 0.5),
        ),
        child: Text(
          'Your first yearly review unlocks after your first reflection.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Collect years with at least one reflection; sort newest first.
    final years = entries.map((e) => e.completedAt.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        for (var i = 0; i < years.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _YearRow(
            year: years[i],
            count: entries
                .where((e) => e.completedAt.year == years[i])
                .length,
            onTap: () {
              final stats = YearStats.compute(entries, years[i]);
              YearInAyatSheet.show(context, stats);
            },
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _YearRow extends ConsumerWidget {
  final int year;
  final int count;
  final VoidCallback onTap;
  final ThemeData theme;

  const _YearRow({
    required this.year,
    required this.count,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.warmBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: AppColors.accentDark.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('year_in_ayat_label')
                          .replaceAll('{year}', '$year'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (count == 1
                              ? t('year_review_subtitle_one')
                              : t('year_review_subtitle_other')
                                  .replaceAll('{n}', '$count'))
                          .replaceAll('{hijri}', hijriYearLabel(year)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the user pick which mufassir is shown when they tap "Read more"
/// on any ayah. Persisted per-language so an English reader's choice
/// doesn't stomp their Arabic reading preference. Options are filtered
/// to the user's current app language — no point showing Arabic
/// tafsirs to someone reading in English translation.
class _TafsirScholarTile extends ConsumerStatefulWidget {
  final ThemeData theme;
  const _TafsirScholarTile({required this.theme});

  @override
  ConsumerState<_TafsirScholarTile> createState() =>
      _TafsirScholarTileState();
}

class _TafsirScholarTileState extends ConsumerState<_TafsirScholarTile> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final storage = ref.watch(localStorageProvider);
    final rawLang = ref.watch(languageProvider);
    final lang = rawLang == 'ar' ? 'ar' : 'en';
    final options = tafsirOptionsFor(lang);
    final current = resolveTafsirFor(lang, storage.getPreferredTafsirSlug(lang));

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warmBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The instructional subtitle ("Shown when you tap 'Read
          // more' on an ayah") was dropped — users discover the
          // connection by using the app, and the subtitle was just
          // chrome telling them how the app works internally.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in options)
                GestureDetector(
                  onTap: () async {
                    await storage.setPreferredTafsirSlug(lang, opt.slug);
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: opt.slug == current.slug
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: opt.slug == current.slug
                            ? AppColors.primary.withValues(alpha: 0.55)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              opt.shortName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: opt.slug == current.slug
                                    ? AppColors.primary
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.75),
                                fontWeight: opt.slug == current.slug
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              opt.mufassir,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        // Checkmark on the selected chip — unifies the
                        // selection cue across Reciter picker, Font
                        // chooser, and Tafsir scholar so users learn one
                        // "this one is active" pattern.
                        if (opt.slug == current.slug) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
