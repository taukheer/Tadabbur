import '../models/ayah.dart';

/// How much of the Quran forms one day's reading.
///
/// Tadabbur shipped as strictly one ayah a day, and that remains the
/// default — the whole reflective model (sit with it, "I felt this",
/// one journal entry) is built around a single verse. But readers who
/// already have a mushaf habit think in *pages*, and asking them to
/// abandon that to use the app is a bad trade. These modes let the
/// daily unit follow the mushaf without changing what a "day" means:
/// one portion, one completion, one streak tick, whatever its size.
enum DailyPortion {
  /// A single verse. The original, and still the default.
  ayah('ayah', 'portion_ayah'),

  /// Half of a mushaf page — the first or second half of the page's
  /// verses, whichever contains the reader's current position.
  halfPage('half_page', 'portion_half_page'),

  /// A full mushaf page (Madani mushaf, 604 pages).
  page('page', 'portion_page');

  const DailyPortion(this.id, this.labelKey);

  /// Stable identifier persisted in preferences and synced state.
  final String id;

  /// Translation key for the human-facing label.
  final String labelKey;

  static DailyPortion fromId(String? id) => switch (id) {
        'half_page' => DailyPortion.halfPage,
        'page' => DailyPortion.page,
        _ => DailyPortion.ayah,
      };

  /// True when a day's reading is more than one verse, and the Today
  /// screen should render a passage rather than a single ayah.
  bool get isPassage => this != DailyPortion.ayah;
}

/// One day's reading: a contiguous run of verses in mushaf order.
class Portion {
  /// The verses to read today, in order. Never empty.
  final List<Ayah> verses;

  /// The mushaf page these verses sit on, when known. Null in ayah
  /// mode, where the page is incidental rather than the unit.
  final int? pageNumber;

  /// Which mode produced this portion.
  final DailyPortion mode;

  const Portion({
    required this.verses,
    required this.mode,
    this.pageNumber,
  });

  Ayah get first => verses.first;
  Ayah get last => verses.last;
  int get length => verses.length;
  bool get isPassage => verses.length > 1;

  List<String> get verseKeys => [for (final v in verses) v.verseKey];

  /// Compact human reference for the range — "36:1–10" within one
  /// surah, "36:80–37:5" when the portion crosses into the next.
  /// Surah names are left to the caller, which has the lookup table
  /// and the user's language.
  String get rangeLabel {
    if (verses.length == 1) return first.verseKey;
    return first.surahNumber == last.surahNumber
        ? '${first.verseKey}–${last.ayahNumber}'
        : '${first.verseKey}–${last.verseKey}';
  }

  /// Splits a page's verses into the half containing [anchorVerseKey].
  ///
  /// Pages are wildly uneven — 5 verses early in the mushaf, 30 in the
  /// short surahs — so halves are taken by verse count rather than by
  /// any notion of physical height, which the API doesn't expose. The
  /// first half takes the extra verse on an odd count, so a reader
  /// always front-loads rather than trailing.
  static List<Ayah> halfOfPage(List<Ayah> pageVerses, String anchorVerseKey) {
    if (pageVerses.length < 2) return pageVerses;
    final split = (pageVerses.length + 1) ~/ 2;
    final anchorIndex =
        pageVerses.indexWhere((v) => v.verseKey == anchorVerseKey);
    // An anchor that isn't on this page means the caller resolved the
    // page from something other than the anchor; default to the front.
    if (anchorIndex < 0 || anchorIndex < split) {
      return pageVerses.sublist(0, split);
    }
    return pageVerses.sublist(split);
  }
}
