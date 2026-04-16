import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';
import 'package:tadabbur/core/theme/app_colors.dart';

/// Opens a preview sheet with a beautifully-designed share card for the
/// current ayah, letting the user review and then share it as a PNG.
///
/// The card is designed for 4:5 Instagram/feed aspect ratio — the most
/// universally-shareable size across Twitter, WhatsApp, Instagram posts
/// and stories. Renders at 3x pixel ratio for retina-crisp output.
Future<void> openShareCardSheet({
  required BuildContext context,
  required Ayah ayah,
  required int dayNumber,
}) async {
  // Flag missing translations so we notice if it's happening in
  // production. The card itself degrades gracefully (omits the
  // translation block), but silently shipping an incomplete share card
  // signals a data gap the user might not catch.
  final raw = ayah.translationText?.trim() ?? '';
  if (raw.isEmpty) {
    SyncReporter.report(
      'share · missing translation',
      'verseKey=${ayah.verseKey}',
      severity: SyncSeverity.quiet,
    );
    unawaited(FirebaseCrashlytics.instance.recordError(
      StateError('Share card rendered without translation'),
      StackTrace.current,
      reason: 'share card missing translation',
      information: ['verseKey=${ayah.verseKey}'],
      fatal: false,
    ));
  }

  final cardKey = GlobalKey();
  final theme = Theme.of(context);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Share this ayah',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preview',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),

              // Scaled-down preview of the card. The actual rendered
              // image is always 1080x1350 regardless of the preview
              // size so the share asset is crisp on any device.
              Flexible(
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: RepaintBoundary(
                      key: cardKey,
                      child: _ShareCard(ayah: ayah, dayNumber: dayNumber),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await _captureAndShare(
                          cardKey: cardKey,
                          ayah: ayah,
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
  required Ayah ayah,
}) async {
  final boundary = cardKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return;

  // 3x pixel ratio gives us a 3240x4050 output — crisp on retina
  // displays and high enough for feed/story uploads without upscaling.
  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;
  final pngBytes = byteData.buffer.asUint8List();

  final tempDir = await getTemporaryDirectory();
  final file = File(
    '${tempDir.path}/tadabbur_${ayah.verseKey.replaceAll(':', '_')}.png',
  );
  await file.writeAsBytes(pngBytes, flush: true);

  final surahName = surahNameFromKey(ayah.verseKey);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    subject: '$surahName ${ayah.verseKey} · Tadabbur',
    text: '$surahName ${ayah.verseKey} · https://tadabbur.app',
  );
}

/// The actual card that gets rendered to PNG. Always sized to a
/// fixed logical 4:5 box inside the RepaintBoundary — the image we
/// share is the pixel-ratio-scaled version of this.
class _ShareCard extends StatelessWidget {
  final Ayah ayah;
  final int dayNumber;

  const _ShareCard({required this.ayah, required this.dayNumber});

  @override
  Widget build(BuildContext context) {
    final surahName = surahNameFromKey(ayah.verseKey);
    final translation = _cleanTranslation(ayah.translationText ?? '');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFBF0), // warm cream top
            Color(0xFFFFF4E0), // slightly deeper cream bottom
          ],
        ),
      ),
      child: Stack(
        children: [
          // Subtle inner ring — gives the card a framed, intentional feel
          // that keeps the composition from looking like a screenshot.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFE8D5B0).withValues(alpha: 0.6),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          // Gold dot header ornament
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _GoldDotRow(),
            ),
          ),
          // Day badge — top-left
          Positioned(
            top: 40,
            left: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Day $dayNumber',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 80, 36, 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Arabic text — the hero
                Text(
                  ayah.textUthmani,
                  locale: const Locale('ar'),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 22,
                    height: 2.1,
                    color: AppColors.sacredText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                // Separator dot
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 22),
                // Translation
                if (translation.isNotEmpty)
                  Text(
                    '"$translation"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.sacredText.withValues(alpha: 0.65),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                const Spacer(),
                // Verse reference
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warmSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.warmBorder.withValues(alpha: 0.6),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$surahName  ·  ${ayah.verseKey}',
                    style: const TextStyle(
                      color: AppColors.warmBrown,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // Wordmark footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Tadabbur',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 2,
                      height: 2,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'One ayah. Every day.',
                      style: TextStyle(
                        color: AppColors.warmBrown.withValues(alpha: 0.6),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.4,
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

  static String _cleanTranslation(String text) {
    return text
        .replaceAll(RegExp(r'\.\d+'), '')
        // Word-glued footnote digits like "Lord1 of" — see the same
        // pattern in journal_screen and quran_api_service. Must use
        // `replaceAllMapped` so `$1` resolves as a capture group.
        .replaceAllMapped(
          RegExp(r'(\w)\d+(?=\s|[,.!?;:"]|$)'),
          (m) => m.group(1)!,
        )
        .replaceAll(RegExp(r'\s*-\s*$'), '')
        .trim();
  }
}

class _GoldDotRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: i == 1 ? 4 : 3,
            height: i == 1 ? 4 : 3,
            decoration: BoxDecoration(
              color: AppColors.accent
                  .withValues(alpha: i == 1 ? 0.8 : 0.5),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

/// Unused PNG helper kept for future "save to gallery" flow.
// ignore: unused_element
Future<Uint8List?> _captureCardAsPng(GlobalKey key,
    {double pixelRatio = 3.0}) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
