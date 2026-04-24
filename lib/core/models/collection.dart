/// A thematic grouping of verses stored on quran.com via QF's
/// Collections API.
///
/// Users assemble collections for themes that span their reading —
/// "Ayahs on patience", "Verses I recited at Fajr", "Ramadan 1447".
/// The underlying QF entity is shared across any Connected App, so a
/// collection created in Tadabbur shows up on quran.com too (and vice
/// versa). That cross-app continuity is what makes Collections a
/// Connected Apps signal rather than an isolated feature.
class QfCollection {
  final String id;
  final String name;
  final int? itemCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QfCollection({
    required this.id,
    required this.name,
    this.itemCount,
    this.createdAt,
    this.updatedAt,
  });

  factory QfCollection.fromJson(Map<String, dynamic> raw) {
    String str(List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = raw[k];
        if (v is String && v.isNotEmpty) return v;
        if (v is num) return v.toString();
      }
      return fallback;
    }

    int? intOrNull(List<String> keys) {
      for (final k in keys) {
        final v = raw[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    DateTime? dateOrNull(List<String> keys) {
      for (final k in keys) {
        final v = raw[k];
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return QfCollection(
      id: str(['id', 'collection_id', 'collectionId']),
      name: str(['name', 'title', 'label'], fallback: 'Untitled'),
      itemCount: intOrNull(['item_count', 'itemCount', 'count', 'size']),
      createdAt: dateOrNull(['created_at', 'createdAt']),
      updatedAt: dateOrNull(['updated_at', 'updatedAt']),
    );
  }
}

/// A single verse reference inside a collection. QF's collection-item
/// payloads vary in shape across deploys, so the parser probes a few
/// common field names and falls back to null when it can't recover
/// a valid verseKey — the UI skips unparseable items silently rather
/// than rendering broken rows.
class QfCollectionItem {
  final String? id;
  final String verseKey;
  final DateTime? addedAt;

  const QfCollectionItem({
    this.id,
    required this.verseKey,
    this.addedAt,
  });

  static QfCollectionItem? tryFromJson(Map<String, dynamic> raw) {
    // Direct verseKey string
    final direct = raw['verseKey'] ?? raw['verse_key'];
    if (direct is String && direct.contains(':')) {
      return QfCollectionItem(
        id: raw['id']?.toString(),
        verseKey: direct,
        addedAt: _date(raw),
      );
    }
    // Composed from {key, verseNumber} (same shape as bookmarks POST)
    final key = raw['key'] ?? raw['surah'] ?? raw['chapter_id'];
    final ayah = raw['verseNumber'] ?? raw['verse_number'] ?? raw['ayah'];
    if (key != null && ayah != null) {
      return QfCollectionItem(
        id: raw['id']?.toString(),
        verseKey: '$key:$ayah',
        addedAt: _date(raw),
      );
    }
    return null;
  }

  static DateTime? _date(Map<String, dynamic> raw) {
    final s = raw['created_at'] ?? raw['createdAt'] ?? raw['added_at'];
    if (s is String) return DateTime.tryParse(s);
    return null;
  }
}
