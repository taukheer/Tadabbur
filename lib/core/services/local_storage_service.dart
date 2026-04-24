import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/models/user_progress.dart';

enum AuthType { guest, google, quranFoundation, none }

class LocalStorageService {
  static const _keyAuthType = 'auth_type';

  static const _keyProgress = 'user_progress';
  static const _keyJournal = 'journal_entries';
  static const _keyOnboarded = 'has_onboarded';
  static const _keyProfile = 'user_profile';
  static const _keyReciterId = 'preferred_reciter_id';
  static const _keyNotificationTime = 'notification_time';
  static const _keyReciterPath = 'reciter_cdn_path';
  static const _keyArabicFontSize = 'arabic_font_size';
  static const _keyTranslationId = 'translation_id';
  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_display_name';

  // Secure storage keys (encrypted on device)
  static const _secureKeyAuthToken = 'auth_token';
  static const _secureKeyRefreshToken = 'refresh_token';
  static const _secureKeyCodeVerifier = 'pkce_code_verifier';
  static const _secureKeyOAuthState = 'oauth_state';

  late final SharedPreferences _prefs;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // In-memory cache for secure values (avoid async reads in sync getters)
  String? _authToken;
  String? _refreshToken;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Pre-load secure values into memory
    _authToken = await _secureStorage.read(key: _secureKeyAuthToken);
    _refreshToken = await _secureStorage.read(key: _secureKeyRefreshToken);
  }

  // --- Onboarding ---

  bool get hasOnboarded => _prefs.getBool(_keyOnboarded) ?? false;

  Future<void> setOnboarded(bool value) =>
      _prefs.setBool(_keyOnboarded, value);

  // --- User Profile ---

  UserProfile? getProfile() {
    final json = _prefs.getString(_keyProfile);
    if (json == null) return null;
    return UserProfile.fromJson(jsonDecode(json));
  }

  Future<void> saveProfile(UserProfile profile) =>
      _prefs.setString(_keyProfile, jsonEncode(profile.toJson()));

  // --- Auth (encrypted via flutter_secure_storage) ---

  String? get authToken => _authToken;

  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    if (token == null) {
      await _secureStorage.delete(key: _secureKeyAuthToken);
    } else {
      await _secureStorage.write(key: _secureKeyAuthToken, value: token);
    }
  }

  String? get refreshToken => _refreshToken;

  Future<void> setRefreshToken(String? token) async {
    _refreshToken = token;
    if (token == null) {
      await _secureStorage.delete(key: _secureKeyRefreshToken);
    } else {
      await _secureStorage.write(key: _secureKeyRefreshToken, value: token);
    }
  }

  /// PKCE code verifier — stored securely, used only during OAuth flow.
  Future<String?> getCodeVerifier() async {
    return _secureStorage.read(key: _secureKeyCodeVerifier);
  }

  Future<void> setCodeVerifier(String? verifier) async {
    if (verifier == null) {
      await _secureStorage.delete(key: _secureKeyCodeVerifier);
    } else {
      await _secureStorage.write(key: _secureKeyCodeVerifier, value: verifier);
    }
  }

  /// OAuth state parameter — stored securely, used for CSRF validation during OAuth flow.
  Future<String?> getOAuthState() async {
    return _secureStorage.read(key: _secureKeyOAuthState);
  }

  Future<void> setOAuthState(String? state) async {
    if (state == null) {
      await _secureStorage.delete(key: _secureKeyOAuthState);
    } else {
      await _secureStorage.write(key: _secureKeyOAuthState, value: state);
    }
  }

  String? get userId => _prefs.getString(_keyUserId);

  Future<void> setUserId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyUserId);
    } else {
      await _prefs.setString(_keyUserId, id);
    }
  }

  /// Cached display name for offline user restoration.
  String? get userName => _prefs.getString(_keyUserName);

  Future<void> setUserName(String? name) async {
    if (name == null) {
      await _prefs.remove(_keyUserName);
    } else {
      await _prefs.setString(_keyUserName, name);
    }
  }

  /// True when the user has signed in via any provider (QF, Google, Apple,
  /// or guest mode). Checking authType is more robust than checking the
  /// token, since 3rd-party auth providers may not give us a usable token.
  bool get isLoggedIn {
    final t = authType;
    return t != AuthType.none;
  }

  AuthType get authType {
    final stored = _prefs.getString(_keyAuthType);
    if (stored == null) {
      // Legacy fallback for installs that pre-date authType persistence.
      if (_authToken == null) return AuthType.none;
      if (_authToken == 'guest') return AuthType.guest;
      if (_authToken!.startsWith('google_')) return AuthType.google;
      return AuthType.quranFoundation;
    }
    try {
      return AuthType.values.byName(stored);
    } catch (_) {
      return AuthType.none;
    }
  }

  Future<void> setAuthType(AuthType type) =>
      _prefs.setString(_keyAuthType, type.name);

  bool get isGuest => authType == AuthType.guest;

  Future<void> clearAuth() async {
    await setAuthToken(null);
    await setRefreshToken(null);
    await setCodeVerifier(null);
    await setOAuthState(null);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyUserName);
    await _prefs.remove(_keyAuthType);
  }

  // --- Preferences ---

  int get preferredReciterId => _prefs.getInt(_keyReciterId) ?? 7; // Mishary default

  Future<void> setPreferredReciterId(int id) =>
      _prefs.setInt(_keyReciterId, id);

  int get translationId => _prefs.getInt(_keyTranslationId) ?? 20; // Saheeh International

  Future<void> setTranslationId(int id) =>
      _prefs.setInt(_keyTranslationId, id);

  String get reciterPath => _prefs.getString(_keyReciterPath) ?? 'alafasy';

  Future<void> setReciterPath(String path) =>
      _prefs.setString(_keyReciterPath, path);

  double get arabicFontSize => _prefs.getDouble(_keyArabicFontSize) ?? 36.0;

  Future<void> setArabicFontSize(double size) =>
      _prefs.setDouble(_keyArabicFontSize, size);

  static const _keyArabicFont = 'arabic_font';
  static const _keyLanguage = 'user_language';
  static const _keyShowTransliteration = 'show_transliteration';

  static const _keyUseHijriDates = 'use_hijri_dates';

  /// When true, journal month headers render as Hijri months
  /// ("Ramadan 1447") instead of Gregorian ("March 2026"). Off by
  /// default — Gregorian is the wider-recognized default — so only
  /// users who deliberately toggle it get the Hijri variant.
  bool get useHijriDates =>
      _prefs.getBool(_keyUseHijriDates) ?? false;

  Future<void> setUseHijriDates(bool value) =>
      _prefs.setBool(_keyUseHijriDates, value);

  static const _keyDeferredSignInShown = 'deferred_signin_shown';

  /// Whether the "save what you've written" prompt has been surfaced
  /// to a guest user. Used to ensure we only nudge once — if the user
  /// dismissed it the first time, that's a signal to leave them alone.
  bool get deferredSignInShown =>
      _prefs.getBool(_keyDeferredSignInShown) ?? false;

  Future<void> setDeferredSignInShown() =>
      _prefs.setBool(_keyDeferredSignInShown, true);

  static const _keyQfProfile = 'qf_user_profile';

  /// Cached QF profile (JSON-encoded). We persist it so the identity
  /// row can render immediately on app launch without blocking on a
  /// network round-trip; the fresh copy lands on the next successful
  /// fetch. Kept alongside the auth token but plain-text (it's
  /// display data, not a credential).
  String? get qfProfileJson => _prefs.getString(_keyQfProfile);

  Future<void> setQfProfileJson(String? encoded) async {
    if (encoded == null || encoded.isEmpty) {
      await _prefs.remove(_keyQfProfile);
    } else {
      await _prefs.setString(_keyQfProfile, encoded);
    }
  }

  String get arabicFont => _prefs.getString(_keyArabicFont) ?? 'AmiriQuran';

  Future<void> setArabicFont(String font) =>
      _prefs.setString(_keyArabicFont, font);

  String get language => _prefs.getString(_keyLanguage) ?? 'en';

  Future<void> setLanguage(String lang) =>
      _prefs.setString(_keyLanguage, lang);

  String? get notificationTime => _prefs.getString(_keyNotificationTime);

  Future<void> setNotificationTime(String time) =>
      _prefs.setString(_keyNotificationTime, time);

  bool get showTransliteration =>
      _prefs.getBool(_keyShowTransliteration) ?? false;

  Future<void> setShowTransliteration(bool value) =>
      _prefs.setBool(_keyShowTransliteration, value);

  // --- User Progress ---

  UserProgress? getProgress() {
    final json = _prefs.getString(_keyProgress);
    if (json == null) return null;
    return UserProgress.fromJson(jsonDecode(json));
  }

  Future<void> saveProgress(UserProgress progress) =>
      _prefs.setString(_keyProgress, jsonEncode(progress.toJson()));

  // --- Bookmarks ---

  static const _keyBookmarks = 'bookmarks';

  List<Bookmark> getBookmarks() {
    final json = _prefs.getString(_keyBookmarks);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Bookmark.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveBookmarks(List<Bookmark> bookmarks) =>
      _prefs.setString(
        _keyBookmarks,
        jsonEncode(bookmarks.map((e) => e.toJson()).toList()),
      );

  // --- Journal Entries ---

  List<JournalEntry> getJournalEntries() {
    final json = _prefs.getString(_keyJournal);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => JournalEntry.fromJson(e)).toList();
  }

  Future<void> saveJournalEntries(List<JournalEntry> entries) =>
      _prefs.setString(
        _keyJournal,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );

  Future<void> addJournalEntry(JournalEntry entry) async {
    final entries = getJournalEntries();
    entries.insert(0, entry);
    await saveJournalEntries(entries);
  }

  // --- Daily Ayah Offline Cache ---
  // Stores the last successfully loaded daily ayah payload so the app can
  // fall back to cached content when the QF API is unreachable.

  static const _keyCachedDailyAyah = 'cached_daily_ayah';

  Map<String, dynamic>? getCachedDailyAyah() {
    final json = _prefs.getString(_keyCachedDailyAyah);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedDailyAyah(Map<String, dynamic> payload) =>
      _prefs.setString(_keyCachedDailyAyah, jsonEncode(payload));

  // --- Pending Firestore Sync ---
  // Tracks IDs of local writes that haven't been confirmed to Firestore yet.
  // On startup we replay these so a crash during sync doesn't lose cloud state.

  static const _keyPendingJournalSync = 'pending_journal_sync';
  static const _keyPendingBookmarkSync = 'pending_bookmark_sync';
  static const _keyPendingBookmarkRemoval = 'pending_bookmark_removal';
  static const _keyPendingProgressSync = 'pending_progress_sync';

  List<String> getPendingJournalSyncIds() =>
      _prefs.getStringList(_keyPendingJournalSync) ?? const [];

  Future<void> addPendingJournalSyncId(String id) async {
    final list = getPendingJournalSyncIds().toList();
    if (!list.contains(id)) {
      list.add(id);
      await _prefs.setStringList(_keyPendingJournalSync, list);
    }
  }

  Future<void> removePendingJournalSyncId(String id) async {
    final list = getPendingJournalSyncIds().toList();
    if (list.remove(id)) {
      await _prefs.setStringList(_keyPendingJournalSync, list);
    }
  }

  List<String> getPendingBookmarkSyncKeys() =>
      _prefs.getStringList(_keyPendingBookmarkSync) ?? const [];

  Future<void> addPendingBookmarkSyncKey(String verseKey) async {
    final list = getPendingBookmarkSyncKeys().toList();
    if (!list.contains(verseKey)) {
      list.add(verseKey);
      await _prefs.setStringList(_keyPendingBookmarkSync, list);
    }
  }

  Future<void> removePendingBookmarkSyncKey(String verseKey) async {
    final list = getPendingBookmarkSyncKeys().toList();
    if (list.remove(verseKey)) {
      await _prefs.setStringList(_keyPendingBookmarkSync, list);
    }
  }

  List<String> getPendingBookmarkRemovalKeys() =>
      _prefs.getStringList(_keyPendingBookmarkRemoval) ?? const [];

  Future<void> addPendingBookmarkRemovalKey(String verseKey) async {
    final list = getPendingBookmarkRemovalKeys().toList();
    if (!list.contains(verseKey)) {
      list.add(verseKey);
      await _prefs.setStringList(_keyPendingBookmarkRemoval, list);
    }
  }

  Future<void> removePendingBookmarkRemovalKey(String verseKey) async {
    final list = getPendingBookmarkRemovalKeys().toList();
    if (list.remove(verseKey)) {
      await _prefs.setStringList(_keyPendingBookmarkRemoval, list);
    }
  }

  bool get hasPendingProgressSync => _prefs.getBool(_keyPendingProgressSync) ?? false;

  Future<void> setPendingProgressSync(bool pending) =>
      _prefs.setBool(_keyPendingProgressSync, pending);

  // --- Clear All ---

  Future<void> clearAll() => _prefs.clear();
}
