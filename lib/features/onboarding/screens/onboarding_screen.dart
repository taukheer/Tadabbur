import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/providers/app_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // User selections
  ArabicLevel? _arabicLevel;
  UnderstandingLevel? _understandingLevel;
  Motivation? _motivation;
  String _startingVerseKey = '1:1';

  void _nextPage() {
    if (_currentPage < 4) {
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
                children: List.generate(5, (i) {
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
                  _WelcomePage(onNext: _nextPage),
                  _ArabicLevelPage(
                    selected: _arabicLevel,
                    onSelect: (v) {
                      setState(() => _arabicLevel = v);
                      Future.delayed(const Duration(milliseconds: 300), _nextPage);
                    },
                  ),
                  _UnderstandingPage(
                    selected: _understandingLevel,
                    onSelect: (v) {
                      setState(() => _understandingLevel = v);
                      Future.delayed(const Duration(milliseconds: 300), _nextPage);
                    },
                  ),
                  _MotivationPage(
                    selected: _motivation,
                    onSelect: (v) {
                      setState(() => _motivation = v);
                    },
                    onBegin: _nextPage,
                  ),
                  _StartingPointPage(
                    selected: _startingVerseKey,
                    onSelect: (v) {
                      setState(() => _startingVerseKey = v);
                    },
                    onBegin: _completeOnboarding,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
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
    await storage.setAuthToken('guest');
    await storage.setUserId('guest');

    // Set starting position via notifier so the provider state updates
    await ref
        .read(userProgressProvider.notifier)
        .setStartingVerse(_startingVerseKey);

    ref.read(userProfileProvider.notifier).state = profile;
    ref.read(hasOnboardedProvider.notifier).state = true;
    ref.read(isLoggedInProvider.notifier).state = true;

    if (mounted) context.go('/home');
  }
}

// === PAGE 0: WELCOME ===

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

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
            'Sixty seconds with the Quran.\nEvery morning.\nAnd one day, your prayer\nwill change.',
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
              child: const Text(
                'Begin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
  final ValueChanged<ArabicLevel> onSelect;

  const _ArabicLevelPage({this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _QuestionPage(
      question: 'How well do you\nread Arabic?',
      subtitle: 'This helps us tailor your experience.',
      options: [
        _Option(
          title: 'I read Arabic fluently',
          subtitle: 'Comfortable with Uthmani script',
          isSelected: selected == ArabicLevel.fluent,
          onTap: () => onSelect(ArabicLevel.fluent),
        ),
        _Option(
          title: 'I can read slowly',
          subtitle: 'Learning or need practice',
          isSelected: selected == ArabicLevel.basic,
          onTap: () => onSelect(ArabicLevel.basic),
        ),
        _Option(
          title: 'I cannot read Arabic',
          subtitle: 'I\'ll need transliteration',
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
  final ValueChanged<UnderstandingLevel> onSelect;

  const _UnderstandingPage({this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _QuestionPage(
      question: 'When you recite\nthe Quran in salah...',
      subtitle: 'Be honest — this is between you and Allah.',
      options: [
        _Option(
          title: 'I understand most of it',
          subtitle: 'I studied Arabic or tafsir',
          isSelected: selected == UnderstandingLevel.most,
          onTap: () => onSelect(UnderstandingLevel.most),
        ),
        _Option(
          title: 'I understand some words',
          subtitle: 'I catch a few meanings',
          isSelected: selected == UnderstandingLevel.some,
          onTap: () => onSelect(UnderstandingLevel.some),
        ),
        _Option(
          title: 'I don\'t understand what I say',
          subtitle: 'I recite but don\'t know the meaning',
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
  final ValueChanged<Motivation> onSelect;
  final VoidCallback onBegin;

  const _MotivationPage({
    this.selected,
    required this.onSelect,
    required this.onBegin,
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
            'What brought\nyou here?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 28),
          _Option(
            title: 'I want to understand what I say in salah',
            isSelected: selected == Motivation.salah,
            onTap: () => onSelect(Motivation.salah),
          ),
          const SizedBox(height: 10),
          _Option(
            title: 'I want a deeper connection with the Quran',
            isSelected: selected == Motivation.connection,
            onTap: () => onSelect(Motivation.connection),
          ),
          const SizedBox(height: 10),
          _Option(
            title: 'I want to build a daily Quran habit',
            isSelected: selected == Motivation.practice,
            onTap: () => onSelect(Motivation.practice),
          ),
          const SizedBox(height: 10),
          _Option(
            title: 'I\'m learning about Islam',
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
                child: const Text(
                  'Continue',
                  style:
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
  final ValueChanged<String> onSelect;
  final VoidCallback onBegin;

  const _StartingPointPage({
    required this.selected,
    required this.onSelect,
    required this.onBegin,
  });

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(
            'Where would you\nlike to begin?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            'You can always change this later.',
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
                'Browse all 114 surahs',
                style: TextStyle(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const Spacer(),
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
                'Begin with ${_selectedSurahName()}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                'Choose a Surah',
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
