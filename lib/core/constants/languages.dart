class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final int translationId;
  final String translationAuthor;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.translationId,
    required this.translationAuthor,
  });
}

class AppLanguages {
  static const supported = [
    AppLanguage(
      code: 'en', name: 'English', nativeName: 'English',
      translationId: 20, translationAuthor: 'Saheeh International',
    ),
    AppLanguage(
      code: 'ar', name: 'Arabic', nativeName: 'العربية',
      translationId: 0, translationAuthor: 'Arabic Only',
    ),
    AppLanguage(
      code: 'ur', name: 'Urdu', nativeName: 'اردو',
      translationId: 234, translationAuthor: 'Fatah Muhammad Jalandhari',
    ),
    AppLanguage(
      code: 'fr', name: 'French', nativeName: 'Français',
      translationId: 136, translationAuthor: 'Montada Islamic Foundation',
    ),
    AppLanguage(
      code: 'es', name: 'Spanish', nativeName: 'Español',
      translationId: 83, translationAuthor: 'Sheikh Isa Garcia',
    ),
    AppLanguage(
      code: 'tr', name: 'Turkish', nativeName: 'Türkçe',
      translationId: 77, translationAuthor: 'Diyanet Isleri',
    ),
    AppLanguage(
      code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia',
      translationId: 134, translationAuthor: 'King Fahad Quran Complex',
    ),
    AppLanguage(
      code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu',
      translationId: 39, translationAuthor: 'Abdullah Muhammad Basmeih',
    ),
    AppLanguage(
      code: 'bn', name: 'Bengali', nativeName: 'বাংলা',
      translationId: 161, translationAuthor: 'Tawheed Publication',
    ),
    AppLanguage(
      code: 'hi', name: 'Hindi', nativeName: 'हिन्दी',
      translationId: 122, translationAuthor: 'Maulana Azizul Haque al-Umari',
    ),
    AppLanguage(
      code: 'de', name: 'German', nativeName: 'Deutsch',
      translationId: 27, translationAuthor: 'Frank Bubenheim and Nadeem',
    ),
    AppLanguage(
      code: 'ru', name: 'Russian', nativeName: 'Русский',
      translationId: 78, translationAuthor: 'Ministry of Awqaf, Egypt',
    ),
    AppLanguage(
      code: 'pt', name: 'Portuguese', nativeName: 'Português',
      translationId: 103, translationAuthor: 'Helmi Nasr',
    ),
    AppLanguage(
      code: 'fa', name: 'Persian', nativeName: 'فارسی',
      translationId: 135, translationAuthor: 'IslamHouse.com',
    ),
    AppLanguage(
      code: 'ta', name: 'Tamil', nativeName: 'தமிழ்',
      translationId: 229, translationAuthor: 'Sheikh Omar Sharif',
    ),
    // Malayalam ('ml') and Somali ('so') were dropped from the picker
    // before launch — the UI translations were too thin to ship to
    // Kerala Mappila and East African Sunni-Sufi audiences without a
    // native reviewer. The keys remain in translations.dart as English
    // fallback only; re-introducing the language is a one-line change
    // here once a native translator polishes the strings.
    AppLanguage(
      code: 'sw', name: 'Swahili', nativeName: 'Kiswahili',
      translationId: 231, translationAuthor: 'Dr. Abdullah Muhammad Abu Bakr',
    ),
    AppLanguage(
      code: 'zh', name: 'Chinese', nativeName: '中文',
      translationId: 56, translationAuthor: 'Ma Jian',
    ),
    AppLanguage(
      code: 'ja', name: 'Japanese', nativeName: '日本語',
      translationId: 35, translationAuthor: 'Ryoichi Mita',
    ),
    AppLanguage(
      code: 'ko', name: 'Korean', nativeName: '한국어',
      translationId: 219, translationAuthor: 'Hamed Choi',
    ),
  ];

  static AppLanguage getByCode(String code) {
    return supported.firstWhere(
      (l) => l.code == code,
      orElse: () => supported.first, // English fallback
    );
  }
}
