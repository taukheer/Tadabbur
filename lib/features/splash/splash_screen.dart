import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tadabbur/core/providers/app_providers.dart';

/// World-class first-impression splash screen.
///
/// Choreography (~1 second total):
///   1. ت + diamond gold dots fade in over 250ms
///   2. Gold horizontal underline draws from center outward over 400ms
///      (overlaps slightly with #1 — starts at t=150ms)
///   3. 150ms hold at full brightness
///   4. Whole composition fades out over 200ms while we navigate to /home
///      (or /onboarding for first-time users)
///
/// The OS-managed launch screen (Android `launch_background.xml` and
/// iOS `LaunchScreen.storyboard`) shows a static version of the same
/// logo on the same #0A2E2A green so the handoff into this widget is
/// seamless — the user perceives one continuous moment, not two splashes
/// stacked.
///
/// The gold-underline-draws-itself motion is the brand's signature
/// gesture. It's intentionally restrained — under one second, no spinner,
/// no marketing yelling. Like the threshold to a masjid: a quiet pause
/// before the user steps into the Quran for the day.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Fade-in of the ת + diamond dots: 0 → 250ms.
  late final Animation<double> _logoFade;

  /// Underline draw: 150ms → 550ms (overlaps slightly with logo fade).
  late final Animation<double> _lineGrow;

  /// Whole-composition fade-out as we navigate away: 850ms → 1050ms.
  late final Animation<double> _exitFade;

  static const _totalDuration = Duration(milliseconds: 1050);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );

    // Stage 1 — logo fades in (0→250ms = 0→0.238 of timeline).
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.238, curve: Curves.easeOut),
    );

    // Stage 2 — underline draws from center outward (150→550ms =
    // 0.143→0.524 of timeline).
    _lineGrow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.143, 0.524, curve: Curves.easeOutCubic),
    );

    // Stage 3 — 150ms hold (550→700ms) is just elapsed time, no
    // animated value.
    //
    // Stage 4 — exit fade (850→1050ms = 0.810→1.0 of timeline). Inverted
    // (1 - t) so that t=0 in this interval reads as "fully visible" and
    // t=1 reads as "fully transparent".
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.810, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().whenComplete(_navigateAway);
  }

  void _navigateAway() {
    if (!mounted) return;
    final hasOnboarded = ref.read(hasOnboardedProvider);
    context.go(hasOnboarded ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hard-coded splash background: must match `splash_bg` in
    // android/app/src/main/res/values/colors.xml AND the storyboard
    // background in ios/Runner/Base.lproj/LaunchScreen.storyboard so
    // the OS-managed launch screen and this Flutter screen are
    // pixel-identical until the animation starts.
    const splashBg = Color(0xFF0A2E2A);
    const goldAccent = Color(0xFFC9A24A);

    return Scaffold(
      backgroundColor: splashBg,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _exitFade.value,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // The ת + diamond dots, sized at ~40% of viewport
                  // shorter side so it dominates without crowding.
                  Opacity(
                    opacity: _logoFade.value,
                    child: SizedBox(
                      width: _logoSize(context),
                      height: _logoSize(context),
                      child: Image.asset(
                        'assets/images/splash_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Gap between letter and underline. The PNG already
                  // has whitespace below the letter, so the visible
                  // gap is smaller than this number suggests.
                  const SizedBox(height: 8),
                  // The signature gesture — gold line drawing itself
                  // outward from center. We render the line at the
                  // final width but multiply its scale on the X axis
                  // by the current animation value so it appears to
                  // grow symmetrically from the middle.
                  Transform.scale(
                    scaleX: _lineGrow.value,
                    scaleY: 1.0,
                    child: Container(
                      width: _logoSize(context) * 0.55,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: goldAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Logo edge length scaled to the viewport. Min/max clamps keep the
  /// composition from looking lost on huge tablets or cramped on small
  /// phones.
  double _logoSize(BuildContext context) {
    final shorter = MediaQuery.of(context).size.shortestSide;
    return (shorter * 0.40).clamp(160.0, 320.0);
  }
}

