class Word {
  final int id;
  final int position;
  final String textUthmani;
  final String? transliteration;
  final String? translation;
  final String? charTypeName;

  const Word({
    required this.id,
    required this.position,
    required this.textUthmani,
    this.transliteration,
    this.translation,
    this.charTypeName,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as int,
      position: json['position'] as int,
      textUthmani: json['text_uthmani'] as String,
      transliteration: json['transliteration'] as String?,
      translation: json['translation'] as String?,
      charTypeName: json['char_type_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': position,
      'text_uthmani': textUthmani,
      if (transliteration != null) 'transliteration': transliteration,
      if (translation != null) 'translation': translation,
      if (charTypeName != null) 'char_type_name': charTypeName,
    };
  }

  Word copyWith({
    int? id,
    int? position,
    String? textUthmani,
    String? transliteration,
    String? translation,
    String? charTypeName,
  }) {
    return Word(
      id: id ?? this.id,
      position: position ?? this.position,
      textUthmani: textUthmani ?? this.textUthmani,
      transliteration: transliteration ?? this.transliteration,
      translation: translation ?? this.translation,
      charTypeName: charTypeName ?? this.charTypeName,
    );
  }

  @override
  String toString() {
    return 'Word(id: $id, position: $position, textUthmani: $textUthmani, '
        'charTypeName: $charTypeName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Word &&
        other.id == id &&
        other.position == position &&
        other.textUthmani == textUthmani &&
        other.transliteration == transliteration &&
        other.translation == translation &&
        other.charTypeName == charTypeName;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      position,
      textUthmani,
      transliteration,
      translation,
      charTypeName,
    );
  }
}
