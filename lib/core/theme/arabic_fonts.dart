import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArabicFonts {
  static const options = [
    ArabicFontOption(
      id: 'AmiriQuran',
      name: 'Amiri Quran',
      description: 'Classic, elegant Naskh',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
    ArabicFontOption(
      id: 'Amiri',
      name: 'Amiri',
      description: 'Traditional book style',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
    ArabicFontOption(
      id: 'ScheherazadeNew',
      name: 'Scheherazade',
      description: 'Beautiful Naskh script',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
    ArabicFontOption(
      id: 'NotoNaskhArabic',
      name: 'Noto Naskh',
      description: 'Clean, modern Naskh',
      preview: 'بِسْمِ ٱللَّهِ',
    ),
    ArabicFontOption(
      id: 'Lateef',
      name: 'Lateef',
      description: 'Nastaliq-inspired style',
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
  final String description;
  final String preview;

  const ArabicFontOption({
    required this.id,
    required this.name,
    required this.description,
    required this.preview,
  });
}
