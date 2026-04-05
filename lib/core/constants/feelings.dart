import 'dart:math';

/// Feeling-to-Ayah mapping for the "Explore by feeling" feature.
/// Each feeling has 10 carefully curated ayat. One is shown randomly.
class FeelingAyah {
  final String id;
  final String emoji;
  final String labelKey;
  final String contextKey; // "Why this ayah?" explanation
  final List<String> verseKeys;

  const FeelingAyah({
    required this.id,
    required this.emoji,
    required this.labelKey,
    required this.contextKey,
    required this.verseKeys,
  });

  /// Pick a random ayah from the curated list.
  String get randomVerseKey =>
      verseKeys[Random().nextInt(verseKeys.length)];
}

class Feelings {
  static const all = [
    // === FEELING LOW / SAD ===
    FeelingAyah(
      id: 'low',
      emoji: '😔',
      labelKey: 'feeling_low',
      contextKey: 'context_low',
      verseKeys: [
        '93:3',   // Your Lord has not abandoned you, nor has He become hateful
        '93:4',   // And the Hereafter is better for you than the present
        '94:5',   // Indeed, with hardship comes ease
        '94:6',   // Indeed, with hardship comes ease
        '12:87',  // Do not despair of the mercy of Allah
        '39:53',  // Do not despair of the mercy of Allah — He forgives all sins
        '65:2',   // Whoever fears Allah, He will make a way out for him
        '65:3',   // And will provide for him from where he does not expect
        '2:214',  // Or do you think you will enter Paradise without trial?
        '3:139',  // Do not weaken and do not grieve — you are superior
      ],
    ),

    // === ANXIOUS / WORRIED ===
    FeelingAyah(
      id: 'anxious',
      emoji: '😰',
      labelKey: 'feeling_anxious',
      contextKey: 'context_anxious',
      verseKeys: [
        '13:28',  // In the remembrance of Allah do hearts find rest
        '2:286',  // Allah does not burden a soul beyond its capacity
        '9:51',   // Nothing will happen to us except what Allah has decreed
        '3:173',  // Allah is sufficient for us, and He is the best Disposer of affairs
        '8:2',    // True believers — when Allah is mentioned, their hearts tremble
        '10:62',  // The allies of Allah — no fear upon them, nor shall they grieve
        '39:36',  // Is not Allah sufficient for His servant?
        '6:17',   // If Allah touches you with harm, none can remove it but He
        '33:3',   // Put your trust in Allah. Allah is sufficient as a Trustee
        '57:22',  // No calamity occurs except that it is in a Record before We bring it
      ],
    ),

    // === ANGRY ===
    FeelingAyah(
      id: 'angry',
      emoji: '😤',
      labelKey: 'feeling_angry',
      contextKey: 'context_angry',
      verseKeys: [
        '3:134',  // Who restrain anger and pardon people
        '42:37',  // Who avoid major sins and when they are angry, they forgive
        '41:34',  // Repel evil with that which is better
        '7:199',  // Show forgiveness, enjoin what is good, and turn away from the ignorant
        '42:43',  // Whoever is patient and forgives — that is a matter of determination
        '3:159',  // It is by the mercy of Allah that you were lenient with them
        '24:22',  // Let them pardon and overlook — do you not wish that Allah should forgive you?
        '16:126', // And if you punish, punish with an equivalent — but if you are patient, it is better
        '5:13',   // Pardon them and overlook — Allah loves those who do good
        '64:14',  // If you pardon and overlook and forgive — then indeed Allah is Forgiving and Merciful
      ],
    ),

    // === GRATEFUL ===
    FeelingAyah(
      id: 'grateful',
      emoji: '🤲',
      labelKey: 'feeling_grateful',
      contextKey: 'context_grateful',
      verseKeys: [
        '14:7',   // If you are grateful, I will surely increase you
        '55:13',  // So which of the favors of your Lord would you deny?
        '16:18',  // If you tried to count the blessings of Allah, you could not
        '31:12',  // Be grateful to Allah — whoever is grateful is grateful for himself
        '2:152',  // Remember Me, and I will remember you. Be grateful and do not deny
        '27:40',  // This is from the favor of my Lord to test me
        '16:114', // Eat of what Allah has provided and be grateful to Him
        '34:13',  // Work, O family of David, in gratitude — few of My servants are grateful
        '7:10',   // We established you on earth and made for you therein means of living
        '46:15',  // Let me be grateful for Your favor which You bestowed upon me
      ],
    ),

    // === OVERWHELMED / CONFUSED ===
    FeelingAyah(
      id: 'confused',
      emoji: '🤔',
      labelKey: 'feeling_confused',
      contextKey: 'context_confused',
      verseKeys: [
        '2:286',  // Allah does not burden a soul beyond that it can bear
        '94:5',   // Indeed, with hardship comes ease
        '65:7',   // Allah will bring ease after hardship
        '2:185',  // Allah intends for you ease and does not intend for you hardship
        '20:114', // My Lord, increase me in knowledge
        '3:8',    // Our Lord, do not let our hearts deviate after You have guided us
        '25:74',  // Our Lord, grant us from our spouses and offspring comfort to our eyes
        '2:45',   // Seek help through patience and prayer
        '73:8',   // Devote yourself to Him with complete devotion
        '29:69',  // Those who strive for Us — We will guide them to Our ways
      ],
    ),

    // === LONELY ===
    FeelingAyah(
      id: 'lonely',
      emoji: '💔',
      labelKey: 'feeling_lonely',
      contextKey: 'context_lonely',
      verseKeys: [
        '2:186',  // I am near. I respond to the call of the caller when he calls
        '50:16',  // We are closer to him than his jugular vein
        '57:4',   // He is with you wherever you are
        '58:7',   // There is no private conversation of three but He is the fourth
        '9:40',   // Do not grieve, indeed Allah is with us
        '29:5',   // Whoever hopes for the meeting with Allah — the term of Allah is coming
        '20:46',  // Fear not. Indeed, I am with you both — I hear and I see
        '3:139',  // Do not weaken and do not grieve
        '41:30',  // Those who said "Our Lord is Allah" and were steadfast — angels descend upon them
        '8:46',   // Be patient. Indeed, Allah is with the patient
      ],
    ),

    // === HOPEFUL ===
    FeelingAyah(
      id: 'hopeful',
      emoji: '🌅',
      labelKey: 'feeling_hopeful',
      contextKey: 'context_hopeful',
      verseKeys: [
        '94:6',   // Indeed, with hardship comes ease
        '2:216',  // Perhaps you dislike something which is good for you
        '12:86',  // I only complain of my suffering to Allah — I know from Allah that which you do not
        '12:87',  // Do not despair of relief from Allah — none despairs except the disbelieving people
        '39:53',  // Do not despair of the mercy of Allah
        '93:5',   // Your Lord is going to give you, and you will be satisfied
        '3:26',   // You give sovereignty to whom You will and take it from whom You will
        '21:87',  // There is no deity except You; exalted are You. I have been of the wrongdoers
        '40:60',  // Call upon Me; I will respond to you
        '2:153',  // Allah is with the patient
      ],
    ),

    // === LOST / SEEKING GUIDANCE ===
    FeelingAyah(
      id: 'lost',
      emoji: '🧭',
      labelKey: 'feeling_lost',
      contextKey: 'context_lost',
      verseKeys: [
        '1:6',    // Guide us to the straight path
        '6:125',  // Whomever Allah wills to guide — He expands his breast to Islam
        '2:269',  // He gives wisdom to whom He wills, and whoever is given wisdom is given much good
        '20:114', // My Lord, increase me in knowledge
        '7:43',   // Praise to Allah who guided us to this — we would not have been guided if Allah had not guided us
        '3:8',    // Our Lord, do not let our hearts deviate after You have guided us
        '29:69',  // Those who strive for Us — We will guide them to Our ways
        '42:52',  // You guide to a straight path
        '6:161',  // Indeed, my Lord has guided me to a straight path
        '16:9',   // And upon Allah is the direction of the path
      ],
    ),

    // === JUST EXPLORING ===
    FeelingAyah(
      id: 'exploring',
      emoji: '✨',
      labelKey: 'feeling_exploring',
      contextKey: 'context_exploring',
      verseKeys: [
        '55:13',  // So which of the favors of your Lord would you deny?
        '51:56',  // I did not create jinn and mankind except to worship Me
        '2:255',  // Ayat al-Kursi — Allah, there is no deity except Him
        '24:35',  // Allah is the Light of the heavens and the earth
        '59:22',  // He is Allah — there is no deity except Him, Knower of the unseen and witnessed
        '112:1',  // Say: He is Allah, the One
        '3:190',  // In the creation of the heavens and earth are signs for those of understanding
        '31:27',  // If all the trees on earth were pens and the sea were ink
        '57:3',   // He is the First and the Last, the Manifest and the Hidden
        '36:82',  // His command is only when He intends a thing — He says "Be" and it is
      ],
    ),
  ];
}
