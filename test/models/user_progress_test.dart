import 'package:flutter_test/flutter_test.dart';
import 'package:tadabbur/core/models/user_progress.dart';
import 'package:tadabbur/core/providers/app_providers.dart';

void main() {
  group('UserProgress', () {
    test('fromJson creates valid progress', () {
      final json = {
        'user_id': 'u1',
        'current_verse_key': '2:1',
        'current_streak': 7,
        'longest_streak': 14,
        'total_ayat_completed': 50,
        'total_reflections': 30,
        'last_completed_at': '2026-04-07T08:00:00.000',
        'started_at': '2026-03-01T08:00:00.000',
        'streak_freezes': 2,
        'is_travel_mode': false,
      };

      final progress = UserProgress.fromJson(json);

      expect(progress.userId, 'u1');
      expect(progress.currentVerseKey, '2:1');
      expect(progress.currentStreak, 7);
      expect(progress.longestStreak, 14);
      expect(progress.totalAyatCompleted, 50);
      expect(progress.streakFreezes, 2);
    });

    test('toJson roundtrip preserves data', () {
      final progress = UserProgress(
        userId: 'rt-1',
        currentVerseKey: '3:14',
        currentStreak: 5,
        longestStreak: 10,
        totalAyatCompleted: 20,
        totalReflections: 15,
        lastCompletedAt: DateTime(2026, 4, 7),
        startedAt: DateTime(2026, 3, 1),
        streakFreezes: 1,
        isTravelMode: false,
      );

      final json = progress.toJson();
      final restored = UserProgress.fromJson(json);

      expect(restored.userId, progress.userId);
      expect(restored.currentVerseKey, progress.currentVerseKey);
      expect(restored.currentStreak, progress.currentStreak);
    });

    test('copyWith creates modified copy', () {
      const progress = UserProgress(
        userId: 'u1',
        currentVerseKey: '1:1',
        currentStreak: 0,
        longestStreak: 0,
        totalAyatCompleted: 0,
        totalReflections: 0,
        streakFreezes: 0,
        isTravelMode: false,
      );

      final modified = progress.copyWith(currentStreak: 3, currentVerseKey: '1:4');

      expect(modified.currentStreak, 3);
      expect(modified.currentVerseKey, '1:4');
      expect(modified.userId, 'u1');
    });
  });

  group('UserProgressNotifier', () {
    test('isLastAyahOfSurah detects end of surah', () {
      expect(UserProgressNotifier.isLastAyahOfSurah('1:7'), true);
      expect(UserProgressNotifier.isLastAyahOfSurah('1:1'), false);
      expect(UserProgressNotifier.isLastAyahOfSurah('2:286'), true);
      expect(UserProgressNotifier.isLastAyahOfSurah('114:6'), true);
    });

    test('surahFromKey extracts surah number', () {
      expect(UserProgressNotifier.surahFromKey('2:255'), 2);
      expect(UserProgressNotifier.surahFromKey('114:1'), 114);
      expect(UserProgressNotifier.surahFromKey('invalid'), 1);
    });
  });
}
