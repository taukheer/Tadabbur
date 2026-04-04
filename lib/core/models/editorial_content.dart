class EditorialContent {
  final String verseKey;
  final String historicalContext;
  final String scholarReflection;
  final String scholarName;
  final String tier2Prompt;
  final String tier3Question;
  final String? surahIntroduction;

  const EditorialContent({
    required this.verseKey,
    required this.historicalContext,
    required this.scholarReflection,
    required this.scholarName,
    required this.tier2Prompt,
    required this.tier3Question,
    this.surahIntroduction,
  });

  factory EditorialContent.fromJson(Map<String, dynamic> json) {
    return EditorialContent(
      verseKey: json['verse_key'] as String,
      historicalContext: json['historical_context'] as String,
      scholarReflection: json['scholar_reflection'] as String,
      scholarName: json['scholar_name'] as String,
      tier2Prompt: json['tier2_prompt'] as String,
      tier3Question: json['tier3_question'] as String,
      surahIntroduction: json['surah_introduction'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verse_key': verseKey,
      'historical_context': historicalContext,
      'scholar_reflection': scholarReflection,
      'scholar_name': scholarName,
      'tier2_prompt': tier2Prompt,
      'tier3_question': tier3Question,
      if (surahIntroduction != null) 'surah_introduction': surahIntroduction,
    };
  }

  EditorialContent copyWith({
    String? verseKey,
    String? historicalContext,
    String? scholarReflection,
    String? scholarName,
    String? tier2Prompt,
    String? tier3Question,
    String? surahIntroduction,
  }) {
    return EditorialContent(
      verseKey: verseKey ?? this.verseKey,
      historicalContext: historicalContext ?? this.historicalContext,
      scholarReflection: scholarReflection ?? this.scholarReflection,
      scholarName: scholarName ?? this.scholarName,
      tier2Prompt: tier2Prompt ?? this.tier2Prompt,
      tier3Question: tier3Question ?? this.tier3Question,
      surahIntroduction: surahIntroduction ?? this.surahIntroduction,
    );
  }

  @override
  String toString() {
    return 'EditorialContent(verseKey: $verseKey, scholarName: $scholarName, '
        'tier2Prompt: $tier2Prompt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EditorialContent &&
        other.verseKey == verseKey &&
        other.historicalContext == historicalContext &&
        other.scholarReflection == scholarReflection &&
        other.scholarName == scholarName &&
        other.tier2Prompt == tier2Prompt &&
        other.tier3Question == tier3Question &&
        other.surahIntroduction == surahIntroduction;
  }

  @override
  int get hashCode {
    return Object.hash(
      verseKey,
      historicalContext,
      scholarReflection,
      scholarName,
      tier2Prompt,
      tier3Question,
      surahIntroduction,
    );
  }
}
