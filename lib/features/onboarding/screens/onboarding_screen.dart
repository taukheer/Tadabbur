import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/constants/languages.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/auth_service.dart';

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

  void _nextPage() {
    if (_currentPage < 6) {
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
      backgroundColor: const Color(0xFFFEFDF8),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(7, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFF1B5E20).withValues(alpha: 0.1),
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
                  _ArabicLevelPage(
                    selected: _arabicLevel,
                    lang: _selectedLanguage ?? 'en',
                    onSelect: (v) {
                      setState(() => _arabicLevel = v);
                      Future.delayed(const Duration(milliseconds: 300), _nextPage);
                    },
                  ),
                  _UnderstandingPage(
                    selected: _understandingLevel,
                    lang: _selectedLanguage ?? 'en',
                    onSelect: (v) {
                      setState(() => _understandingLevel = v);
                      Future.delayed(const Duration(milliseconds: 300), _nextPage);
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
                  // Page 6: Sign in
                  _SignInPage(
                    lang: _selectedLanguage ?? 'en',
                    onGoogleSignIn: _signInWithGoogle,
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
    final qfAuth = ref.read(qfAuthServiceProvider);
    await qfAuth.launchLogin();
    // The OAuth callback will be handled by deep link
    // For now, complete onboarding — token exchange happens on return
    await _completeOnboarding(asGuest: true);
  }

  Future<void> _signInWithGoogle() async {
    final authService = ref.read(authServiceProvider);
    final user = await authService.signInWithGoogle();

    if (user != null) {
      ref.read(authUserProvider.notifier).state = user;
      // Set Firestore user ID for cloud sync
      ref.read(firestoreServiceProvider).setUser(user.id);
      await _completeOnboarding(asGuest: false);
    } else {
      // Sign in cancelled or failed — continue as guest
      await _completeOnboarding(asGuest: true);
    }
  }

  Future<void> _completeOnboarding({bool asGuest = true}) async {
    if (_arabicLevel == null ||
        _understandingLevel == null ||
        _motivation == null) return;

    final profile = UserProfile(
      arabicLevel: _arabicLevel!,
      understandingLevel: _understandingLevel!,
      motivation: _motivation!,
    );

    final storage = ref.read(localStorageProvider);
    await storage.saveProfile(profile);
    await storage.setOnboarded(true);

    if (asGuest) {
      await storage.setAuthToken('guest');
      await storage.setUserId('guest');
    }

    // Set starting position
    await ref
        .read(userProgressProvider.notifier)
        .setStartingVerse(_startingVerseKey);

    ref.read(userProfileProvider.notifier).state = profile;
    ref.read(hasOnboardedProvider.notifier).state = true;
    ref.read(isLoggedInProvider.notifier).state = true;

    // Sync profile to Firestore (fire-and-forget)
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
      ).catchError((_) {});
    }

    if (mounted) context.go('/home');
  }
}

// === PAGE 6: SIGN IN ===

class _SignInPage extends StatelessWidget {
  final String lang;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGuest;
  final VoidCallback? onQuranComSignIn;

  const _SignInPage({
    required this.lang,
    required this.onGoogleSignIn,
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
          const SizedBox(height: 60),

          Icon(
            Icons.cloud_done_outlined,
            size: 48,
            color: const Color(0xFF1B5E20).withValues(alpha: 0.4),
          ).animate().fadeIn(duration: 600.ms),

          const SizedBox(height: 24),

          Text(
            t('save_journey'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

          const SizedBox(height: 12),

          Text(
            t('sign_in_sync'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

          const SizedBox(height: 12),

          // What you lose as guest
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _BenefitRow(icon: Icons.sync_rounded, text: 'Sync across devices'),
                const SizedBox(height: 8),
                _BenefitRow(icon: Icons.backup_rounded, text: 'Journal backed up safely'),
                const SizedBox(height: 8),
                _BenefitRow(icon: Icons.devices_rounded, text: 'Continue on any phone'),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

          const SizedBox(height: 32),

          // Google Sign-In
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onGoogleSignIn,
              icon: Image.network(
                'https://www.google.com/favicon.ico',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.g_mobiledata, size: 24),
              ),
              label: Text(
                t('sign_google'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A1A1A),
                side: const BorderSide(color: Color(0xFFE8E0D4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

          const SizedBox(height: 12),

          // Quran.com Sign-In
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: onQuranComSignIn ?? onGuest,
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              label: Text(
                t('sign_quran'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E3A2F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 700.ms),

          const SizedBox(height: 12),

          // Guest mode with clear callout
          TextButton(
            onPressed: onGuest,
            child: Text(
              t('guest_mode'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 700.ms),

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
        Icon(icon,
            size: 18,
            color: const Color(0xFF1B5E20).withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8B7355).withValues(alpha: 0.7),
                fontSize: 13,
              ),
        ),
      ],
    );
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
              color: Color(0xFF1B5E20),
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 12),
          Text(
            AppTranslations.get('choose_language', 'en'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
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
                            ? const Color(0xFF1B5E20).withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1B5E20)
                                  .withValues(alpha: 0.3)
                              : const Color(0xFFE8E0D4)
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
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFF1A1A1A),
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
                                color: Color(0xFF1B5E20), size: 20),
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
              color: Color(0xFF1B5E20),
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
          const SizedBox(height: 32),
          Text(
            t('welcome_line'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: const Color(0xFF1A1A1A),
            ),
          ).animate().fadeIn(duration: 800.ms, delay: 500.ms),
          const Spacer(flex: 2),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E3A2F),
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

class _ArabicLevelPage extends StatelessWidget {
  final ArabicLevel? selected;
  final String lang;
  final ValueChanged<ArabicLevel> onSelect;

  const _ArabicLevelPage({this.selected, required this.lang, required this.onSelect});

  String t(String key) => AppTranslations.get(key, lang);

  @override
  Widget build(BuildContext context) {
    return _QuestionPage(
      question: t('how_read_arabic'),
      options: [
        _Option(
          title: t('read_fluent'),
          subtitle: t('read_fluent_sub'),
          isSelected: selected == ArabicLevel.fluent,
          onTap: () => onSelect(ArabicLevel.fluent),
        ),
        _Option(
          title: t('read_slow'),
          subtitle: t('read_slow_sub'),
          isSelected: selected == ArabicLevel.basic,
          onTap: () => onSelect(ArabicLevel.basic),
        ),
        _Option(
          title: t('read_none'),
          subtitle: t('read_none_sub'),
          isSelected: selected == ArabicLevel.none,
          onTap: () => onSelect(ArabicLevel.none),
        ),
      ],
    );
  }
}

// === PAGE 2: UNDERSTANDING ===

class _UnderstandingPage extends StatelessWidget {
  final UnderstandingLevel? selected;
  final String lang;
  final ValueChanged<UnderstandingLevel> onSelect;

  const _UnderstandingPage({this.selected, required this.lang, required this.onSelect});

  String t(String key) => AppTranslations.get(key, lang);

  @override
  Widget build(BuildContext context) {
    return _QuestionPage(
      question: t('when_recite'),
      subtitle: t('be_honest'),
      options: [
        _Option(
          title: t('understand_most'),
          isSelected: selected == UnderstandingLevel.most,
          onTap: () => onSelect(UnderstandingLevel.most),
        ),
        _Option(
          title: t('understand_some'),
          isSelected: selected == UnderstandingLevel.some,
          onTap: () => onSelect(UnderstandingLevel.some),
        ),
        _Option(
          title: t('understand_none'),
          isSelected: selected == UnderstandingLevel.none,
          onTap: () => onSelect(UnderstandingLevel.none),
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
              color: const Color(0xFF1A1A1A),
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
                  backgroundColor: const Color(0xFF2E3A2F),
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
    ('1:1', 'Al-Fatiha', 'The Opening — begin from the start'),
    ('36:1', 'Ya-Sin', 'The Heart of the Quran'),
    ('55:1', 'Ar-Rahman', 'The Most Merciful'),
    ('67:1', 'Al-Mulk', 'Sovereignty — protection in the grave'),
    ('78:1', 'Juz Amma', 'The short surahs you hear in salah'),
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
              color: const Color(0xFF1A1A1A),
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
            final (key, name, desc) = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Option(
                title: name,
                subtitle: desc,
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
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
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
                backgroundColor: const Color(0xFF2E3A2F),
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
    // Check full surah list
    final surahNum = int.tryParse(selected.split(':').first) ?? 1;
    if (surahNum > 0 && surahNum <= _surahNames.length) {
      return _surahNames[surahNum - 1];
    }
    return 'Surah $surahNum';
  }

  void _showSurahPicker(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFEFDF8),
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
                itemCount: _surahNames.length,
                itemBuilder: (context, index) {
                  final surahNum = index + 1;
                  final name = _surahNames[index];
                  final isSelected = selected == '$surahNum:1';
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1B5E20).withValues(alpha: 0.1)
                            : const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$surahNum',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFF8B7355),
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
                            ? const Color(0xFF1B5E20)
                            : null,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF1B5E20), size: 20)
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

  static const _surahNames = [
    'Al-Fatiha', 'Al-Baqarah', 'Ali Imran', 'An-Nisa', 'Al-Maidah',
    'Al-An\'am', 'Al-A\'raf', 'Al-Anfal', 'At-Tawbah', 'Yunus',
    'Hud', 'Yusuf', 'Ar-Ra\'d', 'Ibrahim', 'Al-Hijr',
    'An-Nahl', 'Al-Isra', 'Al-Kahf', 'Maryam', 'Ta-Ha',
    'Al-Anbiya', 'Al-Hajj', 'Al-Mu\'minun', 'An-Nur', 'Al-Furqan',
    'Ash-Shu\'ara', 'An-Naml', 'Al-Qasas', 'Al-Ankabut', 'Ar-Rum',
    'Luqman', 'As-Sajdah', 'Al-Ahzab', 'Saba', 'Fatir',
    'Ya-Sin', 'As-Saffat', 'Sad', 'Az-Zumar', 'Ghafir',
    'Fussilat', 'Ash-Shura', 'Az-Zukhruf', 'Ad-Dukhan', 'Al-Jathiyah',
    'Al-Ahqaf', 'Muhammad', 'Al-Fath', 'Al-Hujurat', 'Qaf',
    'Adh-Dhariyat', 'At-Tur', 'An-Najm', 'Al-Qamar', 'Ar-Rahman',
    'Al-Waqi\'ah', 'Al-Hadid', 'Al-Mujadilah', 'Al-Hashr', 'Al-Mumtahanah',
    'As-Saff', 'Al-Jumu\'ah', 'Al-Munafiqun', 'At-Taghabun', 'At-Talaq',
    'At-Tahrim', 'Al-Mulk', 'Al-Qalam', 'Al-Haqqah', 'Al-Ma\'arij',
    'Nuh', 'Al-Jinn', 'Al-Muzzammil', 'Al-Muddaththir', 'Al-Qiyamah',
    'Al-Insan', 'Al-Mursalat', 'An-Naba', 'An-Nazi\'at', 'Abasa',
    'At-Takwir', 'Al-Infitar', 'Al-Mutaffifin', 'Al-Inshiqaq', 'Al-Buruj',
    'At-Tariq', 'Al-A\'la', 'Al-Ghashiyah', 'Al-Fajr', 'Al-Balad',
    'Ash-Shams', 'Al-Layl', 'Ad-Duha', 'Ash-Sharh', 'At-Tin',
    'Al-Alaq', 'Al-Qadr', 'Al-Bayyinah', 'Az-Zalzalah', 'Al-Adiyat',
    'Al-Qari\'ah', 'At-Takathur', 'Al-Asr', 'Al-Humazah', 'Al-Fil',
    'Quraysh', 'Al-Ma\'un', 'Al-Kawthar', 'Al-Kafirun', 'An-Nasr',
    'Al-Masad', 'Al-Ikhlas', 'Al-Falaq', 'An-Nas',
  ];
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
              color: const Color(0xFF1A1A1A),
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
              ? const Color(0xFF1B5E20).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                : const Color(0xFFE8E0D4).withValues(alpha: 0.6),
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
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF1A1A1A),
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
                color: const Color(0xFF1B5E20).withValues(alpha: 0.6),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
