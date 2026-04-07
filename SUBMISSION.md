# Tadabbur — Quran Foundation Hackathon Submission

## Project Title
Tadabbur

## Team
- Mohammed Taukheer

## Short Description
One ayah. Every day. For life. Tadabbur is a daily Quran contemplation app that helps Muslims build a lasting relationship with the Quran through guided reflection, scholarly tafsir, and habit-forming design.

## Detailed Description

Tadabbur transforms the way Muslims engage with the Quran daily. Instead of overwhelming users with full surahs or complex study tools, it delivers one ayah per day with a carefully designed experience that takes 60 seconds — and leaves a lasting impression.

The app guides users through a simple flow: listen to the ayah, read its translation, sit with it, and reflect. Over time, this builds into a spiritual autobiography — a personal journal of every verse that touched them.

### What makes Tadabbur different

**Simplicity as a feature.** Most Quran apps try to do everything. Tadabbur does one thing exceptionally well: daily contemplation. The interface is calm, minimal, and intentional — designed to feel like a sacred space, not a productivity tool.

**Tiered reflection system.** Not every day requires deep scholarship. Some days, all you can do is acknowledge the ayah touched you. Other days, you want to write. Tadabbur supports three tiers:
- **Acknowledge** — "I felt this" (one tap)
- **Respond** — Write a line guided by a reflection prompt
- **Reflect** — Deep contemplation with scholarly questions

**Scholarly depth, on demand.** Every verse has a tafsir summary from Ibn Kathir (English) or Al-Tafsir Al-Muyassar (Arabic), pre-bundled locally for instant offline access. Users can tap "Read more" to load the full tafsir. 130 key verses across all 114 surahs also have curated editorial content — historical context, scholar reflections, and contemplation prompts — all verified against authentic sources.

**Feelings mode.** When users come to the app not for their daily ayah but because they need comfort, they can select how they're feeling — anxious, lonely, grateful, lost — and receive a curated ayah with context for that emotional state. 90 ayat mapped across 9 feelings.

**Habit architecture, not guilt.** The app uses identity-based notifications ("Day 7. You're someone who shows up."), streak tracking with freeze allowances, and quiet day counters — never guilt-tripping, always affirming. The completion message "You showed up today. This counts." is the emotional core.

**21 languages.** Every UI string, reflection prompt, and feeling label is translated into 21 languages including Arabic, Urdu, Tamil, Malayalam, French, Spanish, Turkish, Indonesian, Hindi, Bengali, Malay, German, Russian, Portuguese, Persian, Somali, Swahili, Chinese, Japanese, and Korean.

## Core Features

### Daily Ayah Experience
- Sequential verse progression from Al-Fatiha through An-Nas
- Arabic text in Uthmani script with customizable fonts (AmiriQuran, Noto Naskh, system)
- Adjustable Arabic font size (Small / Medium / Large / Extra Large)
- Translations in 21 languages from quran.com API
- Optional transliteration for non-Arabic readers
- Audio recitation from 6 world-renowned reciters via Islamic Network CDN
- Surah pill showing surah name, ayah number, and juz number
- Makki/Madani revelation type badge
- Sajdah indicator for the 15 prostration verses
- Thematic hook line ("Today's ayah invites you to reflect on mercy")

### Scholarly Content
- Tafsir summaries for 1,300+ verse passages pre-bundled (Ibn Kathir EN + Al-Muyassar AR)
- 130 curated editorial entries across all 114 surahs (English + Arabic)
- Each editorial entry includes: historical context, scholar reflection, tier 2 prompt, tier 3 question
- Surah introduction for every surah
- Full tafsir available on demand via "Read more" bottom sheet
- Sources: Ibn Kathir, Al-Sa'di, Al-Qurtubi, Al-Tabari, Ibn al-Qayyim
- All editorial content verified against fetched tafsir from quran.com canonical API

### Reflection System
- Three-tier reflection: Acknowledge / Respond / Reflect
- Guided reflection prompts (editorial-curated for key verses, generic translated for others)
- Previous reflection memory ("Earlier, you paused on...")
- Completion celebration with identity reinforcement

### Feelings Mode
- 9 emotional states: low, anxious, angry, grateful, confused, lonely, hopeful, lost, exploring
- 90 curated ayat (10 per feeling) with context explanations
- Randomized selection to avoid predictability
- Audio playback with reactive play/pause

### Journal
- Searchable reflection history
- Filter by surah or reflection tier
- Every reflection stored with verse key, Arabic text, translation, and timestamp

### Habit & Identity System
- Daily streak tracking with freeze allowances (3 gaps without breaking)
- Milestone celebrations (Day 3, 7, 14, 30, 100, 365 + ayat milestones at 1, 50, 100)
- Identity-based notifications ("You're building something", "You're consistent")
- Day counter pill on the daily screen
- First-time user guidance ("Sit with this for a moment")
- Yesterday's continuity ("Welcome back. Pick up where you left off.")

### Personalization
- Language selection (21 languages)
- Arabic reading level assessment (fluent, basic, none)
- Understanding level (most, some, none)
- Motivation selection (salah, connection, practice, learning)
- Starting surah choice (Al-Fatiha, Ya-Sin, Ar-Rahman, Al-Mulk, Juz Amma, or any of 114 surahs)
- Auto-enabled transliteration for non-Arabic readers
- Reciter selection (6 reciters)
- Font and font size customization
- Daily notification time picker

### Authentication
- Google Sign-In (Android + iOS)
- Quran Foundation OAuth2 PKCE
- Guest mode (full functionality, local-only data)
- Cloud sync via Firebase Firestore (non-blocking, fire-and-forget)

## Technical Architecture

### Stack
- **Framework**: Flutter 3.41+ / Dart 3.11+
- **State Management**: Riverpod 2.6.1
- **Navigation**: GoRouter 14.8.1
- **HTTP**: Dio 5.7.0 with retry logic and exponential backoff + jitter
- **Audio**: just_audio 0.9.42
- **Local Storage**: SharedPreferences (preferences) + flutter_secure_storage (auth tokens)
- **Cloud**: Firebase Core, Firestore, Crashlytics, Analytics
- **Auth**: google_sign_in, OAuth2 PKCE with crypto
- **Notifications**: flutter_local_notifications with flutter_timezone
- **UI**: Material 3, flutter_animate, google_fonts

### Security
- Auth tokens encrypted via flutter_secure_storage (Android EncryptedSharedPreferences)
- OAuth credentials injected at build time via --dart-define (not in source code)
- PKCE code verifier stored securely with cleanup after exchange
- OAuth callback validates both code and state parameters
- API logging restricted to debug mode only (kDebugMode guard)
- Input validation with safe parsing (int.tryParse with fallbacks)

### Performance
- Tafsir summaries pre-bundled locally (0.6 MB) — zero API calls for scholarly content
- Editorial content loaded from local JSON with in-memory caching
- Exponential backoff with random jitter for API retries
- Firestore retry queue capped at 50 operations to prevent memory leaks
- Single parallel fetch for ayah + words + editorial + surah info + tafsir

### Offline-First Design
- All core functionality works without internet
- Local SharedPreferences stores progress, journal, preferences
- Tafsir summaries and editorial content bundled in app
- Firestore sync is fire-and-forget with retry queue
- QF API sync is non-blocking with graceful failure

### Monitoring
- Firebase Crashlytics for crash reporting (disabled in debug)
- Firebase Analytics tracking: ayah_completed, reflection_added events
- Automatic session, retention, and device analytics

## API Integration

### Content APIs (quran.com / QDC)
| API | Endpoint | Usage |
|-----|----------|-------|
| Quran Text | `/verses/by_key/{key}` | Fetch Arabic text (Uthmani) + translation per verse |
| Word-by-Word | `/verses/by_key/{key}?words=true` | Word breakdown with transliteration |
| Translation | `/verses/by_key/{key}?translations={id}` | 21 language translations |
| Tafsir | `/tafsirs/{slug}/by_ayah/{key}` | Full tafsir on demand (Read more) |
| Chapters | `/chapters/{num}` | Surah info (revelation type, verse count) |
| Audio | Islamic Network CDN | Per-verse recitation streaming |

### User APIs (quran.com / QDC)
| API | Usage |
|-----|-------|
| Streak Tracking | `updateStreak()` — syncs daily streak on ayah completion |
| Activity Logging | `logActivityDay()` — records daily Quran engagement |
| Reflections | `saveReflection()` — syncs journal entries to QF |

### Pre-bundled Data (from quran.com API, fetched at build time)
| Data | Source | Entries |
|------|--------|---------|
| Tafsir summaries (EN) | Ibn Kathir via QDC API | 300 passage summaries |
| Tafsir summaries (AR) | Al-Muyassar via QDC API | 1,013 passage summaries |
| Editorial content (EN) | Curated from fetched tafsir | 130 entries |
| Editorial content (AR) | Curated from fetched tafsir | 130 entries |

## Platforms
- Android (tested, production-ready)
- iOS (configured, simulator-tested)

## Links
- GitHub: [repository URL]
- Demo Video: [to be recorded]
- APK Download: `build/app/outputs/flutter-apk/app-release.apk`

## Contact
- Email: thetadabburapp@gmail.com
