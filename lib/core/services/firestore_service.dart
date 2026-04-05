import 'package:cloud_firestore/cloud_firestore.dart';
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
  }

  /// Save user progress to Firestore.
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    if (_userId == null) return;

    await _db.collection('users').doc(_userId).set({
      'progress': progress,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Load journal entries from Firestore.
  Future<List<JournalEntry>> loadJournalEntries() async {
    if (_userId == null) return [];

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
        verseKey: data['verse_key'] as String,
        arabicText: data['arabic_text'] as String,
        translationText: data['translation_text'] as String,
        tier: ReflectionTier.values.byName(data['tier'] as String),
        promptText: data['prompt_text'] as String?,
        responseText: data['response_text'] as String?,
        completedAt: DateTime.parse(data['completed_at'] as String),
        streakDay: data['streak_day'] as int? ?? 0,
      );
    }).toList();
  }

  /// Load progress from Firestore.
  Future<Map<String, dynamic>?> loadProgress() async {
    if (_userId == null) return null;

    final doc = await _db.collection('users').doc(_userId).get();
    if (!doc.exists) return null;

    return doc.data()?['progress'] as Map<String, dynamic>?;
  }
}
