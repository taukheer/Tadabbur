/// One entry in the curated tafsir catalogue. Each represents a
/// distinct scholarly voice. Users pick their preferred scholar once
/// in Settings; the daily ayah sheet just reads that preference and
/// loads the single corresponding tafsir — no per-ayah decision tax.
class TafsirOption {
  /// Backend slug used with /tafsirs/{slug}/by_ayah/{verseKey}.
  final String slug;

  /// Short display name for menu rows (e.g. "Ibn Kathir").
  final String shortName;

  /// Full title shown in the sheet header (e.g. "Tafsir Ibn Kathir (Abridged)").
  final String fullName;

  /// Mufassir attribution shown as small italic.
  final String mufassir;

  /// Two-letter language code the tafsir is written in.
  final String lang;

  const TafsirOption({
    required this.slug,
    required this.shortName,
    required this.fullName,
    required this.mufassir,
    required this.lang,
  });
}

/// Curated tafsir catalogue. Deliberately small so the Settings
/// dropdown stays legible and each source is a meaningful choice.
///
/// English: a classical (Ibn Kathir, hadith-focused), a South Asian
/// Hanafi (Ma'arif al-Qur'an, legal and spiritual), and a modern
/// accessible voice (Tazkirul Quran).
///
/// Arabic: the three most-cited mufassirin in the tradition.
const List<TafsirOption> kTafsirOptions = [
  TafsirOption(
    slug: 'en-tafisr-ibn-kathir',
    shortName: 'Ibn Kathir',
    fullName: 'Tafsir Ibn Kathir (Abridged)',
    mufassir: 'Hafiz Ibn Kathir',
    lang: 'en',
  ),
  TafsirOption(
    slug: 'en-tafsir-maarif-ul-quran',
    shortName: "Ma'arif",
    fullName: "Ma'arif al-Qur'an",
    mufassir: 'Mufti Muhammad Shafi',
    lang: 'en',
  ),
  TafsirOption(
    slug: 'tazkirul-quran-en',
    shortName: 'Tazkirul',
    fullName: 'Tazkirul Quran',
    mufassir: 'Maulana Wahiduddin Khan',
    lang: 'en',
  ),
  TafsirOption(
    slug: 'ar-tafsir-muyassar',
    shortName: 'الميسر',
    fullName: 'التفسير الميسر',
    mufassir: 'مجمع الملك فهد',
    lang: 'ar',
  ),
  TafsirOption(
    slug: 'ar-tafsir-ibn-kathir',
    shortName: 'ابن كثير',
    fullName: 'تفسير ابن كثير',
    mufassir: 'ابن كثير',
    lang: 'ar',
  ),
  TafsirOption(
    slug: 'ar-tafsir-al-tabari',
    shortName: 'الطبري',
    fullName: 'تفسير الطبري',
    mufassir: 'الطبري',
    lang: 'ar',
  ),
];

/// Returns all options matching [lang]. Falls back to all options
/// (typically the English set) if no options exist for the language.
List<TafsirOption> tafsirOptionsFor(String lang) {
  final filtered =
      kTafsirOptions.where((o) => o.lang == lang).toList(growable: false);
  if (filtered.isNotEmpty) return filtered;
  return kTafsirOptions.where((o) => o.lang == 'en').toList(growable: false);
}

/// Resolves the active tafsir for [lang] given a stored [preferredSlug]
/// (or null). Returns the first option for the language if the stored
/// slug isn't in the catalogue (e.g. user switched languages, or the
/// stored preference was for a slug that's since been retired).
TafsirOption resolveTafsirFor(String lang, String? preferredSlug) {
  final options = tafsirOptionsFor(lang);
  if (preferredSlug != null) {
    for (final o in options) {
      if (o.slug == preferredSlug) return o;
    }
  }
  return options.first;
}
