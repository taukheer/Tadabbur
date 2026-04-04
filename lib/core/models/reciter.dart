class Reciter {
  final int id;
  final String name;
  final String? arabicName;
  final String? relativePath;
  final String? style;

  const Reciter({
    required this.id,
    required this.name,
    this.arabicName,
    this.relativePath,
    this.style,
  });

  factory Reciter.fromJson(Map<String, dynamic> json) {
    return Reciter(
      id: json['id'] as int,
      name: json['reciter_name'] as String? ?? json['name'] as String,
      arabicName: json['arabic_name'] as String?,
      relativePath: json['relative_path'] as String?,
      style: (json['style'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (arabicName != null) 'arabic_name': arabicName,
      if (relativePath != null) 'relative_path': relativePath,
      if (style != null) 'style': style,
    };
  }

  Reciter copyWith({
    int? id,
    String? name,
    String? arabicName,
    String? relativePath,
    String? style,
  }) {
    return Reciter(
      id: id ?? this.id,
      name: name ?? this.name,
      arabicName: arabicName ?? this.arabicName,
      relativePath: relativePath ?? this.relativePath,
      style: style ?? this.style,
    );
  }

  @override
  String toString() {
    return 'Reciter(id: $id, name: $name, style: $style)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reciter &&
        other.id == id &&
        other.name == name &&
        other.arabicName == arabicName &&
        other.relativePath == relativePath &&
        other.style == style;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, arabicName, relativePath, style);
  }
}
