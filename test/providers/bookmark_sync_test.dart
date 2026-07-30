// firebase_core_platform_interface is a transitive dep pulled in only for
// its test harness — same exemption widget_test.dart takes.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadabbur/core/models/bookmark.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/firestore_service.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/services/quran_api_service.dart';
import 'package:tadabbur/core/services/user_api_service.dart';

/// Records the QF calls a [BookmarkNotifier] makes. Declaring
/// `noSuchMethod` lets Dart forward the rest of the (large) service
/// surface, so only the bookmark endpoints need stubbing.
class _FakeUserApi implements UserApiService {
  /// Bookmarks the server believes it holds, in QF's wire shape.
  final List<Map<String, dynamic>> remote;

  /// Id returned by the next POST; null models a response with no id.
  int? nextId;

  final List<String> added = [];
  final List<dynamic> deleted = [];
  int getBookmarksCalls = 0;

  _FakeUserApi({this.remote = const [], this.nextId});

  @override
  Future<int?> addBookmark(String verseKey) async {
    added.add(verseKey);
    return nextId;
  }

  @override
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    getBookmarksCalls++;
    return remote;
  }

  @override
  Future<void> removeBookmark(dynamic bookmarkId) async {
    deleted.add(bookmarkId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirestoreService {
  @override
  Future<void> saveBookmark(Bookmark bookmark,
          {LocalStorageService? storage}) async {}

  @override
  Future<void> removeBookmark(String verseKey,
          {LocalStorageService? storage}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuranApi implements QuranApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `LocalStorageService.init` preloads OAuth tokens from
/// flutter_secure_storage, which has no implementation in a unit-test
/// host. Stub the channel so `init()` completes.
void _stubSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
}

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService();
  await storage.init();
  return storage;
}

/// QF's bookmark wire shape: `key` is the surah, `verseNumber` the ayah.
Map<String, dynamic> _remoteBookmark(int id, String verseKey) {
  final parts = verseKey.split(':');
  return {
    'id': id,
    'key': int.parse(parts[0]),
    'verseNumber': int.parse(parts[1]),
    'type': 'ayah',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // add/remove log analytics events, which touch FirebaseAnalytics.instance.
  setupFirebaseCoreMocks();

  setUpAll(() async {
    _stubSecureStorage();
    await Firebase.initializeApp();
  });

  group('BookmarkNotifier QF id round-trip', () {
    test('add persists the id QF returns', () async {
      final userApi = _FakeUserApi(nextId: 4242);
      final notifier = BookmarkNotifier(
        await _storage(),
        userApi,
        _FakeFirestore(),
        _FakeQuranApi(),
      );

      await notifier.add(
        verseKey: '2:255',
        arabicText: 'a',
        translationText: 't',
      );
      await pumpEventQueue();

      expect(userApi.added, ['2:255']);
      expect(notifier.state.single.qfBookmarkId, 4242,
          reason: 'without the id, remove() can never issue the DELETE');
    });

    test('remove deletes server-side using the stored id', () async {
      final userApi = _FakeUserApi(nextId: 7);
      final notifier = BookmarkNotifier(
        await _storage(),
        userApi,
        _FakeFirestore(),
        _FakeQuranApi(),
      );

      await notifier.add(verseKey: '1:1', arabicText: 'a', translationText: 't');
      await pumpEventQueue();
      await notifier.remove('1:1');
      await pumpEventQueue();

      expect(notifier.state, isEmpty);
      expect(userApi.deleted, [7]);
      expect(userApi.getBookmarksCalls, 0,
          reason: 'id was already known — no lookup needed');
    });

    test('remove resolves a missing id rather than skipping the DELETE',
        () async {
      // Models a bookmark saved before the id was persisted: present
      // locally with no qfBookmarkId, but live on the server.
      final userApi = _FakeUserApi(remote: [_remoteBookmark(99, '18:10')]);
      final storage = await _storage();
      await storage.saveBookmarks([
        Bookmark(
          verseKey: '18:10',
          arabicText: 'a',
          translationText: 't',
          bookmarkedAt: DateTime(2026, 7, 1),
        ),
      ]);
      final notifier = BookmarkNotifier(
        storage,
        userApi,
        _FakeFirestore(),
        _FakeQuranApi(),
      );
      expect(notifier.state.single.qfBookmarkId, isNull);

      await notifier.remove('18:10');
      await pumpEventQueue();

      expect(userApi.deleted, [99],
          reason: 'a skipped DELETE lets hydrateFromQF resurrect the bookmark');
    });

    test('remove tolerates a verse the server does not know about', () async {
      final userApi = _FakeUserApi(remote: [_remoteBookmark(99, '18:10')]);
      final storage = await _storage();
      await storage.saveBookmarks([
        Bookmark(
          verseKey: '3:5',
          arabicText: 'a',
          translationText: 't',
          bookmarkedAt: DateTime(2026, 7, 1),
        ),
      ]);
      final notifier = BookmarkNotifier(
        storage,
        userApi,
        _FakeFirestore(),
        _FakeQuranApi(),
      );

      await notifier.remove('3:5');
      await pumpEventQueue();

      expect(notifier.state, isEmpty);
      expect(userApi.deleted, isEmpty);
    });

    test('a null id from QF leaves the bookmark usable locally', () async {
      final userApi = _FakeUserApi(nextId: null);
      final notifier = BookmarkNotifier(
        await _storage(),
        userApi,
        _FakeFirestore(),
        _FakeQuranApi(),
      );

      await notifier.add(verseKey: '5:5', arabicText: 'a', translationText: 't');
      await pumpEventQueue();

      expect(notifier.state.single.qfBookmarkId, isNull);
      expect(notifier.isBookmarked('5:5'), isTrue);
    });
  });
}
