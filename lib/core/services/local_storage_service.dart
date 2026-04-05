import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/models/user_profile.dart';
import 'package:tadabbur/core/models/user_progress.dart';

class LocalStorageService {
  static const _keyProgress = 'user_progress';
  static const _keyJournal = 'journal_entries';
  static const _keyOnboarded = 'has_onboarded';
  static const _keyProfile = 'user_profile';
  static const _keyReciterId = 'preferred_reciter_id';
  static const _keyNotificationTime = 'notification_time';
  static const _keyReciterPath = 'reciter_cdn_path';
  static const _keyArabicFontSize = 'arabic_font_size';
  static const _keyTranslationId = 'translation_id';
  static const _keyAuthToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

  // --- Auth ---

  String? get authToken => _prefs.getString(_keyAuthToken);

  Future<void> setAuthToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_keyAuthToken);
    } else {
      await _prefs.setString(_keyAuthToken, token);
    }
  }

  String? get refreshToken => _prefs.getString(_keyRefreshToken);

  Future<void> setRefreshToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_keyRefreshToken);
    } else {
      await _prefs.setString(_keyRefreshToken, token);
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

  bool get isLoggedIn => authToken != null;

  Future<void> clearAuth() async {
    await _prefs.remove(_keyAuthToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyUserId);
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

  String get arabicFont => _prefs.getString(_keyArabicFont) ?? 'AmiriQuran';

  Future<void> setArabicFont(String font) =>
      _prefs.setString(_keyArabicFont, font);

  String get language => _prefs.getString(_keyLanguage) ?? 'en';

  Future<void> setLanguage(String lang) =>
      _prefs.setString(_keyLanguage, lang);

  String? get notificationTime => _prefs.getString(_keyNotificationTime);

  Future<void> setNotificationTime(String time) =>
      _prefs.setString(_keyNotificationTime, time);

  // --- User Progress ---

  UserProgress? getProgress() {
    final json = _prefs.getString(_keyProgress);
    if (json == null) return null;
    return UserProgress.fromJson(jsonDecode(json));
  }

  Future<void> saveProgress(UserProgress progress) =>
      _prefs.setString(_keyProgress, jsonEncode(progress.toJson()));

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

  // --- Clear All ---

  Future<void> clearAll() => _prefs.clear();
}
