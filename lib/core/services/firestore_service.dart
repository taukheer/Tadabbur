import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/models/journal_entry.dart';

enum SyncStatus { idle, syncing, failed, success }

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _userId;

  /// Current sync status — UI can watch this to show feedback.
  SyncStatus _syncStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _syncStatus;
  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;

  /// Pending operations that failed and need retry (capped to prevent memory leaks).
  static const _maxRetryQueue = 50;
  final List<Future<void> Function()> _retryQueue = [];
  bool _retrying = false;
  DateTime? _lastFlushAttempt;
  int get pendingRetryCount => _retryQueue.length;

  void setUser(String userId) {
    _userId = userId;
    // Flush any pending retries when user is set
    _flushRetryQueue();
  }

  bool get hasUser => _userId != null;

  /// Retry a failed operation up to [maxAttempts] times with backoff.
  Future<void> _withRetry(
    Future<void> Function() operation, {
    int maxAttempts = 3,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await operation();
        _syncStatus = SyncStatus.success;
        _lastSyncError = null;
        return;
      } catch (e) {
        debugPrint('[Firestore] Attempt $attempt failed: $e');
        if (attempt == maxAttempts) {
          _syncStatus = SyncStatus.failed;
          _lastSyncError = e.toString();
          // Queue for later retry (drop oldest if full)
          if (_retryQueue.length >= _maxRetryQueue) {
            _retryQueue.removeAt(0);
            debugPrint('[Firestore] Retry queue full — dropped oldest');
          }
          _retryQueue.add(operation);
          debugPrint('[Firestore] Queued for retry (${_retryQueue.length} pending)');
          return;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  /// Flush the retry queue — called on connectivity restore or user set.
  Future<void> _flushRetryQueue() async {
    if (_retrying || _retryQueue.isEmpty) return;
    // Throttle: don't flush more than once per 30 seconds
    final now = DateTime.now();
    if (_lastFlushAttempt != null &&
        now.difference(_lastFlushAttempt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastFlushAttempt = now;
    _retrying = true;
    try {
      while (_retryQueue.isNotEmpty) {
        final op = _retryQueue.removeAt(0);
        try {
          await op();
        } catch (e) {
          debugPrint('[Firestore] Retry still failing: $e');
          // Put it back and stop — will try again later
          _retryQueue.insert(0, op);
          break;
        }
      }
    } finally {
      _retrying = false;
    }
  }

  /// Save a journal entry to Firestore.
  Future<void> saveJournalEntry(JournalEntry entry) async {
    if (_userId == null) return;
    _syncStatus = SyncStatus.syncing;
    await _withRetry(() async {
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
    });
  }

  /// Save user progress to Firestore.
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    if (_userId == null) return;
    await _withRetry(() async {
      await _db.collection('users').doc(_userId).set({
        'progress': progress,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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

    await _withRetry(() async {
      await _db.collection('users').doc(_userId).set(data, SetOptions(merge: true));
    });
  }

  /// Save a bookmark to Firestore.
  Future<void> saveBookmark(Bookmark bookmark) async {
    if (_userId == null) return;
    _syncStatus = SyncStatus.syncing;
    await _withRetry(() async {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('bookmarks')
          .doc(bookmark.verseKey.replaceAll(':', '_'))
          .set({
        'verse_key': bookmark.verseKey,
        'arabic_text': bookmark.arabicText,
        'translation_text': bookmark.translationText,
        'bookmarked_at': bookmark.bookmarkedAt.toIso8601String(),
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Remove a bookmark from Firestore.
  Future<void> removeBookmark(String verseKey) async {
    if (_userId == null) return;
    await _withRetry(() async {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('bookmarks')
          .doc(verseKey.replaceAll(':', '_'))
          .delete();
    });
  }

  /// Delete ALL user data from Firestore (used by Delete Account).
  /// Deletes the user document and all subcollections (journal, bookmarks).
  Future<void> deleteUserData() async {
    if (_userId == null) return;
    try {
      final userDoc = _db.collection('users').doc(_userId);

      // Delete journal subcollection in batches of 500 (Firestore limit)
      await _deleteSubcollection(userDoc.collection('journal'));

      // Delete bookmarks subcollection
      await _deleteSubcollection(userDoc.collection('bookmarks'));

      // Delete the main user document
      await userDoc.delete();

      debugPrint('[Firestore] User data deleted');
    } catch (e) {
      debugPrint('[Firestore] Failed to delete user data: $e');
      rethrow;
    }
  }

  /// Helper to delete all docs in a subcollection.
  Future<void> _deleteSubcollection(CollectionReference ref) async {
    final snapshot = await ref.limit(500).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Recurse if there were more than 500 (rare for this app)
    if (snapshot.docs.length == 500) {
      await _deleteSubcollection(ref);
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
