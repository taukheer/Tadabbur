/// Canonical list of surah transliterations used across the app.
///
/// Index 0 is an empty placeholder so callers can use the natural 1-114
/// surah numbering without `-1` offsets. Use [surahNameFromKey] to
/// resolve a name from a `"surah:ayah"` verse key; it falls back to
/// "Surah N" when the number is out of range, so call sites don't need
/// their own bounds checks.
///
/// Previously duplicated in `share_card.dart` and `home_widget_service.dart`;
/// keeping a single source of truth prevents a fix to one transliteration
/// (e.g. "An-Nisa" → "An-Nisāʾ") from silently diverging between the
/// share card and the home-screen widget.
library;

const List<String> kSurahNames = [
  '',
  'Al-Fatiha', 'Al-Baqarah', 'Ali Imran', 'An-Nisa', 'Al-Maidah',
  "Al-An'am", "Al-A'raf", 'Al-Anfal', 'At-Tawbah', 'Yunus',
  'Hud', 'Yusuf', "Ar-Ra'd", 'Ibrahim', 'Al-Hijr',
  'An-Nahl', 'Al-Isra', 'Al-Kahf', 'Maryam', 'Ta-Ha',
  'Al-Anbiya', 'Al-Hajj', "Al-Mu'minun", 'An-Nur', 'Al-Furqan',
  "Ash-Shu'ara", 'An-Naml', 'Al-Qasas', 'Al-Ankabut', 'Ar-Rum',
  'Luqman', 'As-Sajdah', 'Al-Ahzab', 'Saba', 'Fatir',
  'Ya-Sin', 'As-Saffat', 'Sad', 'Az-Zumar', 'Ghafir',
  'Fussilat', 'Ash-Shura', 'Az-Zukhruf', 'Ad-Dukhan', 'Al-Jathiyah',
  'Al-Ahqaf', 'Muhammad', 'Al-Fath', 'Al-Hujurat', 'Qaf',
  'Adh-Dhariyat', 'At-Tur', 'An-Najm', 'Al-Qamar', 'Ar-Rahman',
  "Al-Waqi'ah", 'Al-Hadid', 'Al-Mujadilah', 'Al-Hashr', 'Al-Mumtahanah',
  'As-Saff', "Al-Jumu'ah", 'Al-Munafiqun', 'At-Taghabun', 'At-Talaq',
  'At-Tahrim', 'Al-Mulk', 'Al-Qalam', 'Al-Haqqah', "Al-Ma'arij",
  'Nuh', 'Al-Jinn', 'Al-Muzzammil', 'Al-Muddaththir', 'Al-Qiyamah',
  'Al-Insan', 'Al-Mursalat', "An-Naba'", "An-Nazi'at", 'Abasa',
  'At-Takwir', 'Al-Infitar', 'Al-Mutaffifin', 'Al-Inshiqaq', 'Al-Buruj',
  'At-Tariq', "Al-A'la", 'Al-Ghashiyah', 'Al-Fajr', 'Al-Balad',
  'Ash-Shams', 'Al-Layl', 'Ad-Duha', 'Ash-Sharh', 'At-Tin',
  'Al-Alaq', 'Al-Qadr', 'Al-Bayyinah', 'Az-Zalzalah', 'Al-Adiyat',
  "Al-Qari'ah", 'At-Takathur', 'Al-Asr', 'Al-Humazah', 'Al-Fil',
  'Quraysh', "Al-Ma'un", 'Al-Kawthar', 'Al-Kafirun', 'An-Nasr',
  'Al-Masad', 'Al-Ikhlas', 'Al-Falaq', 'An-Nas',
];

/// Returns the transliterated surah name for a verse key like `"2:255"`.
/// Falls back to `"Surah N"` when the surah number is out of range or
/// the key is malformed.
String surahNameFromKey(String verseKey) {
  final surah = int.tryParse(verseKey.split(':').first) ?? 0;
  if (surah < 1 || surah > 114) return 'Surah $surah';
  return kSurahNames[surah];
}

/// Number of ayat in each surah. Index 0 is an unused placeholder so
/// callers can index by surah number directly.
///
/// Used for verse-position math (absolute ayah number across the
/// Quran) and the "journey through the Qur'an" progress band. These
/// counts are canonical and don't change, so hard-coding them here is
/// correct — no API dependency for a render-time calculation.
const List<int> kSurahVerseCounts = [
  0, // index 0 unused
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109,     // 1-10
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135,      // 11-20
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60,         // 21-30
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85,           // 31-40
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45,            // 41-50
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13,            // 51-60
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44,            // 61-70
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42,            // 71-80
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20,            // 81-90
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11,                 // 91-100
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3,                     // 101-110
  5, 4, 5, 6,                                        // 111-114
];

/// Total ayat in the Quran (sum of kSurahVerseCounts).
const int kTotalAyat = 6236;

/// Returns the 1-indexed absolute ayah number across the whole Quran
/// for a verse key like `"2:255"`. `"1:1"` → 1, `"114:6"` → 6236.
/// Returns 0 if the key is malformed or out of range.
int absoluteAyahNumber(String verseKey) {
  final parts = verseKey.split(':');
  if (parts.length != 2) return 0;
  final surah = int.tryParse(parts[0]) ?? 0;
  final ayah = int.tryParse(parts[1]) ?? 0;
  if (surah < 1 || surah > 114) return 0;
  if (ayah < 1 || ayah > kSurahVerseCounts[surah]) return 0;
  var total = 0;
  for (var i = 1; i < surah; i++) {
    total += kSurahVerseCounts[i];
  }
  return total + ayah;
}
