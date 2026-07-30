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

  // Note: an `oidc.quran-foundation` provider is registered in the
  // Firebase project but is NOT used. OIDC sign-in requires upgrading
  // to Identity Platform, which this project isn't on, so the runtime
  // rejects it with `operation-not-allowed`. The QF identity is carried
  // by a custom token instead (see QfIdentityLinkService), which also
  // fixes email-stranding across reinstalls. The config is left in
  // place, inert, in case the project is upgraded later.

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
  // Review prompt
  // ---------------------------------------------------------------------------

  /// Distinct days the user must have practised on before we ask for a
  /// review. Counted as calendar days with at least one reflection —
  /// not days since install — so the ask only reaches people who have
  /// actually formed the habit and have something to rate.
  static const int ratePromptMinActiveDays = 3;

  /// How long a "Not now" defers the ask.
  static const Duration ratePromptSnooze = Duration(days: 30);

  /// Total times the user may be asked before we retire the prompt.
  /// Two dismissals is a clear answer; a third ask would be nagging.
  static const int ratePromptMaxAsks = 2;

  /// Numeric App Store ID, from
  /// `apps.apple.com/us/app/tadabbur-one-ayah-a-day/id6766132608`.
  ///
  /// Only needed for the fallback path — when StoreKit declines to show
  /// the in-app sheet we deep-link to the listing instead, and iOS
  /// requires the ID to build that URL. Android derives its Play Store
  /// URL from the package name and ignores this.
  static const String appStoreId = '6766132608';

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
