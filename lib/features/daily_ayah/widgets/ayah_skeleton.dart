import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton placeholder for the daily-ayah loading state.
///
/// Built to mirror the actual ayah layout: a tall calligraphy block
/// where the Arabic will settle, followed by three translation lines
/// that taper right-to-center the way real sentences do. This means
/// the eye doesn't jump when real content replaces it — the substitute
/// has the same visual weight as what it's substituting for.
///
/// Uses `shimmer` (already in pubspec) with the app's primary tint
/// instead of neutral greys so the loading state still reads as
/// Tadabbur, not as a generic stub.
class AyahSkeleton extends StatelessWidget {
  const AyahSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = (isDark ? Colors.white : theme.colorScheme.primary)
        .withValues(alpha: isDark ? 0.05 : 0.06);
    final highlight = (isDark ? Colors.white : theme.colorScheme.primary)
        .withValues(alpha: isDark ? 0.10 : 0.14);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1600),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // Header meta: Hijri date placeholder + day badge placeholder
            Row(
              children: [
                _bar(width: 110, height: 10),
                const Spacer(),
                _bar(width: 56, height: 16, radius: 12),
                const SizedBox(width: 8),
                _bar(width: 28, height: 28, radius: 10),
              ],
            ),
            const SizedBox(height: 40),

            // Metadata pills (surah name + revelation tag)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _bar(width: 90, height: 20, radius: 10),
                const SizedBox(width: 8),
                _bar(width: 52, height: 20, radius: 10),
              ],
            ),
            const SizedBox(height: 44),

            // Arabic block — two lines of calligraphy-height bars with
            // RTL taper: longer line on top, shorter on bottom, so the
            // shape anticipates real Arabic rendering.
            Align(
              alignment: Alignment.centerRight,
              child: _bar(width: double.infinity, height: 26, radius: 6),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: _bar(width: 220, height: 26, radius: 6),
            ),
            const SizedBox(height: 36),

            // Translation — three tapering lines, center-aligned the
            // way the real translation renders.
            Center(child: _bar(width: double.infinity, height: 12, radius: 4)),
            const SizedBox(height: 10),
            Center(child: _bar(width: 280, height: 12, radius: 4)),
            const SizedBox(height: 10),
            Center(child: _bar(width: 180, height: 12, radius: 4)),
            const SizedBox(height: 48),

            // Audio/listen bar
            Center(child: _bar(width: 140, height: 40, radius: 20)),
          ],
        ),
      ),
    );
  }

  Widget _bar({
    required double width,
    required double height,
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
