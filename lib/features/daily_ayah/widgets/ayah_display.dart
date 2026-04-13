import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tadabbur/core/models/ayah.dart';

class AyahDisplay extends StatelessWidget {
  final Ayah ayah;

  const AyahDisplay({super.key, required this.ayah});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surahNum = ayah.surahNumber;
    final ayahNum = ayah.ayahNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Surah and ayah reference
          Text(
            '$surahNum:$ayahNum',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Bismillah ornament for first ayah of surahs (except Al-Fatiha and At-Tawbah)
          if (ayahNum == 1 && surahNum != 1 && surahNum != 9) ...[
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
              locale: const Locale('ar'),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 22,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                height: 2.0,
              ),
            ),
            const SizedBox(height: 16),
            Divider(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              indent: 60,
              endIndent: 60,
            ),
            const SizedBox(height: 16),
          ],

          // Main Arabic text — the heart of the screen
          Semantics(
            label: 'Quranic verse ${ayah.verseKey}',
            child: Text(
              ayah.textUthmani,
              locale: const Locale('ar'),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 32,
                color: theme.colorScheme.onSurface,
                height: 2.2,
                letterSpacing: 0,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Translation
          if (ayah.translationText != null) ...[
            Divider(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              indent: 40,
              endIndent: 40,
            ),
            const SizedBox(height: 16),
            Text(
              ayah.translationText!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.8,
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms, curve: Curves.easeOut)
        .slideY(begin: 0.05, end: 0, duration: 800.ms, curve: Curves.easeOut);
  }
}
