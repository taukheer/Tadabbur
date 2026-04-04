import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/providers/app_providers.dart';

// Reciters available on verses.quran.com CDN
const _reciters = [
  _ReciterOption('Alafasy', 'Mishary Rashid Alafasy', 'Murattal'),
  _ReciterOption('AbdulBasworet', 'Abdul Basit (Murattal)', 'Murattal'),
  _ReciterOption('Husary', 'Mahmoud Khalil Al-Husary', 'Murattal'),
  _ReciterOption('Minshawy_Murattal', 'Mohamed Siddiq El-Minshawi', 'Murattal'),
  _ReciterOption('Sudais', 'Abdurrahman As-Sudais', 'Murattal'),
  _ReciterOption('Saood', 'Saood ash-Shuraym', 'Murattal'),
  _ReciterOption('Ghamadi', 'Saad Al-Ghamdi', 'Murattal'),
  _ReciterOption('Ayman', 'Ayman Sowaid', 'Murattal'),
];

class _ReciterOption {
  final String cdnPath;
  final String name;
  final String style;
  const _ReciterOption(this.cdnPath, this.name, this.style);
}

// Font size options
const _fontSizes = [
  ('Small', 28.0),
  ('Medium', 34.0),
  ('Large', 40.0),
  ('Extra Large', 48.0),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);
    final storage = ref.watch(localStorageProvider);
    final theme = Theme.of(context);

    final currentReciter = storage.notificationTime ?? 'Alafasy'; // reusing field for reciter path
    final currentFontSize = storage.preferredReciterId.toDouble(); // reusing field for font size

    return Scaffold(
      backgroundColor: const Color(0xFFFEFDF8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/journal'),
                    icon: Icon(
                      Icons.arrow_back,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  Text(
                    'Settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Journey summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${progress.totalAyatCompleted}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ayat you have sat with',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Currently at ${progress.currentVerseKey}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // === RECITER ===
              _SectionLabel('RECITER', theme),
              const SizedBox(height: 12),
              ..._reciters.map((r) => _ReciterTile(
                    reciter: r,
                    isSelected: currentReciter == r.cdnPath,
                    onTap: () async {
                      await storage.setNotificationTime(r.cdnPath);
                      // Force rebuild
                      ref.read(isLoggedInProvider.notifier).state =
                          ref.read(isLoggedInProvider);
                    },
                    theme: theme,
                  )),

              const SizedBox(height: 28),

              // === ARABIC FONT SIZE ===
              _SectionLabel('ARABIC FONT SIZE', theme),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _fontSizes.map((f) {
                  final (label, size) = f;
                  final isSelected = currentFontSize == size ||
                      (currentFontSize == 7 && size == 34.0); // default
                  return GestureDetector(
                    onTap: () async {
                      await storage.setPreferredReciterId(size.toInt());
                      ref.read(isLoggedInProvider.notifier).state =
                          ref.read(isLoggedInProvider);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1B5E20).withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                              : const Color(0xFFE8E0D4),
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF1B5E20)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Preview
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: (currentFontSize == 7 ? 34 : currentFontSize),
                    color: const Color(0xFF1A1A1A),
                    height: 2.0,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // === TRANSLATION ===
              _SectionLabel('TRANSLATION', theme),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.translate_rounded,
                title: 'Saheeh International',
                subtitle: 'English',
                theme: theme,
              ),

              const SizedBox(height: 32),

              // About
              Center(
                child: Column(
                  children: [
                    Text(
                      'Tadabbur',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Built on Quran Foundation APIs',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Free for every Muslim. Forever.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _SectionLabel(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ReciterTile extends StatelessWidget {
  final _ReciterOption reciter;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ReciterTile({
    required this.reciter,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reciter.name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF1B5E20)
                          : theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    reciter.style,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeData theme;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20,
              color: const Color(0xFF1B5E20).withValues(alpha: 0.4)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
