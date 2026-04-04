class UserProgress {
  final String userId;
  final String currentVerseKey;
  final int currentStreak;
  final int longestStreak;
  final int totalAyatCompleted;
  final int totalReflections;
  final DateTime? lastCompletedAt;
  final int streakFreezes;
  final bool isTravelMode;

  const UserProgress({
    required this.userId,
    required this.currentVerseKey,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalAyatCompleted,
    required this.totalReflections,
    this.lastCompletedAt,
    required this.streakFreezes,
    required this.isTravelMode,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      userId: json['user_id'] as String,
      currentVerseKey: json['current_verse_key'] as String,
      currentStreak: json['current_streak'] as int,
      longestStreak: json['longest_streak'] as int,
      totalAyatCompleted: json['total_ayat_completed'] as int,
      totalReflections: json['total_reflections'] as int,
      lastCompletedAt: json['last_completed_at'] != null
          ? DateTime.parse(json['last_completed_at'] as String)
          : null,
      streakFreezes: json['streak_freezes'] as int,
      isTravelMode: json['is_travel_mode'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'current_verse_key': currentVerseKey,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_ayat_completed': totalAyatCompleted,
      'total_reflections': totalReflections,
      if (lastCompletedAt != null)
        'last_completed_at': lastCompletedAt!.toIso8601String(),
      'streak_freezes': streakFreezes,
      'is_travel_mode': isTravelMode,
    };
  }

  UserProgress copyWith({
    String? userId,
    String? currentVerseKey,
    int? currentStreak,
    int? longestStreak,
    int? totalAyatCompleted,
    int? totalReflections,
    DateTime? lastCompletedAt,
    int? streakFreezes,
    bool? isTravelMode,
  }) {
    return UserProgress(
      userId: userId ?? this.userId,
      currentVerseKey: currentVerseKey ?? this.currentVerseKey,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalAyatCompleted: totalAyatCompleted ?? this.totalAyatCompleted,
      totalReflections: totalReflections ?? this.totalReflections,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      isTravelMode: isTravelMode ?? this.isTravelMode,
    );
  }

  @override
  String toString() {
    return 'UserProgress(userId: $userId, currentVerseKey: $currentVerseKey, '
        'currentStreak: $currentStreak, longestStreak: $longestStreak, '
        'totalAyatCompleted: $totalAyatCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProgress &&
        other.userId == userId &&
        other.currentVerseKey == currentVerseKey &&
        other.currentStreak == currentStreak &&
        other.longestStreak == longestStreak &&
        other.totalAyatCompleted == totalAyatCompleted &&
        other.totalReflections == totalReflections &&
        other.lastCompletedAt == lastCompletedAt &&
        other.streakFreezes == streakFreezes &&
        other.isTravelMode == isTravelMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      currentVerseKey,
      currentStreak,
      longestStreak,
      totalAyatCompleted,
      totalReflections,
      lastCompletedAt,
      streakFreezes,
      isTravelMode,
    );
  }
}
