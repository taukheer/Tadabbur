# Tadabbur تدبر

**One Ayah. Every Day. For Life.**

A daily Quran contemplation app that helps Muslims build a structured practice of tadabbur — sitting with one ayah, understanding it, and reflecting on how it connects to their life.

> *"Do they not then reflect upon the Quran, or are there locks upon their hearts?"* — Quran 47:24

## The Problem

1.8 billion Muslims recite the Quran daily — the vast majority without understanding what they say. Access to the Quran is solved. Understanding is not. No app facilitates a **daily structured tadabbur practice** connected to action.

## The Solution

Tadabbur provides a 60-second daily experience:

1. **See today's ayah** — Arabic with translation in your language
2. **Listen** — recitation from 6 world-renowned reciters
3. **Reflect** — tap "I felt this" or write a one-line reflection
4. **Build a journal** — your spiritual autobiography, one ayah at a time

### Feeling Mode

When you need guidance beyond the daily ayah:
- Select how you're feeling (anxious, lonely, grateful, etc.)
- Receive a curated ayah that speaks to your emotional state
- 90 carefully selected ayat across 9 feelings, randomized

## Features

### Core Experience
- Daily sequential ayah from Al-Fatiha to An-Nas
- Arabic text with auto-scaling for long ayat
- Translation in 21 languages
- Optional transliteration (Roman script)
- Audio recitation with play/pause (6 reciters)
- Three-tier reflection: acknowledge / respond / reflect
- Personal journal with searchable entries

### Personalization
- 21 languages with full UI translation
- 5 Arabic font options with adjustable size
- Choose starting surah (all 114 available)
- Personalized based on Arabic reading level, understanding, and motivation
- Transliteration auto-enabled for non-Arabic readers

### Retention & Habit Design
- Milestone messages (Day 3, 7, 14, 30, 100, 365)
- "Keep this ayah with you today" micro-action
- Welcome back after gap (no guilt, no streak pressure)
- Surah completion moment with choice to continue or switch
- Previous reflection resurfacing

### Authentication & Cloud
- Google Sign-In
- Quran.com OAuth2 (PKCE)
- Firebase Firestore cloud sync (journal, progress, settings)
- Guest mode with local storage (works fully offline)

### Notifications
- Daily scheduled notifications at user-chosen time
- Day-specific messaging (identity-building, not guilt)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (iOS + Android) |
| State Management | Riverpod |
| Navigation | GoRouter |
| Backend APIs | Quran Foundation (QDC) |
| Authentication | Google Sign-In + QF OAuth2 PKCE |
| Cloud Storage | Firebase Firestore |
| Local Storage | SharedPreferences |
| Audio | just_audio + Islamic Network CDN |
| Notifications | flutter_local_notifications |
| Fonts | AmiriQuran + Google Fonts (5 options) |

## Quran Foundation API Integration

### Content APIs
- `GET /verses/by_key/{key}` — Arabic text + translation
- `GET /verses/by_key/{key}?words=true` — Word-by-word with transliteration

### User APIs
- `POST /posts` — Save reflections linked to verse keys
- `POST /streaks` — Track daily streak
- `POST /activity-days` — Log daily activity

## Languages Supported (21)

English, Arabic, Urdu, Tamil, Malayalam, French, Spanish, Turkish, Indonesian, Hindi, Bengali, Malay, German, Russian, Portuguese, Persian, Somali, Swahili, Chinese, Japanese, Korean

Every user-visible string is translated — onboarding, daily screen, reflection, journal, settings, feelings, completion messages.

## Getting Started

### Prerequisites
- Flutter 3.41+
- Dart 3.11+
- Android Studio / Xcode
- Firebase project (for cloud sync)
- Google Cloud OAuth credentials (for sign-in)

### Setup

```bash
# Clone
git clone https://github.com/yourusername/Tadabbur.git
cd Tadabbur

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### Firebase Setup
1. Create project at [Firebase Console](https://console.firebase.google.com)
2. Run `flutterfire configure --project=YOUR_PROJECT_ID`
3. Enable Firestore in test mode

### Google Sign-In Setup
1. Create OAuth client at [Google Cloud Console](https://console.cloud.google.com)
2. Add SHA-1 fingerprint for Android
3. App package: `com.tadabbur.tadabbur`

## Project Structure

```
lib/
  core/
    constants/    — Languages, translations (21), feelings mapping
    models/       — Ayah, Word, JournalEntry, UserProfile, UserProgress
    providers/    — Riverpod state management
    services/     — API client, QF APIs, audio, auth, Firestore, notifications
    theme/        — Colors, typography, Arabic fonts
    widgets/      — App shell (navigation)
    router/       — GoRouter configuration
  features/
    onboarding/   — Language → personalization → surah → sign-in
    daily_ayah/   — Core experience: ayah, reflection, completion
    reflection/   — Write reflection screen
    journal/      — Searchable journal with detail view
    feelings/     — Emotion-to-ayah guidance
    settings/     — Reciter, font, language, transliteration, notifications
  firebase_options.dart
  main.dart
assets/
  data/           — Editorial content (Al-Fatiha scholarly reflections)
  fonts/          — AmiriQuran
  images/         — App icon
```

## Hackathon Submission

**Quran Foundation Hackathon 2026** — Provision Launch x Quran Foundation

- **Deadline:** April 20, 2026
- **Prize Pool:** $10,000 across 7 winners
- **Judging:** Impact (30), UX (20), Technical (20), Innovation (15), API Use (15)

### What Makes Tadabbur Different

Most apps help you **read** the Quran. Tadabbur helps you **live** it.

- No other app facilitates a **daily structured tadabbur practice**
- No other app asks **"what does this ayah say to YOU today?"**
- No other app builds a **searchable spiritual autobiography** over time
- No other app connects understanding to **your daily prayer**
- No other app offers **emotion-guided Quranic support** with curated ayat

## License

Built for the ummah. Free for every Muslim. Forever.

Built on [Quran Foundation APIs](https://api-docs.quran.foundation).
