enum ReflectionTier { acknowledge, respond, reflect }

class JournalEntry {
  final String id;
  final String verseKey;
  final String arabicText;
  final String translationText;
  final ReflectionTier tier;
  final String? promptText;
  final String? responseText;
  final DateTime completedAt;
  final String? hijriDate;
  final int streakDay;
  /// Whether the user has pinned this reflection. Pinned entries
  /// float to a dedicated section at the top of the journal — the
  /// user's anchor points. Added with a default of false so existing
  /// serialized entries deserialize cleanly without a migration.
  final bool isPinned;

  const JournalEntry({
    required this.id,
    required this.verseKey,
    required this.arabicText,
    required this.translationText,
    required this.tier,
    this.promptText,
    this.responseText,
    required this.completedAt,
    this.hijriDate,
    required this.streakDay,
    this.isPinned = false,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      verseKey: json['verse_key'] as String,
      arabicText: json['arabic_text'] as String,
      translationText: json['translation_text'] as String,
      tier: ReflectionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => ReflectionTier.acknowledge,
      ),
      promptText: json['prompt_text'] as String?,
      responseText: json['response_text'] as String?,
      completedAt: DateTime.parse(json['completed_at'] as String),
      hijriDate: json['hijri_date'] as String?,
      streakDay: json['streak_day'] as int,
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verse_key': verseKey,
      'arabic_text': arabicText,
      'translation_text': translationText,
      'tier': tier.name,
      if (promptText != null) 'prompt_text': promptText,
      if (responseText != null) 'response_text': responseText,
      'completed_at': completedAt.toIso8601String(),
      if (hijriDate != null) 'hijri_date': hijriDate,
      'streak_day': streakDay,
      if (isPinned) 'is_pinned': true,
    };
  }

  JournalEntry copyWith({
    String? id,
    String? verseKey,
    String? arabicText,
    String? translationText,
    ReflectionTier? tier,
    String? promptText,
    String? responseText,
    DateTime? completedAt,
    String? hijriDate,
    int? streakDay,
    bool? isPinned,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      verseKey: verseKey ?? this.verseKey,
      arabicText: arabicText ?? this.arabicText,
      translationText: translationText ?? this.translationText,
      tier: tier ?? this.tier,
      promptText: promptText ?? this.promptText,
      responseText: responseText ?? this.responseText,
      completedAt: completedAt ?? this.completedAt,
      hijriDate: hijriDate ?? this.hijriDate,
      streakDay: streakDay ?? this.streakDay,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  String toString() {
    return 'JournalEntry(id: $id, verseKey: $verseKey, tier: ${tier.name}, '
        'completedAt: $completedAt, streakDay: $streakDay, '
        'isPinned: $isPinned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEntry &&
        other.id == id &&
        other.verseKey == verseKey &&
        other.arabicText == arabicText &&
        other.translationText == translationText &&
        other.tier == tier &&
        other.promptText == promptText &&
        other.responseText == responseText &&
        other.completedAt == completedAt &&
        other.hijriDate == hijriDate &&
        other.streakDay == streakDay &&
        other.isPinned == isPinned;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      verseKey,
      arabicText,
      translationText,
      tier,
      promptText,
      responseText,
      completedAt,
      hijriDate,
      streakDay,
      isPinned,
    );
  }
}
