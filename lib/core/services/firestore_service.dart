import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tadabbur/core/models/journal_entry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _userId;

  void setUser(String userId) {
    _userId = userId;
  }

  bool get hasUser => _userId != null;

  /// Save a journal entry to Firestore.
  Future<void> saveJournalEntry(JournalEntry entry) async {
    if (_userId == null) return;
    try {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('journal')
          .doc(entry.id)
          .set({
        'verse_key': entry.verseKey,
        'arabic_text': entry.arabicText,
        'translation_text': entry.translationText,
        'tier': entry.tier.name,
        'prompt_text': entry.promptText,
        'response_text': entry.responseText,
        'completed_at': entry.completedAt.toIso8601String(),
        'streak_day': entry.streakDay,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Firestore] Failed to save journal entry: $e');
    }
  }

  /// Save user progress to Firestore.
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    if (_userId == null) return;
    try {
      await _db.collection('users').doc(_userId).set({
        'progress': progress,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] Failed to save progress: $e');
    }
  }

  /// Save user profile and settings to Firestore.
  Future<void> saveUserProfile({
    String? name,
    String? email,
    String? photoUrl,
    String? language,
    String? arabicLevel,
    String? understandingLevel,
    String? motivation,
    String? reciterPath,
    String? arabicFont,
    double? arabicFontSize,
    String? currentVerseKey,
  }) async {
    if (_userId == null) return;
    try {
      final data = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (email != null) data['email'] = email;
      if (photoUrl != null) data['photo_url'] = photoUrl;
      if (language != null) data['language'] = language;
      if (arabicLevel != null) data['arabic_level'] = arabicLevel;
      if (understandingLevel != null) data['understanding_level'] = understandingLevel;
      if (motivation != null) data['motivation'] = motivation;
      if (reciterPath != null) data['reciter'] = reciterPath;
      if (arabicFont != null) data['arabic_font'] = arabicFont;
      if (arabicFontSize != null) data['arabic_font_size'] = arabicFontSize;
      if (currentVerseKey != null) data['current_verse_key'] = currentVerseKey;

      await _db.collection('users').doc(_userId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] Failed to save profile: $e');
    }
  }

  /// Load journal entries from Firestore.
  Future<List<JournalEntry>> loadJournalEntries() async {
    if (_userId == null) return [];
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('journal')
          .orderBy('completed_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return JournalEntry(
          id: doc.id,
          verseKey: data['verse_key'] as String? ?? '1:1',
          arabicText: data['arabic_text'] as String? ?? '',
          translationText: data['translation_text'] as String? ?? '',
          tier: _parseTier(data['tier'] as String?),
          promptText: data['prompt_text'] as String?,
          responseText: data['response_text'] as String?,
          completedAt: DateTime.tryParse(data['completed_at'] as String? ?? '') ?? DateTime.now(),
          streakDay: data['streak_day'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] Failed to load journal: $e');
      return [];
    }
  }

  /// Load progress from Firestore.
  Future<Map<String, dynamic>?> loadProgress() async {
    if (_userId == null) return null;
    try {
      final doc = await _db.collection('users').doc(_userId).get();
      if (!doc.exists) return null;
      return doc.data()?['progress'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[Firestore] Failed to load progress: $e');
      return null;
    }
  }

  static ReflectionTier _parseTier(String? tier) {
    if (tier == null) return ReflectionTier.acknowledge;
    try {
      return ReflectionTier.values.byName(tier);
    } catch (_) {
      return ReflectionTier.acknowledge;
    }
  }
}
