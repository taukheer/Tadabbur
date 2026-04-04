/// All user-facing strings for Tadabbur (English).
///
/// Centralised here so future localisation is straightforward -- swap this
/// file (or feed it into an i18n system) and every screen updates.
abstract final class AppStrings {
  // ---------------------------------------------------------------------------
  // General
  // ---------------------------------------------------------------------------
  static const String appName = 'Tadabbur';
  static const String appTagline = 'One Ayah. Every Day. For Life.';
  static const String appSubtitle =
      'Your spiritual autobiography through the Quran.';

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------
  static const String onboardingWelcomeTitle = 'Welcome to Tadabbur';
  static const String onboardingWelcomeBody =
      'A sacred space for daily Quran contemplation. One ayah at a time, '
      'building a lifelong habit of reflection.';

  static const String onboardingAyahTitle = 'One Ayah, Every Day';
  static const String onboardingAyahBody =
      'Each morning, you will receive a carefully selected verse. Listen to '
      'its recitation, read the translation, and sit with its meaning.';

  static const String onboardingReflectTitle = 'Reflect & Grow';
  static const String onboardingReflectBody =
      'Write your thoughts -- even a single sentence counts. Over time, '
      'your reflections become a personal spiritual journal.';

  static const String onboardingStreakTitle = 'Build Your Streak';
  static const String onboardingStreakBody =
      'Consistency is the key to transformation. Track your daily streak '
      'and watch your contemplation practice flourish.';

  static const String onboardingGetStarted = 'Begin Your Journey';
  static const String onboardingSkip = 'Skip';
  static const String onboardingNext = 'Next';

  // ---------------------------------------------------------------------------
  // Home / Daily Ayah
  // ---------------------------------------------------------------------------
  static const String todaysAyah = "Today's Ayah";
  static const String listenRecitation = 'Listen to Recitation';
  static const String readTranslation = 'Read Translation';
  static const String wordByWord = 'Word by Word';
  static const String historicalContext = 'Historical Context';
  static const String scholarsReflection = "Scholar's Reflection";
  static const String yourReflection = 'Your Reflection';
  static const String writeReflection = 'Write your reflection...';
  static const String saveReflection = 'Save Reflection';
  static const String reflectionSaved = 'Reflection saved';
  static const String surah = 'Surah';
  static const String ayah = 'Ayah';
  static const String juz = 'Juz';

  // ---------------------------------------------------------------------------
  // Reflection tiers
  // ---------------------------------------------------------------------------
  static const String tier1Label = 'Quick Reflection';
  static const String tier1Description =
      'A brief thought or feeling about the ayah.';

  static const String tier2Label = 'Deeper Reflection';
  static const String tier2Description =
      'Connect the ayah to your life or an experience.';

  static const String tier3Label = "Scholar's Reflection";
  static const String tier3Description =
      'Explore the linguistic, historical, or thematic depth of the verse.';

  static const String tierPromptPrefix = 'Reflection Depth';
  static const String tierWordCount = 'words';

  // ---------------------------------------------------------------------------
  // Streak
  // ---------------------------------------------------------------------------
  static const String currentStreak = 'Current Streak';
  static const String longestStreak = 'Longest Streak';
  static const String totalReflections = 'Total Reflections';
  static const String streakDays = 'days';
  static const String streakDay = 'day';
  static const String streakFreezeAvailable = 'Streak Freeze Available';
  static const String streakFreezeUsed = 'Streak Freeze Used';
  static const String streakFreezeDescription =
      'A streak freeze protects your streak if you miss a day. '
      'You can hold up to 3 at a time.';
  static const String streakMilestoneReached = 'Milestone Reached!';
  static String streakMilestoneMessage(int days) =>
      'Masha\'Allah! You have maintained your contemplation for $days days.';
  static String streakCount(int count) =>
      '$count ${count == 1 ? 'day' : 'days'}';

  // ---------------------------------------------------------------------------
  // Journal / History
  // ---------------------------------------------------------------------------
  static const String journal = 'Journal';
  static const String journalEmpty =
      'Your reflections will appear here.\nStart with today\'s ayah.';
  static const String journalEntryDate = 'Reflected on';
  static const String searchJournal = 'Search reflections...';
  static const String noResults = 'No reflections found.';

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  static const String settings = 'Settings';
  static const String appearance = 'Appearance';
  static const String lightMode = 'Light';
  static const String darkMode = 'Dark';
  static const String systemMode = 'System';
  static const String notifications = 'Notifications';
  static const String dailyReminder = 'Daily Reminder';
  static const String reminderTime = 'Reminder Time';
  static const String translation = 'Translation';
  static const String reciter = 'Reciter';
  static const String about = 'About';
  static const String privacyPolicy = 'Privacy Policy';
  static const String termsOfService = 'Terms of Service';
  static const String version = 'Version';
  static const String signOut = 'Sign Out';
  static const String deleteAccount = 'Delete Account';
  static const String deleteAccountConfirm =
      'Are you sure? This will permanently delete your account and all '
      'reflections. This action cannot be undone.';

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------
  static const String notificationTitle = 'Your Ayah Awaits';
  static const String notificationBody =
      'Take a moment to reflect on today\'s verse.';
  static const String notificationStreakReminder =
      'Don\'t lose your streak! Reflect on today\'s ayah.';
  static const String notificationMilestone =
      'Congratulations on your contemplation milestone!';

  // ---------------------------------------------------------------------------
  // Audio player
  // ---------------------------------------------------------------------------
  static const String playing = 'Playing';
  static const String paused = 'Paused';
  static const String loading = 'Loading...';
  static const String replay = 'Replay';

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------
  static const String signIn = 'Sign In';
  static const String signInWithQuranCom = 'Sign in with Quran.com';
  static const String continueAsGuest = 'Continue as Guest';
  static const String guestDisclaimer =
      'Your reflections will be stored locally. Sign in later to sync '
      'across devices.';

  // ---------------------------------------------------------------------------
  // Error messages
  // ---------------------------------------------------------------------------
  static const String errorGeneric =
      'Something went wrong. Please try again.';
  static const String errorNetwork =
      'Unable to connect. Please check your internet connection.';
  static const String errorLoadingAyah =
      'Could not load today\'s ayah. Please try again later.';
  static const String errorLoadingAudio =
      'Could not load the recitation audio.';
  static const String errorSavingReflection =
      'Could not save your reflection. Please try again.';
  static const String errorAuth =
      'Authentication failed. Please try signing in again.';
  static const String errorTimeout =
      'The request timed out. Please try again.';
  static const String errorCacheExpired =
      'Cached content has expired. Refreshing...';

  // ---------------------------------------------------------------------------
  // Empty / placeholder states
  // ---------------------------------------------------------------------------
  static const String emptyReflections =
      'No reflections yet. Start your journey today.';
  static const String emptyBookmarks = 'No bookmarked ayahs yet.';

  // ---------------------------------------------------------------------------
  // Actions / buttons
  // ---------------------------------------------------------------------------
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String done = 'Done';
  static const String share = 'Share';
  static const String bookmark = 'Bookmark';
  static const String bookmarked = 'Bookmarked';
  static const String close = 'Close';
  static const String continueText = 'Continue';
  static const String learnMore = 'Learn More';

  // ---------------------------------------------------------------------------
  // Accessibility
  // ---------------------------------------------------------------------------
  static const String a11yPlayAudio = 'Play ayah recitation';
  static const String a11yPauseAudio = 'Pause ayah recitation';
  static const String a11yStreakIndicator = 'Streak indicator';
  static const String a11yReflectionInput = 'Reflection text input';
  static const String a11yBackButton = 'Go back';
  static const String a11ySettingsButton = 'Open settings';
}
