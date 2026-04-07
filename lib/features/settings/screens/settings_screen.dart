import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/services/auth_service.dart';
import 'package:tadabbur/core/services/firestore_service.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/arabic_fonts.dart';
import 'package:tadabbur/features/daily_ayah/providers/daily_ayah_provider.dart';

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

const _surahNames = [
  '', 'Al-Fatiha', 'Al-Baqarah', 'Ali Imran', 'An-Nisa', 'Al-Maidah',
  'Al-An\'am', 'Al-A\'raf', 'Al-Anfal', 'At-Tawbah', 'Yunus',
  'Hud', 'Yusuf', 'Ar-Ra\'d', 'Ibrahim', 'Al-Hijr',
  'An-Nahl', 'Al-Isra', 'Al-Kahf', 'Maryam', 'Ta-Ha',
  'Al-Anbiya', 'Al-Hajj', 'Al-Mu\'minun', 'An-Nur', 'Al-Furqan',
  'Ash-Shu\'ara', 'An-Naml', 'Al-Qasas', 'Al-Ankabut', 'Ar-Rum',
  'Luqman', 'As-Sajdah', 'Al-Ahzab', 'Saba', 'Fatir',
  'Ya-Sin', 'As-Saffat', 'Sad', 'Az-Zumar', 'Ghafir',
  'Fussilat', 'Ash-Shura', 'Az-Zukhruf', 'Ad-Dukhan', 'Al-Jathiyah',
  'Al-Ahqaf', 'Muhammad', 'Al-Fath', 'Al-Hujurat', 'Qaf',
  'Adh-Dhariyat', 'At-Tur', 'An-Najm', 'Al-Qamar', 'Ar-Rahman',
  'Al-Waqi\'ah', 'Al-Hadid', 'Al-Mujadilah', 'Al-Hashr', 'Al-Mumtahanah',
  'As-Saff', 'Al-Jumu\'ah', 'Al-Munafiqun', 'At-Taghabun', 'At-Talaq',
  'At-Tahrim', 'Al-Mulk', 'Al-Qalam', 'Al-Haqqah', 'Al-Ma\'arij',
  'Nuh', 'Al-Jinn', 'Al-Muzzammil', 'Al-Muddaththir', 'Al-Qiyamah',
  'Al-Insan', 'Al-Mursalat', 'An-Naba', 'An-Nazi\'at', 'Abasa',
  'At-Takwir', 'Al-Infitar', 'Al-Mutaffifin', 'Al-Inshiqaq', 'Al-Buruj',
  'At-Tariq', 'Al-A\'la', 'Al-Ghashiyah', 'Al-Fajr', 'Al-Balad',
  'Ash-Shams', 'Al-Layl', 'Ad-Duha', 'Ash-Sharh', 'At-Tin',
  'Al-Alaq', 'Al-Qadr', 'Al-Bayyinah', 'Az-Zalzalah', 'Al-Adiyat',
  'Al-Qari\'ah', 'At-Takathur', 'Al-Asr', 'Al-Humazah', 'Al-Fil',
  'Quraysh', 'Al-Ma\'un', 'Al-Kawthar', 'Al-Kafirun', 'An-Nasr',
  'Al-Masad', 'Al-Ikhlas', 'Al-Falaq', 'An-Nas',
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);
    final storage = ref.watch(localStorageProvider);
    final theme = Theme.of(context);

    final currentReciter = ref.watch(reciterPathProvider);
    final currentFontSize = ref.watch(arabicFontSizeProvider);
    final currentFont = ref.watch(arabicFontProvider);
    final currentSurah =
        int.tryParse(progress.currentVerseKey.split(':').first) ?? 1;
    final currentAyah =
        int.tryParse(progress.currentVerseKey.split(':').last) ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFDF8),
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

              // === ACCOUNT ===
              _SectionLabel('ACCOUNT', theme),
              const SizedBox(height: 10),
              _AccountTile(ref: ref, theme: theme),

              const SizedBox(height: 28),

              // === CURRENT POSITION — tap to change ===
              _SectionLabel('CURRENT POSITION', theme),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showSurahPicker(context, ref, progress),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          const Color(0xFF1B5E20).withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSurah > 0 &&
                                      currentSurah < _surahNames.length
                                  ? _surahNames[currentSurah]
                                  : 'Surah $currentSurah',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: const Color(0xFF1B5E20),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Ayah $currentAyah  ·  ${progress.totalAyatCompleted} ayat completed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF1B5E20)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Change',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF1B5E20)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: const Color(0xFF1B5E20)
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
                      color: const Color(0xFFE8E0D4),
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
                            color: const Color(0xFF1B5E20)
                                .withValues(alpha: 0.5),
                          )),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: const Color(0xFF1B5E20)
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
                          .catchError((_) {});
                    },
                    theme: theme,
                  )),

              const SizedBox(height: 28),

              // === DAILY REMINDER ===
              _SectionLabel('DAILY REMINDER', theme),
              const SizedBox(height: 10),
              _NotificationTile(ref: ref, theme: theme),

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
                    color: const Color(0xFFE8E0D4), width: 0.5),
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
                      activeColor: const Color(0xFF1B5E20),
                      onChanged: (v) async {
                        await storage.setShowTransliteration(v);
                        ref.read(showTransliterationProvider.notifier).state = v;
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
                          .catchError((_) {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1B5E20)
                                .withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1B5E20)
                                  .withValues(alpha: 0.3)
                              : const Color(0xFFE8E0D4),
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF1B5E20)
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
                          .catchError((_) {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: currentFont == font.id
                            ? const Color(0xFF1B5E20).withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: currentFont == font.id
                              ? const Color(0xFF1B5E20).withValues(alpha: 0.25)
                              : const Color(0xFFE8E0D4).withValues(alpha: 0.5),
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
                                              ? const Color(0xFF1B5E20)
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
                                  textDirection: TextDirection.rtl,
                                  style: ArabicFonts.getStyle(font.id, fontSize: 22)
                                      .copyWith(
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (currentFont == font.id)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF1B5E20), size: 20),
                        ],
                      ),
                    ),
                  )),

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
                      color: const Color(0xFFE8E0D4), width: 0.5),
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
      backgroundColor: const Color(0xFFFEFDF8),
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
                                  ? const Color(0xFF1B5E20)
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
                            color: Color(0xFF1B5E20), size: 20)
                        : null,
                    onTap: () async {
                      await storage.setLanguage(lang.code);
                      ref.read(languageProvider.notifier).state = lang.code;
                      ref.read(firestoreServiceProvider)
                          .saveUserProfile(language: lang.code)
                          .catchError((_) {});
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
      backgroundColor: const Color(0xFFFEFDF8),
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
                  final name = _surahNames[surahNum];
                  final isCurrent = progress.currentVerseKey
                      .startsWith('$surahNum:');
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF1B5E20)
                                .withValues(alpha: 0.1)
                            : const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('$surahNum',
                            style: TextStyle(
                              color: isCurrent
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFF8B7355),
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
                              ? const Color(0xFF1B5E20)
                              : null,
                        )),
                    trailing: isCurrent
                        ? const Icon(Icons.place_rounded,
                            color: Color(0xFF1B5E20), size: 18)
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
      backgroundColor: const Color(0xFFFEFDF8),
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
      final firestore = widget.ref.read(firestoreServiceProvider);
      final storage = widget.ref.read(localStorageProvider);

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

      // Auto-close after showing success
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send feedback. Please try again.')),
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
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Icon(Icons.check_circle_rounded,
                color: const Color(0xFF1B5E20), size: 56),
            const SizedBox(height: 20),
            Text('JazakAllahu Khairan',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1B5E20),
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
                color: const Color(0xFFE0E0E0),
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
                        ? const Color(0xFF1B5E20).withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                          : const Color(0xFFE8E0D4),
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16,
                          color: selected
                              ? const Color(0xFF1B5E20)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? const Color(0xFF1B5E20)
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
                borderSide: const BorderSide(color: Color(0xFFE8E0D4), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8E0D4), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
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
                backgroundColor: const Color(0xFF1B5E20),
                disabledBackgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.3),
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
              ? const Color(0xFF1B5E20).withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled
                ? const Color(0xFF1B5E20).withValues(alpha: 0.15)
                : const Color(0xFFE8E0D4),
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
                  ? const Color(0xFF1B5E20)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEnabled ? 'Daily reminder at $timeStr' : 'Set a daily reminder',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isEnabled
                          ? const Color(0xFF1B5E20)
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
                color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
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
          : const TimeOfDay(hour: 5, minute: 30), // Default: after Fajr
      helpText: 'When should we remind you?',
    );

    if (picked != null) {
      // Request permission first
      final granted = await notifService.requestPermission();
      if (granted) {
        await notifService.scheduleDailyNotification(
          hour: picked.hour,
          minute: picked.minute,
        );
        // Force rebuild
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
          final authService = ref.read(authServiceProvider);
          final user = await authService.signInWithGoogle();
          if (user != null) {
            ref.read(authUserProvider.notifier).state = user;
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E0D4), width: 0.5),
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
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.6))),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                const Color(0xFF1B5E20).withValues(alpha: 0.1),
            backgroundImage: authUser.photoUrl != null
                ? NetworkImage(authUser.photoUrl!)
                : null,
            child: authUser.photoUrl == null
                ? Text(
                    authUser.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1B5E20),
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
                      color: const Color(0xFF1B5E20),
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
              ? const Color(0xFF1B5E20).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B5E20).withValues(alpha: 0.25)
                : const Color(0xFFE8E0D4).withValues(alpha: 0.5),
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
                        ? const Color(0xFF1B5E20)
                        : theme.colorScheme.onSurface,
                    fontSize: 14,
                  )),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF1B5E20), size: 20),
          ],
        ),
      ),
    );
  }
}
