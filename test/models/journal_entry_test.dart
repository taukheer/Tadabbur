import 'package:flutter_test/flutter_test.dart';
import 'package:tadabbur/core/models/journal_entry.dart';

void main() {
  group('JournalEntry', () {
    test('fromJson creates valid entry', () {
      final json = {
        'id': 'test-1',
        'verse_key': '2:255',
        'arabic_text': 'test arabic',
        'translation_text': 'test translation',
        'tier': 'reflect',
        'prompt_text': 'How does this verse speak to you?',
        'response_text': 'It reminds me of God\'s greatness',
        'completed_at': '2026-04-08T10:00:00.000',
        'hijri_date': '10 Shawwal 1447',
        'streak_day': 5,
      };

      final entry = JournalEntry.fromJson(json);

      expect(entry.id, 'test-1');
      expect(entry.verseKey, '2:255');
      expect(entry.tier, ReflectionTier.reflect);
      expect(entry.streakDay, 5);
    });

    test('fromJson falls back to acknowledge for invalid tier', () {
      final json = {
        'id': 'test-2',
        'verse_key': '1:1',
        'arabic_text': 'text',
        'translation_text': 'text',
        'tier': 'invalid_tier',
        'completed_at': '2026-04-08T10:00:00.000',
        'streak_day': 1,
      };

      final entry = JournalEntry.fromJson(json);
      expect(entry.tier, ReflectionTier.acknowledge);
    });

    test('toJson roundtrip preserves data', () {
      final entry = JournalEntry(
        id: 'rt-1',
        verseKey: '3:14',
        arabicText: 'arabic',
        translationText: 'translation',
        tier: ReflectionTier.respond,
        completedAt: DateTime(2026, 4, 8),
        streakDay: 10,
      );

      final json = entry.toJson();
      final restored = JournalEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.verseKey, entry.verseKey);
      expect(restored.tier, entry.tier);
      expect(restored.streakDay, entry.streakDay);
    });

    test('copyWith creates modified copy', () {
      final entry = JournalEntry(
        id: 'cw-1',
        verseKey: '1:1',
        arabicText: 'a',
        translationText: 't',
        tier: ReflectionTier.acknowledge,
        completedAt: DateTime(2026, 4, 1),
        streakDay: 1,
      );

      final modified = entry.copyWith(tier: ReflectionTier.reflect, streakDay: 5);

      expect(modified.tier, ReflectionTier.reflect);
      expect(modified.streakDay, 5);
      expect(modified.id, entry.id);
    });

    test('equality works correctly', () {
      final a = JournalEntry(
        id: 'eq-1',
        verseKey: '1:1',
        arabicText: 'a',
        translationText: 't',
        tier: ReflectionTier.acknowledge,
        completedAt: DateTime(2026, 4, 1),
        streakDay: 1,
      );
      final b = JournalEntry(
        id: 'eq-1',
        verseKey: '1:1',
        arabicText: 'a',
        translationText: 't',
        tier: ReflectionTier.acknowledge,
        completedAt: DateTime(2026, 4, 1),
        streakDay: 1,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
