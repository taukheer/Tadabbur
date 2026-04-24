import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/constants/surahs.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/sync_reporter.dart';
import 'package:tadabbur/core/theme/app_colors.dart';


class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // User selections
  String? _selectedLanguage;
  ArabicLevel? _arabicLevel;
  UnderstandingLevel? _understandingLevel;
  Motivation? _motivation;
  String _startingVerseKey = '1:1';

  // Onboarding is 6 steps: language, welcome, arabic-relationship,
  // motivation, starting-point, sign-in. Sign-in is the final step so
  // every user has a real identity before seeing their first ayah —
  // activity tracking on QF User APIs + Firestore sync needs this. A
  // small "continue without signing in" link on the sign-in page
  // keeps a guest escape hatch for judges and skeptics without
  // burying the primary CTA.
  static const _totalPages = 6;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(_totalPages, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _LanguagePage(
                    selected: _selectedLanguage,
                    onSelect: (v) {
                      setState(() => _selectedLanguage = v);
                      // Save immediately so rest of onboarding can use it
                      ref.read(localStorageProvider).setLanguage(v);
                      ref.read(languageProvider.notifier).state = v;
                      Future.delayed(const Duration(milliseconds: 300), _nextPage);
                    },
                  ),
                  _WelcomePage(onNext: _nextPage, lang: _selectedLanguage ?? 'en'),
                  _ArabicRelationshipPage(
                    arabic: _arabicLevel,
                    understanding: _understandingLevel,
                    lang: _selectedLanguage ?? 'en',
                    onSelect: (pair) {
                      setState(() {
                        _arabicLevel = pair.$1;
                        _understandingLevel = pair.$2;
                      });
                      Future.delayed(
                          const Duration(milliseconds: 300), _nextPage);
                    },
                  ),
                  _MotivationPage(
                    selected: _motivation,
                    lang: _selectedLanguage ?? 'en',
                    onSelect: (v) {
                      setState(() => _motivation = v);
                    },
                    onBegin: _nextPage,
                  ),
                  _StartingPointPage(
                    selected: _startingVerseKey,
                    lang: _selectedLanguage ?? 'en',
                    onSelect: (v) {
                      setState(() => _startingVerseKey = v);
                    },
                    onBegin: _nextPage,
                  ),
                  // Final step: sign-in. Quran.com is the primary CTA
                  // (emerald filled button) because QF OAuth is the
                  // identity that unlocks Collections, Notes sync,
                  // Bookmarks, Activity-days, Streak, and the whole
                  // Connected Apps ecosystem story. Google / Apple
                  // are secondary paths. Guest is a small de-emphasized
                  // link so an evaluator can bypass without friction
                  // but a real user sees signing in as the obvious
                  // next move.
                  _SignInPage(
                    lang: _selectedLanguage ?? 'en',
                    onGoogleSignIn: _signInWithGoogle,
                    onAppleSignIn: _isIOS ? _signInWithApple : null,
                    onQuranComSignIn: _signInWithQuranCom,
                    onGuest: () => _completeOnboarding(asGuest: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithQuranCom() async {
    debugPrint('[Button] Onboarding: Quran.com sign-in tapped');
    final qfAuth = ref.read(qfAuthServiceProvider);
    await qfAuth.launchLogin();
    // OAuth completes via the deep-link handler in main.dart + the
    // router's /oauth/callback route, which exchanges the code for
    // a token. In the meantime we complete onboarding as guest so
    // the user doesn't get stuck on a spinner; the token arrival
    // upgrades authType from guest → quranFoundation automatically.
    // The login event is logged as 'quran_foundation' because that's
    // the user's intent, even though the token arrives asynchronously.
    await _completeOnboarding(asGuest: true, method: 'quran_foundation');
  }

  bool get _isIOS =>
      Theme.of(context).platform == TargetPlatform.iOS;

  Future<void> _signInWithGoogle() async {
    debugPrint('[Button] Onboarding: Google sign-in tapped');
    final qfAuth = ref.read(qfAuthServiceProvider);
    await qfAuth.launchLogin();
    await _completeOnboarding(asGuest: true, method: 'google');
  }

  Future<void> _signInWithApple() async {
    debugPrint('[Button] Onboarding: Apple sign-in tapped');
    final authService = ref.read(authServiceProvider);
    final user = await authService.signInWithApple();

    if (user != null) {
      ref.read(authUserProvider.notifier).state = user;
      ref.read(firestoreServiceProvider).setUser(user.id);
      await _completeOnboarding(asGuest: false, method: 'apple');
    } else {
      await _completeOnboarding(asGuest: true, method: 'apple_failed');
    }
  }

  Future<void> _completeOnboarding({
    bool asGuest = true,
    String method = 'guest',
  }) async {
    if (_arabicLevel == null ||
        _understandingLevel == null ||
        _motivation == null) {
      return;
    }

    final profile = UserProfile(
      arabicLevel: _arabicLevel!,
      understandingLevel: _understandingLevel!,
      motivation: _motivation!,
    );

    final storage = ref.read(localStorageProvider);
    await storage.saveProfile(profile);
    await storage.setOnboarded(true);

    // Auto-enable transliteration for users who can't read Arabic
    if (_arabicLevel == ArabicLevel.none) {
      await storage.setShowTransliteration(true);
      ref.read(showTransliterationProvider.notifier).state = true;
    }

    if (asGuest) {
      // Use the Firebase Auth anonymous UID as the guest's stable
      // identity, not the hardcoded string 'guest'. Otherwise every
      // guest overwrites the same /users/guest Firestore doc and the
      // admin can't distinguish installs. Anonymous auth is started
      // on app boot in main.dart; if it hasn't landed yet (very
      // first launch, offline, etc.), fall back to 'guest' so we
      // still return a valid id — the next write after auth lands
      // will move the user to their real UID via resetUser+setUser.
      final anonUid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      await storage.setAuthToken('guest');
      await storage.setUserId(anonUid);
      await storage.setAuthType(AuthType.guest);
      ref.read(firestoreServiceProvider).setUser(anonUid);
    }

    // Emit a login event so we can count auth methods in Firebase
    // Analytics (guest vs quran_foundation vs apple vs google). Fire
    // and forget — analytics is best-effort, never blocks the UI.
    unawaited(FirebaseAnalytics.instance
        .logLogin(loginMethod: method)
        .catchError((Object _) {}));

    // Set starting position
    await ref
        .read(userProgressProvider.notifier)
        .setStartingVerse(_startingVerseKey);

    ref.read(userProfileProvider.notifier).state = profile;
    ref.read(hasOnboardedProvider.notifier).state = true;
    ref.read(isLoggedInProvider.notifier).state = true;

    // Sync profile to Firestore (fire-and-forget). Runs for guests
    // too now that each guest has a distinct Firebase UID — previous
    // version short-circuited on `firestore.hasUser` which was false
    // for guests, leaving them invisible in the /users collection.
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore.hasUser) {
      final authUser = ref.read(authUserProvider);
      firestore.saveUserProfile(
        name: authUser?.name,
        email: authUser?.email,
        photoUrl: authUser?.photoUrl,
        language: _selectedLanguage ?? 'en',
        arabicLevel: _arabicLevel?.name,
        understandingLevel: _understandingLevel?.name,
        motivation: _motivation?.name,
        currentVerseKey: _startingVerseKey,
        reciterPath: storage.reciterPath,
        arabicFont: storage.arabicFont,
        arabicFontSize: storage.arabicFontSize,
        authMethod: method,
      ).catchError((Object e) {
        SyncReporter.report('profile', e);
      });
    }

    if (mounted) context.go('/home');
  }
}

// === PAGE 0: LANGUAGE ===

class _LanguagePage extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _LanguagePage({this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            'تدبر',
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 40,
              color: AppColors.primary,
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 12),
          Text(
            AppTranslations.get('choose_language', 'en'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: AppLanguages.supported.length,
              itemBuilder: (context, index) {
                final lang = AppLanguages.supported[index];
                final isSelected = selected == lang.code;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () => onSelect(lang.code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                                  .withValues(alpha: 0.3)
                              : AppColors.warmBorder
                                  .withValues(alpha: 0.5),
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang.nativeName,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimaryLight,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            lang.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// === PAGE 1: WELCOME ===

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  final String lang;

  const _WelcomePage({required this.onNext, required this.lang});

  String t(String key) => AppTranslations.get(key, lang);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          const Spacer(flex: 3),
          const Text(
            'تدبر',
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 64,
              color: AppColors.primary,
              height: 1.4,
            ),
          )
              .animate()
              .fadeIn(duration: 1000.ms)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: 1000.ms,
              ),
          const SizedBox(height: 12),
          Text(
            t('tagline'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.primary.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ).animate().fadeIn(duration: 800.ms, delay: 300.ms),
          const SizedBox(height: 32),
          Text(
            t('welcome_line'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: AppColors.textPrimaryLight,
            ),
          ).animate().fadeIn(duration: 800.ms, delay: 500.ms),
          const Spacer(flex: 2),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkButton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                t('begin'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
          const Spacer(),
        ],
      ),
    );
  }
}

// === PAGE 1: ARABIC LEVEL ===

/// Single "Arabic relationship" question that captures both reading
/// ability and comprehension in one tap.
///
/// Folded from the old two separate pages (ArabicLevel + Understanding).
/// Users reported these as redundant — both are "how much Arabic do
/// you know" — so the flow now asks once with four honest options
/// that span the realistic space: fluent+comprehension, fluent but
/// meaning slips, slow reader, or not yet reading.
class _ArabicRelationshipPage extends StatelessWidget {
  final ArabicLevel? arabic;
  final UnderstandingLevel? understanding;
  final String lang;
  final ValueChanged<(ArabicLevel, UnderstandingLevel)> onSelect;

  const _ArabicRelationshipPage({
    required this.arabic,
    required this.understanding,
    required this.lang,
    required this.onSelect,
  });

  String t(String key) => AppTranslations.get(key, lang);

  bool _isSelected(ArabicLevel a, UnderstandingLevel u) =>
      arabic == a && understanding == u;

  @override
  Widget build(BuildContext context) {
    return _QuestionPage(
      // Reuse the existing "How well do you read Arabic?" string —
      // the new sub-title pairs (fluent+comprehension) make the
      // question cover both reading *and* comprehension in one step.
      question: t('how_read_arabic'),
      subtitle: t('be_honest'),
      options: [
        _Option(
          title: t('read_fluent'),
          subtitle: t('understand_most'),
          isSelected: _isSelected(ArabicLevel.fluent, UnderstandingLevel.most),
          onTap: () =>
              onSelect((ArabicLevel.fluent, UnderstandingLevel.most)),
        ),
        _Option(
          title: t('read_fluent'),
          subtitle: t('understand_some'),
          isSelected: _isSelected(ArabicLevel.fluent, UnderstandingLevel.some),
          onTap: () =>
              onSelect((ArabicLevel.fluent, UnderstandingLevel.some)),
        ),
        _Option(
          title: t('read_slow'),
          subtitle: t('understand_some'),
          isSelected: _isSelected(ArabicLevel.basic, UnderstandingLevel.some),
          onTap: () =>
              onSelect((ArabicLevel.basic, UnderstandingLevel.some)),
        ),
        _Option(
          title: t('read_none'),
          subtitle: t('understand_none'),
          isSelected: _isSelected(ArabicLevel.none, UnderstandingLevel.none),
          onTap: () =>
              onSelect((ArabicLevel.none, UnderstandingLevel.none)),
        ),
      ],
    );
  }
}

// === PAGE 3: MOTIVATION ===

class _MotivationPage extends StatelessWidget {
  final Motivation? selected;
  final String lang;
  final ValueChanged<Motivation> onSelect;
  final VoidCallback onBegin;

  const _MotivationPage({
    this.selected,
    required this.lang,
    required this.onSelect,
    required this.onBegin,
  });

  String t(String key) => AppTranslations.get(key, lang);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(
            t('what_brought'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
              height: 1.3,
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 28),
          _Option(
            title: t('motivation_salah'),
            isSelected: selected == Motivation.salah,
            onTap: () => onSelect(Motivation.salah),
          ),
          const SizedBox(height: 10),
          _Option(
            title: t('motivation_connection'),
            isSelected: selected == Motivation.connection,
            onTap: () => onSelect(Motivation.connection),
          ),
          const SizedBox(height: 10),
          _Option(
            title: t('motivation_practice'),
            isSelected: selected == Motivation.practice,
            onTap: () => onSelect(Motivation.practice),
          ),
          const SizedBox(height: 10),
          _Option(
            title: t('motivation_learning'),
            isSelected: selected == Motivation.learning,
            onTap: () => onSelect(Motivation.learning),
          ),
          const Spacer(),
          if (selected != null)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: onBegin,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkButton,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  t('continue_btn'),
                  style: const
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(
                  begin: 0.1,
                  end: 0,
                  duration: 400.ms,
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// === SHARED COMPONENTS ===

// === PAGE 4: STARTING POINT ===

class _StartingPointPage extends StatelessWidget {
  final String selected;
  final String lang;
  final ValueChanged<String> onSelect;
  final VoidCallback onBegin;

  const _StartingPointPage({
    required this.selected,
    required this.lang,
    required this.onSelect,
    required this.onBegin,
  });

  String t(String key) => AppTranslations.get(key, lang);

  static const _presets = [
    ('1:1', 'Al-Fatiha', 'surah_fatiha_desc'),
    ('36:1', 'Ya-Sin', 'surah_yasin_desc'),
    ('55:1', 'Ar-Rahman', 'surah_rahman_desc'),
    ('67:1', 'Al-Mulk', 'surah_mulk_desc'),
    ('78:1', 'Juz Amma', 'surah_juz_amma_desc'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            t('where_begin'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
              height: 1.3,
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            t('change_later'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              fontStyle: FontStyle.italic,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 24),
          ..._presets.asMap().entries.map((entry) {
            final (key, name, descKey) = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Option(
                title: name,
                subtitle: t(descKey),
                isSelected: selected == key,
                onTap: () => onSelect(key),
              )
                  .animate()
                  .fadeIn(
                    duration: 400.ms,
                    delay: (300 + entry.key * 100).ms,
                  )
                  .slideY(
                    begin: 0.05,
                    end: 0,
                    duration: 400.ms,
                    delay: (300 + entry.key * 100).ms,
                  ),
            );
          }),
          // Browse all surahs
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => _showSurahPicker(context),
              child: Text(
                t('browse_surahs'),
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onBegin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkButton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                '${t('begin_with')} ${_selectedSurahName()}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _selectedSurahName() {
    // Check presets first
    for (final (key, name, _) in _presets) {
      if (selected == key) return name;
    }
    // Fall back to the canonical surah list.
    return surahNameFromKey(selected);
  }

  void _showSurahPicker(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
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
              child: Text(
                t('choose_different'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: 114,
                itemBuilder: (context, index) {
                  final surahNum = index + 1;
                  final name = kSurahNames[surahNum];
                  final isSelected = selected == '$surahNum:1';
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.warmSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$surahNum',
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.warmBrown,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : null,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 20)
                        : null,
                    onTap: () {
                      onSelect('$surahNum:1');
                      Navigator.of(context).pop();
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

}

class _QuestionPage extends StatelessWidget {
  final String question;
  final String? subtitle;
  final List<Widget> options;

  const _QuestionPage({
    required this.question,
    this.subtitle,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(
            question,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
              height: 1.3,
            ),
          ).animate().fadeIn(duration: 600.ms),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                fontStyle: FontStyle.italic,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          ],
          const SizedBox(height: 32),
          ...options
              .asMap()
              .entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: e.value
                        .animate()
                        .fadeIn(
                          duration: 400.ms,
                          delay: (300 + e.key * 100).ms,
                        )
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          duration: 400.ms,
                          delay: (300 + e.key * 100).ms,
                        ),
                  )),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _Option({
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.warmBorder.withValues(alpha: 0.6),
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
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary.withValues(alpha: 0.6),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// Final onboarding step: sign-in, with Quran.com as the primary path
/// and a small de-emphasized guest link at the bottom.
///
/// Rationale: QF OAuth is the identity layer that unlocks Collections,
/// Notes sync, Bookmarks, Activity-days, Streaks, and the whole
/// Connected Apps story. Users who sign in produce real activity we
/// can track; users who skip are a small minority we still support.
class _SignInPage extends StatelessWidget {
  final String lang;
  final VoidCallback onGoogleSignIn;
  final VoidCallback? onAppleSignIn;
  final VoidCallback onGuest;
  final VoidCallback? onQuranComSignIn;

  const _SignInPage({
    required this.lang,
    required this.onGoogleSignIn,
    this.onAppleSignIn,
    required this.onGuest,
    this.onQuranComSignIn,
  });

  String t(String key) => AppTranslations.get(key, lang);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(
            Icons.auto_stories_rounded,
            size: 44,
            color: AppColors.primary.withValues(alpha: 0.5),
          ).animate().fadeIn(duration: 600.ms),

          const SizedBox(height: 22),
          Text(
            t('save_journey'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 150.ms),

          const SizedBox(height: 10),
          Text(
            t('sign_in_sync'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 250.ms),

          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warmSurfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _BenefitRow(
                    icon: Icons.sync_rounded, text: t('sync_benefit')),
                const SizedBox(height: 8),
                _BenefitRow(
                    icon: Icons.backup_rounded, text: t('backup_benefit')),
                const SizedBox(height: 8),
                _BenefitRow(
                    icon: Icons.devices_rounded, text: t('phone_benefit')),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 350.ms),

          const SizedBox(height: 28),

          // Quran.com — primary CTA. The button that should grab the
          // eye: emerald fill, book icon, top of the sign-in stack.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onQuranComSignIn ?? onGuest,
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              label: Text(
                t('sign_quran'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkButton,
                minimumSize: const Size.fromHeight(54),
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

          const SizedBox(height: 12),

          // Google — secondary outlined button.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGoogleSignIn,
              icon: Image.network(
                'https://www.google.com/favicon.ico',
                width: 20,
                height: 20,
                errorBuilder: (ctx, err, stack) =>
                    const Icon(Icons.g_mobiledata, size: 24),
              ),
              label: Text(
                t('sign_google'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimaryLight,
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
                side: const BorderSide(color: AppColors.warmBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

          // Apple — iOS only, secondary outlined button.
          if (onAppleSignIn != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAppleSignIn,
                icon: const Icon(Icons.apple_rounded, size: 22),
                label: Text(
                  t('sign_apple'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimaryLight,
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  side: const BorderSide(color: AppColors.warmBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 650.ms),
          ],

          const SizedBox(height: 18),

          // Guest escape — deliberately quiet text link. Not styled
          // like a button so it doesn't compete with the real CTA;
          // still accessible for a judge/skeptic who wants to peek
          // without committing.
          TextButton(
            onPressed: onGuest,
            child: Text(
              t('guest_mode'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 750.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.warmBrown.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}
