import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArabicFonts {
  static const options = [
    ArabicFontOption(
      id: 'AmiriQuran',
      name: 'Amiri Quran',
      descriptionKey: 'font_desc_amiri_quran',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
    ArabicFontOption(
      id: 'Amiri',
      name: 'Amiri',
      descriptionKey: 'font_desc_amiri',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
    ArabicFontOption(
      id: 'ScheherazadeNew',
      name: 'Scheherazade',
      descriptionKey: 'font_desc_scheherazade',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
    ArabicFontOption(
      id: 'NotoNaskhArabic',
      name: 'Noto Naskh',
      descriptionKey: 'font_desc_noto_naskh',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
    ArabicFontOption(
      id: 'Lateef',
      name: 'Lateef',
      descriptionKey: 'font_desc_lateef',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
  ];

  /// Get the TextStyle for the given font ID and size.
  static TextStyle getStyle(String fontId, {double fontSize = 36}) {
    switch (fontId) {
      case 'AmiriQuran':
        return TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: fontSize,
          height: 2.2,
        );
      case 'Amiri':
        return GoogleFonts.amiri(
          fontSize: fontSize,
          height: 2.2,
        );
      case 'ScheherazadeNew':
        return GoogleFonts.scheherazadeNew(
          fontSize: fontSize,
          height: 2.2,
        );
      case 'NotoNaskhArabic':
        return GoogleFonts.notoNaskhArabic(
          fontSize: fontSize,
          height: 2.0,
        );
      case 'Lateef':
        return GoogleFonts.lateef(
          fontSize: fontSize,
          height: 2.2,
        );
      default:
        return TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: fontSize,
          height: 2.2,
        );
    }
  }
}

class ArabicFontOption {
  final String id;
  final String name;
  /// Translation key for the font's one-line genre description
  /// (e.g. "Classic, elegant Naskh"). Resolved at render time so the
  /// description localizes alongside the rest of the UI.
  final String descriptionKey;
  final String preview;

  const ArabicFontOption({
    required this.id,
    required this.name,
    required this.descriptionKey,
    required this.preview,
  });
}
