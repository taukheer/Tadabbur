import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';

enum SyncStatus { idle, syncing, failed, success }

/// Firestore sync service with persistent pending-write tracking.
///
/// Each write (journal entry, bookmark, progress) is marked pending in
/// [LocalStorageService] before the network call and cleared on success.
/// If the app crashes or the request fails, the pending entry survives and
/// is replayed by [flushPendingSyncs] (called on user login and after
/// successful writes).
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _userId;

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _syncStatus;
  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;

  bool _flushing = false;

  void setUser(String userId) {
    _userId = userId;
  }

  bool get hasUser => _userId != null;

  int pendingCount(LocalStorageService storage) =>
      storage.getPendingJournalSyncIds().length +
      storage.getPendingBookmarkSyncKeys().length +
      storage.getPendingBookmarkRemovalKeys().length +
      (storage.hasPendingProgressSync ? 1 : 0);

  /// Retry a failed write up to [maxAttempts] times with linear backoff.
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
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Journal
  // ---------------------------------------------------------------------------

  /// Save a journal entry to Firestore. Marks the entry ID as pending in
  /// [storage] before the call; clears it on success. If [storage] is null,
  /// the caller is responsible for retry bookkeeping.
  Future<void> saveJournalEntry(
    JournalEntry entry, {
    LocalStorageService? storage,
  }) async {
    if (_userId == null) return;
    if (storage != null) {
      await storage.addPendingJournalSyncId(entry.id);
    }
    _syncStatus = SyncStatus.syncing;
    await _withRetry(() => _writeJournalEntry(entry));
    if (storage != null) {
      await storage.removePendingJournalSyncId(entry.id);
    }
  }

  Future<void> _writeJournalEntry(JournalEntry entry) async {
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

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  Future<void> saveProgress(
    Map<String, dynamic> progress, {
    LocalStorageService? storage,
  }) async {
    if (_userId == null) return;
    if (storage != null) {
      await storage.setPendingProgressSync(true);
    }
    await _withRetry(() => _writeProgress(progress));
    if (storage != null) {
      await storage.setPendingProgressSync(false);
    }
  }

  Future<void> _writeProgress(Map<String, dynamic> progress) async {
    await _db.collection('users').doc(_userId).set({
      'progress': progress,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // User profile
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  Future<void> saveBookmark(
    Bookmark bookmark, {
    LocalStorageService? storage,
  }) async {
    if (_userId == null) return;
    if (storage != null) {
      await storage.addPendingBookmarkSyncKey(bookmark.verseKey);
    }
    _syncStatus = SyncStatus.syncing;
    await _withRetry(() => _writeBookmark(bookmark));
    if (storage != null) {
      await storage.removePendingBookmarkSyncKey(bookmark.verseKey);
    }
  }

  Future<void> _writeBookmark(Bookmark bookmark) async {
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
  }

  Future<void> removeBookmark(
    String verseKey, {
    LocalStorageService? storage,
  }) async {
    if (_userId == null) return;
    if (storage != null) {
      // If the bookmark was still pending add, just drop it from the add queue
      // and skip the remote call — nothing to delete.
      if (storage.getPendingBookmarkSyncKeys().contains(verseKey)) {
        await storage.removePendingBookmarkSyncKey(verseKey);
        return;
      }
      await storage.addPendingBookmarkRemovalKey(verseKey);
    }
    await _withRetry(() => _deleteBookmark(verseKey));
    if (storage != null) {
      await storage.removePendingBookmarkRemovalKey(verseKey);
    }
  }

  Future<void> _deleteBookmark(String verseKey) async {
    await _db
        .collection('users')
        .doc(_userId)
        .collection('bookmarks')
        .doc(verseKey.replaceAll(':', '_'))
        .delete();
  }

  // ---------------------------------------------------------------------------
  // Replay pending writes
  // ---------------------------------------------------------------------------

  /// Replay any writes that were marked pending but never confirmed with
  /// Firestore. Safe to call repeatedly; no-op when no user is set or when
  /// a flush is already in progress.
  Future<void> flushPendingSyncs(LocalStorageService storage) async {
    if (_userId == null || _flushing) return;
    _flushing = true;
    try {
      // Journal entries
      final pendingJournalIds = storage.getPendingJournalSyncIds();
      if (pendingJournalIds.isNotEmpty) {
        final byId = {for (final e in storage.getJournalEntries()) e.id: e};
        for (final id in pendingJournalIds) {
          final entry = byId[id];
          if (entry == null) {
            // Local entry was deleted — nothing to sync.
            await storage.removePendingJournalSyncId(id);
            continue;
          }
          try {
            await _writeJournalEntry(entry);
            await storage.removePendingJournalSyncId(id);
          } catch (e) {
            debugPrint('[Firestore] Journal replay failed for $id: $e');
            // Leave pending; will retry on next flush.
          }
        }
      }

      // Bookmark additions
      final pendingBookmarkKeys = storage.getPendingBookmarkSyncKeys();
      if (pendingBookmarkKeys.isNotEmpty) {
        final byKey = {for (final b in storage.getBookmarks()) b.verseKey: b};
        for (final key in pendingBookmarkKeys) {
          final bookmark = byKey[key];
          if (bookmark == null) {
            await storage.removePendingBookmarkSyncKey(key);
            continue;
          }
          try {
            await _writeBookmark(bookmark);
            await storage.removePendingBookmarkSyncKey(key);
          } catch (e) {
            debugPrint('[Firestore] Bookmark replay failed for $key: $e');
          }
        }
      }

      // Bookmark removals
      final pendingRemovals = storage.getPendingBookmarkRemovalKeys();
      if (pendingRemovals.isNotEmpty) {
        for (final key in pendingRemovals) {
          try {
            await _deleteBookmark(key);
            await storage.removePendingBookmarkRemovalKey(key);
          } catch (e) {
            debugPrint('[Firestore] Bookmark removal replay failed: $e');
          }
        }
      }

      // Progress
      if (storage.hasPendingProgressSync) {
        final progress = storage.getProgress();
        if (progress != null) {
          try {
            await _writeProgress(progress.toJson());
            await storage.setPendingProgressSync(false);
          } catch (e) {
            debugPrint('[Firestore] Progress replay failed: $e');
          }
        } else {
          await storage.setPendingProgressSync(false);
        }
      }
    } finally {
      _flushing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Delete / Restore
  // ---------------------------------------------------------------------------

  /// Delete ALL user data from Firestore (used by Delete Account).
  Future<void> deleteUserData() async {
    if (_userId == null) return;
    try {
      final userDoc = _db.collection('users').doc(_userId);
      await _deleteSubcollection(userDoc.collection('journal'));
      await _deleteSubcollection(userDoc.collection('bookmarks'));
      await userDoc.delete();
      debugPrint('[Firestore] User data deleted');
    } catch (e) {
      debugPrint('[Firestore] Failed to delete user data: $e');
      rethrow;
    }
  }

  Future<void> _deleteSubcollection(CollectionReference ref) async {
    final snapshot = await ref.limit(500).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (snapshot.docs.length == 500) {
      await _deleteSubcollection(ref);
    }
  }

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
