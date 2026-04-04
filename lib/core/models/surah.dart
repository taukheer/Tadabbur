class Surah {
  final int id;
  final String nameArabic;
  final String nameSimple;
  final String nameComplex;
  final String? translatedName;
  final String revelationType;
  final int versesCount;
  final List<int>? pages;

  const Surah({
    required this.id,
    required this.nameArabic,
    required this.nameSimple,
    required this.nameComplex,
    this.translatedName,
    required this.revelationType,
    required this.versesCount,
    this.pages,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'] as int,
      nameArabic: json['name_arabic'] as String,
      nameSimple: json['name_simple'] as String,
      nameComplex: json['name_complex'] as String,
      translatedName: json['translated_name'] as String?,
      revelationType: json['revelation_type'] as String,
      versesCount: json['verses_count'] as int,
      pages: (json['pages'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_arabic': nameArabic,
      'name_simple': nameSimple,
      'name_complex': nameComplex,
      if (translatedName != null) 'translated_name': translatedName,
      'revelation_type': revelationType,
      'verses_count': versesCount,
      if (pages != null) 'pages': pages,
    };
  }

  Surah copyWith({
    int? id,
    String? nameArabic,
    String? nameSimple,
    String? nameComplex,
    String? translatedName,
    String? revelationType,
    int? versesCount,
    List<int>? pages,
  }) {
    return Surah(
      id: id ?? this.id,
      nameArabic: nameArabic ?? this.nameArabic,
      nameSimple: nameSimple ?? this.nameSimple,
      nameComplex: nameComplex ?? this.nameComplex,
      translatedName: translatedName ?? this.translatedName,
      revelationType: revelationType ?? this.revelationType,
      versesCount: versesCount ?? this.versesCount,
      pages: pages ?? this.pages,
    );
  }

  @override
  String toString() {
    return 'Surah(id: $id, nameSimple: $nameSimple, nameArabic: $nameArabic, '
        'revelationType: $revelationType, versesCount: $versesCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Surah) return false;
    if (other.id != id ||
        other.nameArabic != nameArabic ||
        other.nameSimple != nameSimple ||
        other.nameComplex != nameComplex ||
        other.translatedName != translatedName ||
        other.revelationType != revelationType ||
        other.versesCount != versesCount) {
      return false;
    }
    if (other.pages == null && pages == null) return true;
    if (other.pages == null || pages == null) return false;
    if (other.pages!.length != pages!.length) return false;
    for (int i = 0; i < pages!.length; i++) {
      if (other.pages![i] != pages![i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      nameArabic,
      nameSimple,
      nameComplex,
      translatedName,
      revelationType,
      versesCount,
      pages != null ? Object.hashAll(pages!) : null,
    );
  }
}
