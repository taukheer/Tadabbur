class Bookmark {
  final String verseKey;
  final String arabicText;
  final String translationText;
  final DateTime bookmarkedAt;
  final int? qfBookmarkId;

  const Bookmark({
    required this.verseKey,
    required this.arabicText,
    required this.translationText,
    required this.bookmarkedAt,
    this.qfBookmarkId,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      verseKey: json['verse_key'] as String,
      arabicText: json['arabic_text'] as String,
      translationText: json['translation_text'] as String,
      bookmarkedAt: DateTime.parse(json['bookmarked_at'] as String),
      qfBookmarkId: json['qf_bookmark_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verse_key': verseKey,
      'arabic_text': arabicText,
      'translation_text': translationText,
      'bookmarked_at': bookmarkedAt.toIso8601String(),
      if (qfBookmarkId != null) 'qf_bookmark_id': qfBookmarkId,
    };
  }

  Bookmark copyWith({int? qfBookmarkId}) {
    return Bookmark(
      verseKey: verseKey,
      arabicText: arabicText,
      translationText: translationText,
      bookmarkedAt: bookmarkedAt,
      qfBookmarkId: qfBookmarkId ?? this.qfBookmarkId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bookmark && other.verseKey == verseKey;
  }

  @override
  int get hashCode => verseKey.hashCode;

  @override
  String toString() => 'Bookmark(verseKey: $verseKey, bookmarkedAt: $bookmarkedAt)';
}
