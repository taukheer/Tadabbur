import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/models/tafsir_option.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/core/theme/arabic_fonts.dart';
import 'package:tadabbur/features/daily_ayah/providers/daily_ayah_provider.dart';
import 'package:tadabbur/features/journal/screens/journal_screen.dart'
    show YearStats, YearInAyatSheet, hijriYearLabel;

const _reciters = [
  _ReciterOption('alafasy', 'Mishary Rashid Alafasy'),
  _ReciterOption('husary', 'Mahmoud Khalil Al-Husary'),
  _ReciterOption('minshawi', 'Mohamed Siddiq El-Minshawi'),
  _ReciterOption('abdurrahmaansudais', 'Abdurrahman As-Sudais'),
  _ReciterOption('muhammadayyoub', 'Muhammad Ayyub'),
  _ReciterOption('shaatree', 'Abu Bakr Ash-Shaatree'),
];

class _ReciterOption {
  final String cdnPath;
  final String name;
  const _ReciterOption(this.cdnPath, this.name);
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),

              const SizedBox(height: 24),

              // === QF IDENTITY — visible sign of the OAuth connection ===
              // Only renders when the user is signed in via QF OAuth
              // *and* we have a profile on hand; for guest/Google/Apple
              // the row is silent so it can't mislead.
              _QfIdentityRow(ref: ref, theme: theme),

              // === ACCOUNT ===
              // Hidden for QF-authenticated users because the identity
              // row above already tells the full story. Without this
              // guard, _AccountTile would fall back to "Guest mode" on
              // every relaunch (it reads authUserProvider, which is
              // in-memory only and resets to null at cold start),
              // producing two contradictory cards.
              if (storage.authType != AuthType.quranFoundation) ...[
                _SectionLabel('ACCOUNT', theme),
                const SizedBox(height: 10),
                _AccountTile(ref: ref, theme: theme),
                const SizedBox(height: 28),
              ] else
                const SizedBox(height: 8),

              // === CURRENT POSITION — tap to change ===
              _SectionLabel('CURRENT POSITION', theme),
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
                              'Ayah $currentAyah  ·  ${progress.totalAyatCompleted} ayat completed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.primary
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Change',
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
              _SectionLabel('LANGUAGE', theme),
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
                      Text('Change',
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
              _SectionLabel('RECITER', theme),
              const SizedBox(height: 10),
              ..._reciters.map((r) => _ReciterTile(
                    name: r.name,
                    isSelected: currentReciter == r.cdnPath,
                    onTap: () async {
                      await storage.setReciterPath(r.cdnPath);
                      ref.read(reciterPathProvider.notifier).state = r.cdnPath;
                      ref.read(firestoreServiceProvider)
                          .saveUserProfile(reciterPath: r.cdnPath)
                          .catchError((Object e) {
                        SyncReporter.report('reciter preference', e,
                            severity: SyncSeverity.quiet);
                      });
                    },
                    theme: theme,
                  )),

              const SizedBox(height: 28),

              // === DAILY REMINDER ===
              _SectionLabel('DAILY REMINDER', theme),
              const SizedBox(height: 10),
              _NotificationTile(ref: ref, theme: theme),

              const SizedBox(height: 28),

              // === TAFSIR SCHOLAR ===
              _SectionLabel('TAFSIR SCHOLAR', theme),
              const SizedBox(height: 10),
              _TafsirScholarTile(theme: theme),

              const SizedBox(height: 28),

              // === TRANSLITERATION ===
              _SectionLabel('TRANSLITERATION', theme),
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
                          Text('Show transliteration',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          Text('Roman script below Arabic text',
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

              // === JOURNAL DATES ===
              _SectionLabel('JOURNAL DATES', theme),
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
                          Text('Use Hijri months',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          Text(
                            'Section headers show "Ramadan 1447" '
                            'instead of "March 2026".',
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
              _SectionLabel('ARABIC FONT SIZE', theme),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _fontSizes.map((f) {
                  final (label, size) = f;
                  final isSelected =
                      (currentFontSize - size).abs() < 1;
                  return GestureDetector(
                    onTap: () async {
                      await storage.setArabicFontSize(size);
                      ref.read(arabicFontSizeProvider.notifier).state = size;
                      ref.read(firestoreServiceProvider)
                          .saveUserProfile(arabicFontSize: size)
                          .catchError((Object e) {
                        SyncReporter.report('font-size preference', e,
                            severity: SyncSeverity.quiet);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                                .withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                                  .withValues(alpha: 0.3)
                              : AppColors.warmBorder,
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // === ARABIC FONT STYLE ===
              _SectionLabel('ARABIC FONT', theme),
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
                                    Text(font.description,
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

              // === YEARLY REVIEWS ===
              // Year-in-Ayat summaries accessible year-round. The
              // journal tab surfaces the banner only during the
              // Dec 15 – Jan 15 window; users who want to revisit an
              // older review or peek mid-year come here.
              _SectionLabel('YEAR IN AYAT', theme),
              const SizedBox(height: 10),
              _YearlyReviewsTile(ref: ref, theme: theme),

              const SizedBox(height: 28),

              // === FEEDBACK ===
              _SectionLabel('FEEDBACK', theme),
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
                            Text('Send Feedback',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                            Text('Help us improve Tadabbur',
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

              // About
              Center(
                child: Column(
                  children: [
                    Text('Tadabbur',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Built on Quran Foundation APIs',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.2))),
                    const SizedBox(height: 2),
                    Text('Free for every Muslim. Forever.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.2),
                            fontStyle: FontStyle.italic)),
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

  void _showLanguagePicker(
      BuildContext context, WidgetRef ref, dynamic storage) {
    final theme = Theme.of(context);
    final currentLang = ref.read(languageProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
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
              child: Text('Translation Language',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
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
              child: Text('Jump to Surah',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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

      // Writes to /feedback in Firestore. The collection's security
      // rule requires `request.auth != null` + a size cap; anonymous
      // Firebase Auth (wired in main.dart) satisfies the auth check
      // for every install. Viewable in Firebase Console at
      // tadabbur-492408 → Firestore → feedback.
      await FirebaseFirestore.instance.collection('feedback').add({
        'category': _category,
        'message': _controller.text.trim(),
        'user_id': storage.userId ?? 'guest',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send feedback. Please try again.'),
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
            Text('JazakAllahu Khairan',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 8),
            Text('Your feedback helps us improve.',
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
          Text('Send Feedback',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
          Text('We read every message.',
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
                  : const Text('Send', style: TextStyle(fontSize: 15)),
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

class _NotificationTile extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;

  const _NotificationTile({required this.ref, required this.theme});

  @override
  Widget build(BuildContext context) {
    final notifService = ref.watch(notificationServiceProvider);
    final scheduled = notifService.getScheduledTime();
    final isEnabled = scheduled != null;
    final timeStr = isEnabled
        ? TimeOfDay(hour: scheduled.hour, minute: scheduled.minute)
            .format(context)
        : 'Not set';

    return GestureDetector(
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
                        ? 'Daily reminder at $timeStr'
                        : 'Set a daily reminder',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isEnabled
                          ? AppColors.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    isEnabled
                        ? '"Your ayah for today is waiting"'
                        : 'One notification per day, your chosen time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.35),
                      fontStyle: isEnabled ? FontStyle.italic : FontStyle.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              isEnabled ? 'Change' : 'Set time',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
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
                    Text('Guest mode',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    Text('Sign in to save your journey',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.35),
                            fontSize: 12)),
                  ],
                ),
              ),
              Text('Sign in',
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
            child: Text('Sign out',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.35))),
          ),
        ],
      ),
    );
  }
}

class _ReciterTile extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ReciterTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.warmBorder.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.primary
                        : theme.colorScheme.onSurface,
                    fontSize: 14,
                  )),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Account',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
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
                        'Delete account',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color:
                              theme.colorScheme.error.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Permanently delete your account and all data',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete account?'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete forever'),
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
          const SnackBar(
            content: Text('Account deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete account: $e'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of quran.com?'),
        content: Text(
          'Your local reflections and bookmarks stay on this device. '
          'Sign back in any time to resume syncing with quran.com.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Sign out'),
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
      const SnackBar(
        content: Text('Signed out of quran.com.'),
        duration: Duration(seconds: 2),
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

class _YearRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                      '$year in ayat',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${hijriYearLabel(year)} · ${count == 1 ? "1 reflection" : "$count reflections"}',
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
          Text(
            'Shown when you tap "Read more" on an ayah.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
