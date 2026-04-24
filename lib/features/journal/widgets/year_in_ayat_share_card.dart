import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/theme/app_colors.dart';

/// Force modern lining figures (1, 2, 3 at consistent height) on stat
/// numbers. Cormorant Garamond defaults to old-style figures with
/// descenders — lovely for body text, unreadable as dashboard stats.
const List<FontFeature> _liningFigures = [
  FontFeature('lnum'),
  FontFeature('tnum'),
];

/// Opens a preview sheet for the Year-in-Ayat share card. The card is
/// rendered off-screen in a RepaintBoundary, captured to PNG, and
/// handed to the platform share sheet. 4:5 aspect matches the
/// daily-ayah share card for feed/story compatibility.
Future<void> openYearInAyatShareSheet({
  required BuildContext context,
  required int gregorianYear,
  required String hijriYearLabel,
  required int totalReflections,
  required int activeDays,
  required int longestStreak,
  required int surahsEngaged,
  required int topSurahNumber,
  required int topSurahCount,
}) async {
  final cardKey = GlobalKey();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              // Card preview — 4:5 aspect. RepaintBoundary wraps it so
              // toImage() captures exactly what the user sees.
              AspectRatio(
                aspectRatio: 4 / 5,
                child: RepaintBoundary(
                  key: cardKey,
                  child: _YearShareCard(
                    gregorianYear: gregorianYear,
                    hijriYearLabel: hijriYearLabel,
                    totalReflections: totalReflections,
                    activeDays: activeDays,
                    longestStreak: longestStreak,
                    surahsEngaged: surahsEngaged,
                    topSurahNumber: topSurahNumber,
                    topSurahCount: topSurahCount,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _captureAndShare(
                          cardKey: cardKey,
                          gregorianYear: gregorianYear,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _captureAndShare({
  required GlobalKey cardKey,
  required int gregorianYear,
}) async {
  final boundary = cardKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return;

  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;
  final pngBytes = byteData.buffer.asUint8List();

  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/tadabbur_year_$gregorianYear.png');
  await file.writeAsBytes(pngBytes, flush: true);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    subject: 'My Year in Ayat · $gregorianYear · Tadabbur',
    text: 'My Year in Ayat · $gregorianYear · https://tadabbur-beige.vercel.app',
  );
}

/// The card that gets rendered to PNG. Fixed 4:5 aspect with the
/// daily-ayah share card's warm cream palette for visual consistency
/// across Tadabbur's shared artifacts.
class _YearShareCard extends StatelessWidget {
  final int gregorianYear;
  final String hijriYearLabel;
  final int totalReflections;
  final int activeDays;
  final int longestStreak;
  final int surahsEngaged;
  final int topSurahNumber;
  final int topSurahCount;

  const _YearShareCard({
    required this.gregorianYear,
    required this.hijriYearLabel,
    required this.totalReflections,
    required this.activeDays,
    required this.longestStreak,
    required this.surahsEngaged,
    required this.topSurahNumber,
    required this.topSurahCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasTopSurah = topSurahNumber > 0 && topSurahCount > 0;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFBF0),
            Color(0xFFFFF4E0),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Inner hairline frame — lifts the card from screenshot to
          // artifact. Insets match the daily-ayah share card for
          // cross-card consistency.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFE8D5B0).withValues(alpha: 0.7),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── Top cluster: eyebrow, ornament, year, hijri ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'YEAR IN AYAT',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GoldOrnament(),
                    const SizedBox(height: 10),
                    // Hero year in serif. Cormorant's old-style figures
                    // here are a feature, not a bug — they give the
                    // year the feel of a printed date on a dedication
                    // page instead of a calendar widget.
                    Text(
                      '$gregorianYear',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.textPrimaryLight,
                        fontSize: 52,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hijriYearLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.accentDark.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.2,
                        fontFeatures: _liningFigures,
                      ),
                    ),
                  ],
                ),

                // ── Middle cluster: most-returned-to surah ──
                if (hasTopSurah)
                  Column(
                    children: [
                      Text(
                        'MOST RETURNED TO',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimaryLight
                              .withValues(alpha: 0.45),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        kSurahNames[topSurahNumber],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorantGaramond(
                          color: AppColors.accentDark,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$topSurahCount ${topSurahCount == 1 ? "reflection" : "reflections"}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimaryLight
                              .withValues(alpha: 0.55),
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          fontFeatures: _liningFigures,
                        ),
                      ),
                    ],
                  ),

                // ── Stats cluster ──
                Column(
                  children: [
                    _Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CardStat(
                            value: '$totalReflections',
                            label: totalReflections == 1
                                ? 'reflection'
                                : 'reflections',
                          ),
                        ),
                        Expanded(
                          child: _CardStat(
                            value: '$activeDays',
                            label: activeDays == 1
                                ? 'day with the Qur\'an'
                                : 'days with the Qur\'an',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CardStat(
                            value: '$longestStreak',
                            label: 'day streak',
                          ),
                        ),
                        Expanded(
                          child: _CardStat(
                            value: '$surahsEngaged',
                            label: surahsEngaged == 1
                                ? 'surah engaged'
                                : 'surahs engaged',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Divider(),
                  ],
                ),

                // ── Bottom cluster: closing line + colophon ──
                Column(
                  children: [
                    Text(
                      'May these be written in your scales.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.accentDark.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TADABBUR  ·  $gregorianYear',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.primary.withValues(alpha: 0.55),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.6,
                        fontFeatures: _liningFigures,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three small gold diamonds centered with thin rules — a quiet
/// ornamental divider evoking the decorative elements found in
/// traditional mushaf pages without borrowing any specific Islamic
/// calligraphic motif (which would be risky to reproduce casually).
class _GoldOrnament extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = AppColors.accentDark.withValues(alpha: 0.55);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(height: 0.5, color: color),
        ),
        const SizedBox(width: 8),
        _Diamond(color: color, size: 4),
        const SizedBox(width: 4),
        _Diamond(color: color, size: 5),
        const SizedBox(width: 4),
        _Diamond(color: color, size: 4),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 0.5, color: color),
        ),
      ],
    );
  }
}

class _Diamond extends StatelessWidget {
  final Color color;
  final double size;

  const _Diamond({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398, // 45°
      child: Container(
        width: size,
        height: size,
        color: color,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: AppColors.accentDark.withValues(alpha: 0.22),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String value;
  final String label;

  const _CardStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.textPrimaryLight,
            fontSize: 26,
            fontWeight: FontWeight.w500,
            height: 1.0,
            fontFeatures: _liningFigures,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.textPrimaryLight.withValues(alpha: 0.6),
            fontSize: 10,
            letterSpacing: 0.3,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
