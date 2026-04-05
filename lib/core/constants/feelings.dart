/// Feeling-to-Ayah mapping for the "Explore by feeling" feature.
/// Each feeling maps to a carefully selected ayah that speaks to that emotion.
class FeelingAyah {
  final String id;
  final String emoji;
  final String labelKey; // translation key
  final String verseKey;

  const FeelingAyah({
    required this.id,
    required this.emoji,
    required this.labelKey,
    required this.verseKey,
  });
}

class Feelings {
  static const all = [
    FeelingAyah(
      id: 'low',
      emoji: '😔',
      labelKey: 'feeling_low',
      verseKey: '93:3', // "Your Lord has not abandoned you, nor has He become hateful"
    ),
    FeelingAyah(
      id: 'anxious',
      emoji: '😰',
      labelKey: 'feeling_anxious',
      verseKey: '13:28', // "Verily, in the remembrance of Allah do hearts find rest"
    ),
    FeelingAyah(
      id: 'angry',
      emoji: '😤',
      labelKey: 'feeling_angry',
      verseKey: '3:134', // "Who restrain anger and pardon people"
    ),
    FeelingAyah(
      id: 'grateful',
      emoji: '🤲',
      labelKey: 'feeling_grateful',
      verseKey: '14:7', // "If you are grateful, I will surely increase you"
    ),
    FeelingAyah(
      id: 'confused',
      emoji: '🤔',
      labelKey: 'feeling_confused',
      verseKey: '2:286', // "Allah does not burden a soul beyond that it can bear"
    ),
    FeelingAyah(
      id: 'lonely',
      emoji: '💔',
      labelKey: 'feeling_lonely',
      verseKey: '2:186', // "I am near. I respond to the call of the caller when he calls"
    ),
    FeelingAyah(
      id: 'hopeful',
      emoji: '🌅',
      labelKey: 'feeling_hopeful',
      verseKey: '94:6', // "Indeed, with hardship comes ease"
    ),
    FeelingAyah(
      id: 'lost',
      emoji: '🧭',
      labelKey: 'feeling_lost',
      verseKey: '1:6', // "Guide us to the straight path"
    ),
  ];
}
