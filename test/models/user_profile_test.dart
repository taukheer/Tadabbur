import 'package:flutter_test/flutter_test.dart';
import 'package:tadabbur/core/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('fromJson creates valid profile', () {
      final json = {
        'arabic_level': 'fluent',
        'understanding_level': 'most',
        'motivation': 'salah',
        'preferred_time': 'After Fajr',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.arabicLevel, ArabicLevel.fluent);
      expect(profile.understandingLevel, UnderstandingLevel.most);
      expect(profile.motivation, Motivation.salah);
      expect(profile.preferredTime, 'After Fajr');
    });

    test('fromJson uses fallback for invalid enum values', () {
      final json = {
        'arabic_level': 'expert',
        'understanding_level': 'lots',
        'motivation': 'fun',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.arabicLevel, ArabicLevel.none);
      expect(profile.understandingLevel, UnderstandingLevel.none);
      expect(profile.motivation, Motivation.connection);
    });

    test('toJson roundtrip preserves data', () {
      const profile = UserProfile(
        arabicLevel: ArabicLevel.basic,
        understandingLevel: UnderstandingLevel.some,
        motivation: Motivation.practice,
        preferredTime: 'Morning',
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.arabicLevel, profile.arabicLevel);
      expect(restored.understandingLevel, profile.understandingLevel);
      expect(restored.motivation, profile.motivation);
      expect(restored.preferredTime, profile.preferredTime);
    });

    test('computed properties work', () {
      const beginner = UserProfile(
        arabicLevel: ArabicLevel.none,
        understandingLevel: UnderstandingLevel.none,
        motivation: Motivation.salah,
      );

      expect(beginner.needsTransliteration, true);
      expect(beginner.needsWordByWord, true);
      expect(beginner.isSalahMotivated, true);
      expect(beginner.isBeginnerFriendly, true);

      const fluent = UserProfile(
        arabicLevel: ArabicLevel.fluent,
        understandingLevel: UnderstandingLevel.most,
        motivation: Motivation.connection,
      );

      expect(fluent.needsTransliteration, false);
      expect(fluent.needsWordByWord, false);
      expect(fluent.isSalahMotivated, false);
      expect(fluent.isBeginnerFriendly, false);
    });
  });
}
