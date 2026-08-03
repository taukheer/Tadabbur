import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/layout/breakpoints.dart';
import 'package:tadabbur/core/constants/translations.dart';
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
  required String lang,
}) async {
  String t(String key) => AppTranslations.get(key, lang);
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
    constraints: kAdaptiveSheetConstraints,    backgroundColor: theme.colorScheme.surface,
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
                t('share_ayah'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('share_card_preview'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.inkAt(0.4),
                ),
              ),
              const SizedBox(height: 16),

              // Scaled-down preview of the card. The actual rendered
              // image is always 1080x1350 regardless of the preview
              // size so the share asset is crisp on any device.
              //
              // Capped at 560 logical pixels of height: on a phone the
              // modal sheet's natural height already keeps the card
              // compact; on iPad the modal can grow to ~1000 pixels
              // tall and an uncapped 4:5 card would balloon to a
              // 720×900 cream slab with a short ayah floating in the
              // top quarter. Capping height (and width via the 4:5
              // aspect ratio) gives a 448×560 preview centered in the
              // sheet — readable, intentional, and consistent across
              // device classes.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
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
                        t('cancel'),
                        style: TextStyle(
                          color: theme.inkAt(0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    // Builder gives us a context whose RenderBox sits
                    // inside the FilledButton — we use it to derive the
                    // sharePositionOrigin needed for the iPad share
                    // popover. iPad's UIActivityViewController is a
                    // popover that *must* anchor to a screen rect, so
                    // calling Share.shareXFiles without an origin on
                    // iPad fails silently. iPhone ignores the origin.
                    child: Builder(
                      builder: (btnCtx) => FilledButton.icon(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          await _captureAndShare(
                            cardKey: cardKey,
                            ayah: ayah,
                            buttonContext: btnCtx,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(t('share_button')),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
  BuildContext? buttonContext,
}) async {
  // Compute share popover origin BEFORE the async gap (button context
  // may unmount during the capture/file-write). iPad's
  // UIActivityViewController is a popover that *must* anchor to a
  // sourceRect — without it the share call silently no-ops on iPad.
  Rect? origin;
  if (buttonContext != null && buttonContext.mounted) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
  }

  try {
    final boundary = cardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      debugPrint('[Share] capture aborted: no RepaintBoundary');
      return;
    }

    // 3x pixel ratio gives us a 3240x4050 output — crisp on retina
    // displays and high enough for feed/story uploads without upscaling.
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      debugPrint('[Share] capture aborted: byteData null');
      return;
    }
    final pngBytes = byteData.buffer.asUint8List();
    debugPrint('[Share] captured ${pngBytes.length} bytes');

    // Use dart:io's systemTemp instead of path_provider's
    // getTemporaryDirectory(). path_provider's iOS implementation goes
    // through objective_c.framework FFI bindings that fail on the iOS
    // 26.x simulator runtime, silently breaking share. systemTemp uses
    // a direct stat of /private/tmp so it works reliably on both
    // simulator and device.
    final tempDir = Directory.systemTemp;
    final file = File(
      '${tempDir.path}/tadabbur_${ayah.verseKey.replaceAll(':', '_')}.png',
    );
    await file.writeAsBytes(pngBytes, flush: true);
    debugPrint('[Share] wrote ${file.path}');

    final surahName = surahNameFromKey(ayah.verseKey);
    final result = await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: '$surahName ${ayah.verseKey} · Tadabbur',
      text: '$surahName ${ayah.verseKey} · https://tadabbur-jet.vercel.app',
      sharePositionOrigin: origin,
    );
    debugPrint('[Share] result: ${result.status}');
  } catch (e, stack) {
    debugPrint('[Share] FAILED: $e\n$stack');
    SyncReporter.report('share', e, severity: SyncSeverity.quiet);
  }
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

    // Arabic sizing still scales by character count — Arabic has its
    // own height budget above the separator and scaleDown on the
    // Arabic block would compromise its sacred presence.
    final arabicLen = ayah.textUthmani.length;
    final arabicFontSize = arabicLen > 300
        ? 13.0
        : arabicLen > 220
            ? 14.5
            : arabicLen > 140
                ? 17.0
                : arabicLen > 80
                    ? 19.0
                    : 22.0;
    final arabicLineHeight = arabicLen > 220
        ? 1.75
        : arabicLen > 140
            ? 1.9
            : 2.1;

    // Translation sizes by character count with a readable floor of
    // 9.5 pt. Previous iterations tried FittedBox(scaleDown) so the
    // block auto-fit the available vertical space — but for a 4:5
    // card preview that math produced type so small it was
    // unreadable. A discrete scale tuned against known ayah lengths
    // gives us predictable readability; the translation always
    // renders in full and hits a realistic lower bound.
    final trLen = translation.length;
    final translationFontSize = trLen > 500
        ? 9.5
        : trLen > 380
            ? 10.5
            : trLen > 280
                ? 11.5
                : trLen > 200
                    ? 12.5
                    : trLen > 130
                        ? 13.0
                        : 14.0;
    final translationLineHeight = trLen > 380 ? 1.4 : 1.5;

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
          // Day badge — top-left. Dropped the separate gold-dot
          // ornament row above the content: it ate ~30 px of vertical
          // space and added nothing the viewer couldn't infer from
          // the card's warmth. Less chrome = more room for the ayah.
          Positioned(
            top: 28,
            left: 28,
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
          // Wordmark footer — positioned at the bottom of the card,
          // independent of content length so short verses don't
          // strand it half-way up while long verses don't shove it
          // off-screen. Mirrors the day badge anchor at the top.
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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
            ),
          ),
          // Main content — vertically centered between the day badge
          // (top-left) and wordmark (bottom-center). Padding insets
          // clear those two anchors. With MainAxisAlignment.center on
          // the Column, short ayat sit in the middle of the card
          // instead of clumping at the top with cream emptiness below.
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 75, 32, 70),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                // Arabic text — the hero
                Text(
                  ayah.textUthmani,
                  locale: const Locale('ar'),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: arabicFontSize,
                    height: arabicLineHeight,
                    color: AppColors.sacredText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                // Separator dot
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 12),
                // Translation: char-count sizing picks a readable
                // target; FittedBox(scaleDown) acts as a *safety net*
                // only when the text still overflows (pathologically
                // long verses like 4:6). Flexible (not Expanded) lets
                // the block size to its content for short verses
                // while still bounding it for long ones — which is
                // what keeps the layout centered instead of stretched.
                if (translation.isNotEmpty)
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, c) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: c.maxWidth,
                          child: Text(
                            '"$translation"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: translationFontSize,
                              height: translationLineHeight,
                              color: AppColors.sacredText
                                  .withValues(alpha: 0.65),
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
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
