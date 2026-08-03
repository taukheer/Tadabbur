// Covers the half-page / page reading modes.
//
// The risky part of this feature is the arithmetic, not the UI: split a
// page in the wrong place and the reader silently re-reads or skips
// verses every morning, with nothing on screen to indicate it.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/models/daily_portion.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/features/daily_ayah/screens/daily_ayah_screen.dart'
    show arabicSizeForBlock;
import 'package:flutter/services.dart';

Ayah _v(int surah, int ayah, {int page = 1}) => Ayah(
      id: surah * 1000 + ayah,
      verseKey: '$surah:$ayah',
      surahNumber: surah,
      ayahNumber: ayah,
      textUthmani: 'verse $surah:$ayah',
      pageNumber: page,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyPortion', () {
    test('unknown and missing ids fall back to a single ayah', () {
      expect(DailyPortion.fromId(null), DailyPortion.ayah);
      expect(DailyPortion.fromId('nonsense'), DailyPortion.ayah);
      expect(DailyPortion.fromId('ayah'), DailyPortion.ayah);
    });

    test('ids round-trip', () {
      for (final mode in DailyPortion.values) {
        expect(DailyPortion.fromId(mode.id), mode);
      }
    });

    test('only the multi-verse modes count as a passage', () {
      expect(DailyPortion.ayah.isPassage, isFalse);
      expect(DailyPortion.halfPage.isPassage, isTrue);
      expect(DailyPortion.page.isPassage, isTrue);
    });
  });

  group('half-page split', () {
    test('an even page splits down the middle', () {
      final page = [for (var i = 1; i <= 8; i++) _v(2, i)];

      final firstHalf = Portion.halfOfPage(page, '2:1');
      expect(firstHalf.map((v) => v.verseKey), ['2:1', '2:2', '2:3', '2:4']);

      final secondHalf = Portion.halfOfPage(page, '2:5');
      expect(secondHalf.map((v) => v.verseKey), ['2:5', '2:6', '2:7', '2:8']);
    });

    test('an odd page front-loads the extra verse', () {
      final page = [for (var i = 1; i <= 7; i++) _v(1, i)];

      expect(Portion.halfOfPage(page, '1:1').length, 4);
      expect(Portion.halfOfPage(page, '1:5').length, 3);
    });

    test('the two halves partition the page exactly — no gap, no overlap',
        () {
      // Page 582 really does carry 30 verses; the dense pages are where
      // an off-by-one hides best.
      for (final size in [2, 5, 8, 9, 15, 30]) {
        final page = [for (var i = 1; i <= size; i++) _v(78, i)];
        final first = Portion.halfOfPage(page, '78:1');
        final second = Portion.halfOfPage(page, page.last.verseKey);

        expect([...first, ...second].map((v) => v.verseKey),
            page.map((v) => v.verseKey),
            reason: 'halves of a $size-verse page must reassemble it');
      }
    });

    test('a one-verse page is returned whole rather than split to nothing',
        () {
      final page = [_v(112, 1)];
      expect(Portion.halfOfPage(page, '112:1'), page);
    });

    test('an anchor that is not on the page defaults to the first half', () {
      final page = [for (var i = 1; i <= 6; i++) _v(3, i)];
      expect(Portion.halfOfPage(page, '99:9').length, 3);
    });
  });

  group('range labels', () {
    test('a single verse has no range', () {
      final p = Portion(verses: [_v(36, 1)], mode: DailyPortion.ayah);
      expect(p.rangeLabel, '36:1');
      expect(p.isPassage, isFalse);
    });

    test('a range within one surah abbreviates the end', () {
      final p = Portion(
        verses: [for (var i = 1; i <= 10; i++) _v(36, i)],
        mode: DailyPortion.page,
      );
      expect(p.rangeLabel, '36:1–10');
      expect(p.length, 10);
    });

    test('a range crossing surahs keeps both keys', () {
      // Page 604 spans Al-Ikhlas, Al-Falaq and An-Nas, so this is the
      // normal case at the end of the mushaf, not an edge case.
      final p = Portion(
        verses: [_v(112, 1, page: 604), _v(114, 6, page: 604)],
        mode: DailyPortion.page,
      );
      expect(p.rangeLabel, '112:1–114:6');
    });
  });

  group('journal entries record the range', () {
    JournalEntry entryWith({String? end, int count = 1}) => JournalEntry(
          id: 'x',
          verseKey: '36:1',
          verseKeyEnd: end,
          verseCount: count,
          arabicText: 'a',
          translationText: 't',
          tier: ReflectionTier.acknowledge,
          completedAt: DateTime(2026, 8, 3),
          streakDay: 1,
        );

    test('a single-verse entry looks exactly as it always did', () {
      final e = entryWith();
      expect(e.isPassage, isFalse);
      expect(e.rangeLabel, '36:1');
      // Absent from JSON entirely, so old readers are unaffected.
      expect(e.toJson().containsKey('verse_key_end'), isFalse);
      expect(e.toJson().containsKey('verse_count'), isFalse);
    });

    test('a passage entry carries its span', () {
      final e = entryWith(end: '36:10', count: 10);
      expect(e.isPassage, isTrue);
      expect(e.rangeLabel, '36:1–10');
      expect(e.toJson()['verse_count'], 10);
    });

    test('entries written before this feature deserialize as a range of one',
        () {
      final legacy = {
        'id': 'x',
        'verse_key': '36:1',
        'arabic_text': 'a',
        'translation_text': 't',
        'tier': 'acknowledge',
        'completed_at': DateTime(2026, 8, 3).toIso8601String(),
        'streak_day': 1,
      };
      final e = JournalEntry.fromJson(legacy);
      expect(e.verseCount, 1);
      expect(e.verseKeyEnd, isNull);
      expect(e.isPassage, isFalse);
    });

    test('the reading mode is recorded, not just the size', () {
      // A half-page that held ten verses and a full page that held ten
      // are the same size but not the same intention — the journal has
      // to be able to tell them apart.
      final half = entryWith(end: '36:10', count: 10)
          .copyWith(portionId: 'half_page');
      final full =
          entryWith(end: '36:10', count: 10).copyWith(portionId: 'page');

      expect(half.verseCount, full.verseCount);
      expect(half.portionId, isNot(full.portionId));
      expect(JournalEntry.fromJson(half.toJson()).portionId, 'half_page');
      expect(JournalEntry.fromJson(full.toJson()).portionId, 'page');
    });

    test('legacy entries carry no mode and stay single verses', () {
      final e = entryWith();
      expect(e.portionId, isNull);
      expect(e.toJson().containsKey('portion_id'), isFalse);
    });

    test('a passage entry stores every verse it covered', () {
      final e = entryWith(end: '36:3', count: 3).copyWith(
        portionId: 'page',
        verses: const [
          JournalVerse(verseKey: '36:1', arabicText: 'يسٓ', translationText: 'Ya, Seen.'),
          JournalVerse(verseKey: '36:2', arabicText: 'وَٱلْقُرْءَانِ', translationText: 'By the wise Quran'),
          JournalVerse(verseKey: '36:3', arabicText: 'إِنَّكَ', translationText: 'You are indeed'),
        ],
      );
      expect(e.allVerses.length, 3);
      expect(e.allVerses.map((v) => v.verseKey), ['36:1', '36:2', '36:3']);
      expect(e.allVerses[1].translationText, 'By the wise Quran');

      final back = JournalEntry.fromJson(e.toJson());
      expect(back.allVerses.length, 3);
      expect(back.allVerses.last.arabicText, 'إِنَّكَ');
    });

    test('a single-ayah entry reads back through the same accessor', () {
      // Ayah mode stores no verse list — duplicating arabicText would
      // double the journal for the default mode — but callers must not
      // have to care which shape they got.
      final e = entryWith();
      expect(e.verses, isEmpty);
      expect(e.allVerses.length, 1);
      expect(e.allVerses.single.verseKey, '36:1');
      expect(e.allVerses.single.arabicText, 'a');
      expect(e.toJson().containsKey('verses'), isFalse);
    });

    test('a passage entry survives a JSON round-trip', () {
      final e = entryWith(end: '36:10', count: 10);
      final back = JournalEntry.fromJson(e.toJson());
      expect(back.verseKeyEnd, '36:10');
      expect(back.verseCount, 10);
      expect(back.rangeLabel, e.rangeLabel);
    });
  });

  group('arabic sizing across a passage', () {
    // The anchor verse and the rest of the page are rendered by two
    // different widgets. They must agree on size, or consecutive ayat
    // of one page appear at different scales — which reads as a bug.
    test('one size is chosen for the whole block', () {
      const base = 36.0;
      expect(arabicSizeForBlock(20, base), base);
      expect(arabicSizeForBlock(60, base), base * 0.8);
      expect(arabicSizeForBlock(150, base), base * 0.65);
    });

    test('a short verse next to a long one is sized by the long one', () {
      const base = 36.0;
      const shortVerse = 20;
      const longVerse = 150;
      final blockSize = arabicSizeForBlock(
        [shortVerse, longVerse].reduce((a, b) => a > b ? a : b),
        base,
      );
      // Both verses render at the long verse's size, not their own.
      expect(blockSize, arabicSizeForBlock(longVerse, base));
      expect(blockSize, isNot(arabicSizeForBlock(shortVerse, base)));
    });

    test('sizing never grows past the user\'s chosen point size', () {
      for (final base in [28.0, 36.0, 44.0, 52.0]) {
        for (final len in [1, 49, 50, 51, 100, 101, 500]) {
          expect(arabicSizeForBlock(len, base), lessThanOrEqualTo(base));
          expect(arabicSizeForBlock(len, base), greaterThan(0));
        }
      }
    });
  });

  group('portion preference', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
    });

    Future<LocalStorageService> storage() async {
      SharedPreferences.setMockInitialValues({});
      final s = LocalStorageService();
      await s.init();
      return s;
    }

    test('defaults to one ayah — nobody is migrated by an update', () async {
      final s = await storage();
      expect(s.dailyPortion, 'ayah');
      expect(DailyPortion.fromId(s.dailyPortion), DailyPortion.ayah);
    });

    test('round-trips the choice', () async {
      final s = await storage();
      for (final mode in DailyPortion.values) {
        await s.setDailyPortion(mode.id);
        expect(DailyPortion.fromId(s.dailyPortion), mode);
      }
    });
  });
}
