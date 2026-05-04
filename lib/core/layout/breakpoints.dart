import 'package:flutter/material.dart';

/// Width-based device class. Mirrors Material's window-size class
/// guidance so the same breakpoints work for foldables, tablets, and
/// landscape phones.
///
/// - [compact]: phone, foldable folded, narrow window. < 600 logical px.
/// - [medium]: tablet portrait, foldable unfolded, small landscape phone. 600-839.
/// - [expanded]: tablet landscape, desktop. ≥ 840.
enum WindowSizeClass { compact, medium, expanded }

/// Maximum content width on tablet+. Keeps long lines of Arabic and
/// translation text readable instead of stretching across a 13-inch
/// iPad. 720 is the sweet spot — wide enough that two columns of
/// reflection cards fit comfortably, narrow enough that lines don't
/// fatigue the eye.
const double kMaxContentWidth = 720;

/// Width cap for `showModalBottomSheet` calls. On phones the sheet
/// fills the screen width as usual; on iPad the sheet centers and
/// caps at this width so tafsir, surah pickers, share cards, etc.
/// don't span 13 inches of glass. Apply via the `constraints:`
/// parameter on every modal sheet to keep behavior consistent.
const BoxConstraints kAdaptiveSheetConstraints =
    BoxConstraints(maxWidth: kMaxContentWidth);

/// Threshold for showing the side navigation rail instead of the
/// bottom navigation bar. Anything ≥ 840 (iPad landscape, foldable
/// unfolded landscape) gets the rail; below stays with bottom nav.
const double kSideNavBreakpoint = 840;

extension WindowSizeContext on BuildContext {
  WindowSizeClass get windowSize {
    final w = MediaQuery.sizeOf(this).width;
    if (w < 600) return WindowSizeClass.compact;
    if (w < kSideNavBreakpoint) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  /// True for tablet-class widths (iPad portrait, iPad landscape,
  /// large foldables). Phones in any orientation are false.
  bool get isWideLayout => windowSize != WindowSizeClass.compact;

  /// True only for the widest window class — iPad landscape and
  /// desktop. Used to swap bottom nav for a side rail.
  bool get useSideNavigation => windowSize == WindowSizeClass.expanded;
}

/// Constrains its child to [kMaxContentWidth] on tablet-class devices,
/// passes through unchanged on phones. Centers horizontally with
/// optional padding inside the constrained box.
///
/// Drop-in wrapper for any screen body or scrollable that should
/// remain phone-friendly on iPad rather than stretching to fill.
class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.isWideLayout) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
