class Ayah {
  final int id;
  final String verseKey;
  final int surahNumber;
  final int ayahNumber;
  final String textUthmani;
  final String? textSimple;
  final String? translationText;
  final String? translationAuthor;
  final int? juzNumber;
  final int? hizbNumber;
  final int? rukuNumber;
  final int? pageNumber;

  const Ayah({
    required this.id,
    required this.verseKey,
    required this.surahNumber,
    required this.ayahNumber,
    required this.textUthmani,
    this.textSimple,
    this.translationText,
    this.translationAuthor,
    this.juzNumber,
    this.hizbNumber,
    this.rukuNumber,
    this.pageNumber,
  });

  factory Ayah.fromJson(Map<String, dynamic> json) {
    return Ayah(
      id: json['id'] as int,
      verseKey: json['verse_key'] as String,
      surahNumber: json['surah_number'] as int,
      ayahNumber: json['ayah_number'] as int,
      textUthmani: json['text_uthmani'] as String,
      textSimple: json['text_simple'] as String?,
      translationText: json['translation_text'] as String?,
      translationAuthor: json['translation_author'] as String?,
      juzNumber: json['juz_number'] as int?,
      hizbNumber: json['hizb_number'] as int?,
      rukuNumber: json['ruku_number'] as int?,
      pageNumber: json['page_number'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verse_key': verseKey,
      'surah_number': surahNumber,
      'ayah_number': ayahNumber,
      'text_uthmani': textUthmani,
      if (textSimple != null) 'text_simple': textSimple,
      if (translationText != null) 'translation_text': translationText,
      if (translationAuthor != null) 'translation_author': translationAuthor,
      if (juzNumber != null) 'juz_number': juzNumber,
      if (hizbNumber != null) 'hizb_number': hizbNumber,
      if (rukuNumber != null) 'ruku_number': rukuNumber,
      if (pageNumber != null) 'page_number': pageNumber,
    };
  }

  Ayah copyWith({
    int? id,
    String? verseKey,
    int? surahNumber,
    int? ayahNumber,
    String? textUthmani,
    String? textSimple,
    String? translationText,
    String? translationAuthor,
    int? juzNumber,
    int? hizbNumber,
    int? rukuNumber,
    int? pageNumber,
  }) {
    return Ayah(
      id: id ?? this.id,
      verseKey: verseKey ?? this.verseKey,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      textUthmani: textUthmani ?? this.textUthmani,
      textSimple: textSimple ?? this.textSimple,
      translationText: translationText ?? this.translationText,
      translationAuthor: translationAuthor ?? this.translationAuthor,
      juzNumber: juzNumber ?? this.juzNumber,
      hizbNumber: hizbNumber ?? this.hizbNumber,
      rukuNumber: rukuNumber ?? this.rukuNumber,
      pageNumber: pageNumber ?? this.pageNumber,
    );
  }

  @override
  String toString() {
    return 'Ayah(id: $id, verseKey: $verseKey, surahNumber: $surahNumber, '
        'ayahNumber: $ayahNumber, textUthmani: $textUthmani)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ayah &&
        other.id == id &&
        other.verseKey == verseKey &&
        other.surahNumber == surahNumber &&
        other.ayahNumber == ayahNumber &&
        other.textUthmani == textUthmani &&
        other.textSimple == textSimple &&
        other.translationText == translationText &&
        other.translationAuthor == translationAuthor &&
        other.juzNumber == juzNumber &&
        other.hizbNumber == hizbNumber &&
        other.rukuNumber == rukuNumber &&
        other.pageNumber == pageNumber;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      verseKey,
      surahNumber,
      ayahNumber,
      textUthmani,
      textSimple,
      translationText,
      translationAuthor,
      juzNumber,
      hizbNumber,
      rukuNumber,
      pageNumber,
    );
  }
}
