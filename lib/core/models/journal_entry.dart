enum ReflectionTier { acknowledge, respond, reflect }

/// One verse as stored inside a journal entry.
///
/// The journal has to render what the reader actually read, offline,
/// years later — re-fetching a page from the network to show a diary
/// entry would make the journal useless on a plane. So the text is
/// copied in at write time.
///
/// JSON keys are single letters on purpose. The whole journal is
/// persisted as one string in SharedPreferences and re-serialised on
/// every write, so per-verse overhead is multiplied by every verse of
/// every passage day; `{"k":..,"a":..,"t":..}` saves roughly a third
/// against spelled-out keys.
class JournalVerse {
  final String verseKey;
  final String arabicText;
  final String translationText;

  const JournalVerse({
    required this.verseKey,
    required this.arabicText,
    this.translationText = '',
  });

  factory JournalVerse.fromJson(Map<String, dynamic> json) => JournalVerse(
        verseKey: json['k'] as String? ?? '',
        arabicText: json['a'] as String? ?? '',
        translationText: json['t'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'k': verseKey,
        'a': arabicText,
        if (translationText.isNotEmpty) 't': translationText,
      };

  int get ayahNumber =>
      int.tryParse(verseKey.split(':').last) ?? 0;
}

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

  /// Language code (e.g. `'en'`, `'ta'`, `'ar'`) the user was viewing
  /// when this entry was written — i.e. the language [translationText]
  /// is in. Lets the journal hide a stale translation when the user
  /// later switches their app language: an Arabic-mode user shouldn't
  /// see Tamil text on entries they wrote while in Tamil mode.
  /// Null on legacy entries written before this field existed; the
  /// render layer treats null as "language unknown" and hides the
  /// translation defensively.
  final String? translationLang;

  /// Last verse of the day's reading, when it spanned more than one —
  /// half-page and page modes. Null on single-ayah entries, which is
  /// every entry written before those modes existed, so old data
  /// deserializes unchanged and simply reads as a range of one.
  final String? verseKeyEnd;

  /// How many verses the day covered. Defaults to 1 for the same
  /// backwards-compatibility reason.
  final int verseCount;

  /// Which reading mode produced this entry — a [DailyPortion] id.
  /// Null on entries written before the modes existed, which are
  /// single ayat by definition.
  ///
  /// Recorded separately from [verseCount] because the two answer
  /// different questions: the count says how much was read, this says
  /// what the reader had set out to do. A half-page that happened to
  /// hold ten verses and a full page that held ten are the same size
  /// but not the same intention.
  final String? portionId;

  /// Every verse the day covered, with its text — the actual reading,
  /// not just its first line.
  ///
  /// Empty for single-ayah entries, where [arabicText] already is the
  /// whole day and duplicating it would double the journal's size for
  /// the default mode. Use [allVerses] to read either shape uniformly.
  final List<JournalVerse> verses;

  /// The day's verses, whichever mode wrote the entry.
  List<JournalVerse> get allVerses => verses.isNotEmpty
      ? verses
      : [
          JournalVerse(
            verseKey: verseKey,
            arabicText: arabicText,
            translationText: translationText,
          ),
        ];

  /// True when this entry records a passage rather than a single ayah.
  bool get isPassage => verseCount > 1;

  /// "36:1–10" for a passage, "36:1" for a single verse. The surah
  /// name is left to the render layer, which has the user's language.
  String get rangeLabel {
    final end = verseKeyEnd;
    if (!isPassage || end == null) return verseKey;
    final startSurah = verseKey.split(':').first;
    final endParts = end.split(':');
    return startSurah == endParts.first
        ? '$verseKey–${endParts.last}'
        : '$verseKey–$end';
  }

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
    this.translationLang,
    this.verseKeyEnd,
    this.verseCount = 1,
    this.portionId,
    this.verses = const [],
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      verseKey: json['verse_key'] as String,
      verseKeyEnd: json['verse_key_end'] as String?,
      verseCount: json['verse_count'] as int? ?? 1,
      portionId: json['portion_id'] as String?,
      verses: (json['verses'] as List?)
              ?.map((v) => JournalVerse.fromJson(v as Map<String, dynamic>))
              .toList() ??
          const [],
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
      translationLang: json['translation_lang'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verse_key': verseKey,
      if (verseKeyEnd != null) 'verse_key_end': verseKeyEnd,
      if (verseCount > 1) 'verse_count': verseCount,
      if (portionId != null) 'portion_id': portionId,
      if (verses.isNotEmpty)
        'verses': [for (final v in verses) v.toJson()],
      'arabic_text': arabicText,
      'translation_text': translationText,
      'tier': tier.name,
      if (promptText != null) 'prompt_text': promptText,
      if (responseText != null) 'response_text': responseText,
      'completed_at': completedAt.toIso8601String(),
      if (hijriDate != null) 'hijri_date': hijriDate,
      'streak_day': streakDay,
      if (isPinned) 'is_pinned': true,
      if (translationLang != null) 'translation_lang': translationLang,
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
    String? translationLang,
    String? verseKeyEnd,
    int? verseCount,
    String? portionId,
    List<JournalVerse>? verses,
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
      translationLang: translationLang ?? this.translationLang,
      verseKeyEnd: verseKeyEnd ?? this.verseKeyEnd,
      verseCount: verseCount ?? this.verseCount,
      portionId: portionId ?? this.portionId,
      verses: verses ?? this.verses,
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
        other.isPinned == isPinned &&
        other.translationLang == translationLang;
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
      translationLang,
    );
  }
}
