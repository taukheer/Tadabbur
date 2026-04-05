import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tadabbur/core/constants/feelings.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/quran_api_service.dart';
import 'package:tadabbur/core/theme/arabic_fonts.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/models/ayah.dart';

class FeelingsScreen extends ConsumerStatefulWidget {
  const FeelingsScreen({super.key});

  @override
  ConsumerState<FeelingsScreen> createState() => _FeelingsScreenState();
}

class _FeelingsScreenState extends ConsumerState<FeelingsScreen> {
  FeelingAyah? _selected;
  Ayah? _ayah;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.get(key, lang);

    return Scaffold(
      backgroundColor: const Color(0xFFFEFDF8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _ayah != null
            ? _buildAyahView(theme, t, lang)
            : _buildFeelingPicker(theme, t),
      ),
    );
  }

  Widget _buildFeelingPicker(ThemeData theme, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            t('how_feeling'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ).animate().fadeIn(duration: 600.ms),

          const SizedBox(height: 8),
          Text(
            t('feeling_subtitle'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

          const SizedBox(height: 28),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.0,
              ),
              itemCount: Feelings.all.length,
              itemBuilder: (context, index) {
                final feeling = Feelings.all[index];
                return GestureDetector(
                  onTap: _loading ? null : () => _selectFeeling(feeling),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _selected?.id == feeling.id
                          ? const Color(0xFF1B5E20).withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selected?.id == feeling.id
                            ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                            : const Color(0xFFE8E0D4).withValues(alpha: 0.5),
                        width: _selected?.id == feeling.id ? 1.5 : 0.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(feeling.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              t(feeling.labelKey),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: _selected?.id == feeling.id
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selected?.id == feeling.id
                                    ? const Color(0xFF1B5E20)
                                    : const Color(0xFF1A1A1A),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: 400.ms,
                      delay: (100 * index).ms,
                    )
                    .slideY(begin: 0.05, end: 0, duration: 400.ms, delay: (100 * index).ms);
              },
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: Color(0xFF1B5E20),
                strokeWidth: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAyahView(ThemeData theme, String Function(String) t, String lang) {
    final arabicFontId = ref.watch(arabicFontProvider);
    final arabicFontSize = ref.watch(arabicFontSizeProvider);
    final reciterPath = ref.watch(reciterPathProvider);

    // Build audio URL
    final absAyahNum = _absoluteAyahNumber(
      int.parse(_ayah!.verseKey.split(':').first),
      int.parse(_ayah!.verseKey.split(':').last),
    );
    final bitrate = reciterPath == 'abdurrahmaansudais' ? '192' : '128';
    final audioUrl =
        'https://cdn.islamic.network/quran/audio/$bitrate/ar.$reciterPath/$absAyahNum.mp3';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Feeling label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selected!.emoji}  ${t(_selected!.labelKey)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8B7355),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Arabic
          Text(
            _ayah!.textUthmani,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: ArabicFonts.getStyle(arabicFontId, fontSize: arabicFontSize)
                .copyWith(color: const Color(0xFF1A1A1A)),
          ).animate().fadeIn(duration: 800.ms),

          const SizedBox(height: 20),

          // Translation
          if (_ayah!.translationText != null)
            Text(
              '"${_ayah!.translationText!}"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                height: 1.6,
                fontSize: 15,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

          const SizedBox(height: 24),

          // Listen
          FilledButton.icon(
            onPressed: () async {
              final audioService = ref.read(audioServiceProvider);
              await audioService.playAyah(audioUrl);
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(t('listen')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E3A2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

          const SizedBox(height: 32),

          // Prompt
          Text(
            t('sit_moment'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          // I felt this
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(t('i_felt_this')),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _selectFeeling(FeelingAyah feeling) async {
    setState(() {
      _selected = feeling;
      _loading = true;
    });

    try {
      final quranApi = ref.read(quranApiProvider);
      final storage = ref.read(localStorageProvider);
      final translationId =
          AppLanguages.getByCode(storage.language).translationId.toString();
      final ayah = await quranApi.getVerseByKey(
        feeling.randomVerseKey,
        translationId: translationId,
      );
      if (mounted) {
        setState(() {
          _ayah = ayah;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int _absoluteAyahNumber(int surah, int ayah) {
    const vc = [0,7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,98,135,112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,75,85,54,53,89,59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,13,14,11,11,18,12,12,30,52,52,44,28,28,20,56,40,31,50,40,46,42,29,19,36,25,22,17,19,26,30,20,15,21,11,8,8,19,5,8,8,11,11,8,3,9,5,4,7,3,6,3,5,4,5,6];
    int total = 0;
    for (int i = 1; i < surah && i < vc.length; i++) total += vc[i];
    return total + ayah;
  }
}
