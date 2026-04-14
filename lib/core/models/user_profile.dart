import 'package:flutter/foundation.dart' show debugPrint;

enum ArabicLevel {
  fluent,    // "I can read Arabic fluently"
  basic,     // "I can read Arabic slowly"
  none,      // "I cannot read Arabic"
}

enum UnderstandingLevel {
  most,      // "I understand most of what I recite"
  some,      // "I understand some words"
  none,      // "I don't understand what I recite"
}

enum Motivation {
  salah,     // "I want to understand what I say in prayer"
  connection,// "I want a deeper relationship with the Quran"
  practice,  // "I want to start a daily Quran habit"
  learning,  // "I'm learning about Islam"
}

class UserProfile {
  final ArabicLevel arabicLevel;
  final UnderstandingLevel understandingLevel;
  final Motivation motivation;
  final String? preferredTime; // "After Fajr", "Morning", "After Isha"

  const UserProfile({
    required this.arabicLevel,
    required this.understandingLevel,
    required this.motivation,
    this.preferredTime,
  });

  bool get needsTransliteration => arabicLevel == ArabicLevel.none;
  bool get needsWordByWord => understandingLevel != UnderstandingLevel.most;
  bool get isSalahMotivated => motivation == Motivation.salah;
  bool get isBeginnerFriendly =>
      arabicLevel == ArabicLevel.none &&
      understandingLevel == UnderstandingLevel.none;

  Map<String, dynamic> toJson() => {
        'arabic_level': arabicLevel.name,
        'understanding_level': understandingLevel.name,
        'motivation': motivation.name,
        'preferred_time': preferredTime,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    ArabicLevel arabicLevel;
    try {
      arabicLevel = ArabicLevel.values.byName(json['arabic_level'] as String);
    } catch (_) {
      debugPrint(
        '[UserProfile] unknown arabic_level=${json['arabic_level']} '
        '— defaulting to none',
      );
      arabicLevel = ArabicLevel.none;
    }

    UnderstandingLevel understandingLevel;
    try {
      understandingLevel =
          UnderstandingLevel.values.byName(json['understanding_level'] as String);
    } catch (_) {
      debugPrint(
        '[UserProfile] unknown understanding_level=${json['understanding_level']} '
        '— defaulting to none',
      );
      understandingLevel = UnderstandingLevel.none;
    }

    Motivation motivation;
    try {
      motivation = Motivation.values.byName(json['motivation'] as String);
    } catch (_) {
      debugPrint(
        '[UserProfile] unknown motivation=${json['motivation']} '
        '— defaulting to connection',
      );
      motivation = Motivation.connection;
    }

    return UserProfile(
      arabicLevel: arabicLevel,
      understandingLevel: understandingLevel,
      motivation: motivation,
      preferredTime: json['preferred_time'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.arabicLevel == arabicLevel &&
        other.understandingLevel == understandingLevel &&
        other.motivation == motivation &&
        other.preferredTime == preferredTime;
  }

  @override
  int get hashCode => Object.hash(
        arabicLevel,
        understandingLevel,
        motivation,
        preferredTime,
      );
}
