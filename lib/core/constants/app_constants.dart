/// Application-wide constants for Tadabbur.
abstract final class AppConstants {
  // ---------------------------------------------------------------------------
  // App identity
  // ---------------------------------------------------------------------------
  static const String appName = 'Tadabbur';
  static const String appTagline = 'One Ayah. Every Day. For Life.';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // ---------------------------------------------------------------------------
  // Canonical text
  // ---------------------------------------------------------------------------

  /// Bismillah text in Uthmani script. Universally canonical — matches
  /// the Mushaf and is identical across every QF translation/edition.
  static const String bismillahUthmani =
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

  // ---------------------------------------------------------------------------
  // Quran Foundation API
  // ---------------------------------------------------------------------------
  static const String qfApiBaseUrl = 'https://api.qurancdn.com/api/qdc';
  static const String qfAuthUrl = 'https://oauth.quran.com';

  /// Default translation resource ID (Saheeh International).
  static const int defaultTranslationId = 20;

  /// Default reciter ID (Mishari Rashid al-Afasy).
  static const int defaultReciterId = 7;

  // ---------------------------------------------------------------------------
  // Animation durations
  // ---------------------------------------------------------------------------
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animPageTransition = Duration(milliseconds: 400);
  static const Duration animAyahReveal = Duration(milliseconds: 800);
  static const Duration animStreakCelebration = Duration(milliseconds: 1200);

  // ---------------------------------------------------------------------------
  // Streak & engagement
  // ---------------------------------------------------------------------------

  /// Maximum number of streak freezes a user may hold at once.
  static const int maxStreakFreezeDays = 3;

  /// Hour of the day (24h) at which the daily ayah resets.
  static const int dailyResetHour = 4; // 4:00 AM local

  /// Streak milestones that trigger a celebration animation.
  static const List<int> streakMilestones = [7, 30, 100, 365, 1000];

  // ---------------------------------------------------------------------------
  // Caching
  // ---------------------------------------------------------------------------

  /// How long fetched ayah content stays valid in the local cache.
  static const Duration contentCacheDuration = Duration(hours: 24);

  /// How long audio files remain cached on disk.
  static const Duration audioCacheDuration = Duration(days: 7);

  /// Maximum number of cached daily packages kept offline.
  static const int maxCachedDailyPackages = 30;

  // ---------------------------------------------------------------------------
  // Reflection tiers
  // ---------------------------------------------------------------------------
  static const int reflectionTier1MinWords = 0;
  static const int reflectionTier2MinWords = 25;
  static const int reflectionTier3MinWords = 100;

  // ---------------------------------------------------------------------------
  // Notification channels (Android)
  // ---------------------------------------------------------------------------
  static const String notificationChannelId = 'tadabbur_daily';
  static const String notificationChannelName = 'Daily Ayah';
  static const String notificationChannelDesc =
      'Your daily Quran contemplation reminder';

  // ---------------------------------------------------------------------------
  // Hive box names
  // ---------------------------------------------------------------------------
  static const String hiveBoxSettings = 'settings';
  static const String hiveBoxReflections = 'reflections';
  static const String hiveBoxStreaks = 'streaks';
  static const String hiveBoxCache = 'content_cache';

  // ---------------------------------------------------------------------------
  // SharedPreferences keys
  // ---------------------------------------------------------------------------
  static const String prefKeyOnboardingComplete = 'onboarding_complete';
  static const String prefKeyThemeMode = 'theme_mode';
  static const String prefKeyNotificationHour = 'notification_hour';
  static const String prefKeyNotificationMinute = 'notification_minute';
  static const String prefKeyPreferredTranslation = 'preferred_translation';
  static const String prefKeyPreferredReciter = 'preferred_reciter';

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------
  static const double maxContentWidth = 600;
  static const double horizontalPadding = 20;
  static const double cardBorderRadius = 16;
  static const double sacredContainerRadius = 20;
}
