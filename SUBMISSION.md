# Tadabbur — Quran Foundation Hackathon Submission

## Project Title
**Tadabbur** — One ayah. Every day. For life.

## Team
- Mohammed Taukheer (solo)

## Short Description
Tadabbur is a daily Quran contemplation app built around one verse a day, a three‑tier reflection ladder, and a feelings‑based search — all wired through the Quran Foundation Content and User APIs so that streaks, reflections, bookmarks, and Quran Reflect posts stay in sync with the user's quran.com identity.

## The Problem (and why it's the brief)
The hackathon brief identifies the core gap directly:

> "Many reconnect during Ramadan, but maintaining engagement afterwards is difficult."

Most Quran apps optimise for *volume* — long reading streaks, full‑surah sessions, leaderboards. That works for the ~5% who already have the habit. For everyone else it produces guilt, then disengagement, the moment Ramadan ends.

Tadabbur takes the opposite bet: **depth over volume.** One ayah. Sixty seconds. Every day. Forever.

---

## How Tadabbur Maps to the 100‑Point Rubric

### 1. Impact on Quran Engagement — 30 pts (tiebreaker)

The product thesis is engagement that *outlasts Ramadan*. Every design decision serves this:

- **Sequential daily delivery from Al‑Fatiha through An‑Nas.** The user is on a personal walk through the entire Mushaf — not picking from a feed. Showing up matters more than catching up; freezes (3) absorb life without breaking the streak.
- **Three‑tier reflection ladder** — *Acknowledge → Respond → Reflect* — meets the user where they are on each given day. A bad day is one tap; a thoughtful one is a guided journal entry. Both *count*. This is the single most engagement‑relevant feature: it removes the all‑or‑nothing failure mode that kills habit apps.
- **Identity‑based notifications** ("Day 7. You're someone who shows up.") affirm a self‑concept rather than guilt‑trip. The completion screen line — *"You showed up today. This counts."* — is the emotional core.
- **Feelings mode** catches the user when they come *because life is hard*, not because they're on schedule. 90 curated ayat across 9 emotional states (anxious, lonely, grateful, lost, hopeful, low, angry, confused, exploring) — randomised so the same emotion surfaces a different verse each time.
- **The journal becomes a spiritual autobiography.** Every reflection is searchable, timestamped, and bound to its verse — so the longer the user stays, the more value the app accrues. Switching cost grows with use; that's how engagement compounds past Ramadan.

### 2. Product Quality & UX — 20 pts

- **Designed as a sacred space, not a productivity tool** — calm palette, restrained motion, no streaks shouted at the user, no leaderboards, no emojis on Feeling cards.
- **19 languages shipped with end‑to‑end UI coverage**: English, Arabic, Urdu, French, Spanish, Turkish, Indonesian, Malay, Bengali, Hindi, German, Russian, Portuguese, Persian, Tamil, Swahili, Chinese (Simplified), Japanese, Korean. Every visible UI string, reflection prompt, feeling label, streak‑copy variant, and font genre description is translated. Malayalam and Somali are deferred until native translators can review — they remain in the translations file as English fallback so the architecture is ready, but they're hidden from the language picker so users only see languages we can stand behind.
- **Arabic typography** — 5 font options (AmiriQuran, Noto Naskh Arabic, system, etc.), 4 sizes, RTL‑safe, locale‑tagged for correct shaping. Optional transliteration for non‑Arabic readers, auto‑enabled when the onboarding flow detects no Arabic reading ability.
- **6‑step onboarding** that personalises the experience: Arabic level, comprehension level, motivation (salah / connection / practice / learning), starting surah, language, sign‑in or guest. Output: a verse cadence, prompt style, and notification tone tuned to *this* user.
- **Empty states, loading states, and error states are explicit** on every screen — no blank spinners, no silent failures. Recent polish pass added: error message surfacing on the daily‑ayah load failure, snackbar feedback on Feelings‑mode API failures, snackbar on journal pull‑to‑refresh failures, and an explicit *"Shared to Quran Reflect"* confirmation on the completion screen when the user opted in.
- **Accessibility**: tooltips on icon‑only buttons, Semantics labels on the audio button, font‑size respect, contrast against dark/light themes.

### 3. Technical Execution — 20 pts

- **Stack**: Flutter 3.41+ / Dart 3.11+ · Riverpod 2.6 · GoRouter 14.8 · Dio 5.7 (retry + exponential backoff with jitter) · just_audio · Firebase (Firestore + Crashlytics + Analytics) · flutter_local_notifications.
- **Security posture**:
  - OAuth2 with **PKCE** for QF sign‑in; secrets injected at build time via `--dart-define`, never committed.
  - Tokens encrypted via `flutter_secure_storage` (Android EncryptedSharedPreferences / iOS Keychain).
  - **Firestore deny‑by‑default rules**: only the owner can read/write their own `users/{uid}` doc and journal/bookmarks subcollections; per‑doc size caps; `feedback/` create‑only with no client read; rules deployed via repo‑tracked `firebase.json` (no Test Mode).
  - Debug‑only API logging guarded by `kDebugMode`.
  - State + code parameter validation on the OAuth callback.
- **Offline‑first**: tafsir summaries (1,300+ passages, Ibn Kathir EN + Al‑Muyassar AR) and 130 editorial entries are pre‑bundled; the app is fully usable with no network. Firestore sync is fire‑and‑forget with a 50‑op replay queue cap. QF sync is non‑blocking with graceful degradation.
- **Performance**: parallel fetch for ayah + words + editorial + surah info + tafsir; in‑memory caching of editorial JSON; 7‑day audio URL cache; idempotent loaders that survive backgrounding.
- **Reliability**: audio resolution has a documented two‑tier fallback (QF recitations API → `cdn.islamic.network`); fallback events are recorded as non‑fatal Crashlytics records and an `audio_fallback_used` Analytics event so silent regressions are visible. Reciter selection writes both the QF reciter id (used by the audio call) and the CDN slug (used by the fallback) — the QF integration sees the actually‑selected reciter, not just a default.
- **Error handling**: every catchable failure either retries, reports to `SyncReporter`, or surfaces user‑visible feedback — no silent `catch (_) {}` blocks in user‑facing flows.

### 4. Innovation & Creativity — 15 pts

Three fresh ideas, each named and shipped:

1. **The three‑tier reflection ladder** (Acknowledge / Respond / Reflect). Tier‑1 is a single tap and counts as a complete day. Tier‑2 is a 1–2 line response to a curated prompt. Tier‑3 is a full journal entry with an editorial contemplation question. This isn't a setting — it's the daily decision the user makes, and it dissolves the "I don't have time to engage properly today" failure mode.
2. **Feelings mode** — the user enters their emotional state and the Quran answers them. 90 verses, 9 emotions, randomised. Most Quran apps treat the Quran as a corpus to navigate; this treats it as a counsellor.
3. **Identity‑based notifications.** Most habit apps shame ("You broke your streak!"). Tadabbur reinforces identity ("You're someone who shows up"). The wording shifts every milestone (Day 3, 7, 14, 30, 100, 365, plus ayat milestones) — a quiet, principled departure from gamification orthodoxy.

### 5. Effective Use of APIs — 15 pts

Tadabbur uses **multiple Content APIs and multiple User APIs**, not the single‑category minimum.

#### Content APIs (Quran Foundation / QDC)
| API | Endpoint | Usage |
|-----|----------|-------|
| Quran (Verses) | `/verses/by_key/{key}` | Daily verse Arabic (Uthmani) + chapter context |
| Translation | `/verses/by_key/{key}?translations={id}` | Per‑user translation in 19 languages |
| Word‑by‑word | `/verses/by_key/{key}?words=true` | Optional word breakdown + transliteration |
| Audio | `/recitations/{reciter_id}/by_chapter/{chapter}` → `audio.qurancdn.com` | Attempted first for per‑verse audio. Each reciter selection is wired to the QF reciter id, so the call asks for the actually-selected reciter — not the default. Falls back to `cdn.islamic.network` (the only CDN with reliable per‑ayah files for all 7 reciters today) when QF returns no audio. Fallback events logged to Crashlytics + Analytics so a regression in either source is observable. |
| Audio Reciters Catalogue | `/audio/reciters` | Live‑fetched on Settings open and cached for 7 days; the count of reciters available on Quran Foundation is rendered under the RECITER section header so the integration is visible to a judge in 5 seconds. |
| Tafsir | `/tafsirs/{slug}/by_ayah/{key}` | Full tafsir on demand from the bottom sheet |
| Chapters | `/chapters/{num}` | Surah metadata: revelation type, verse count, name variants |

#### User APIs (Quran Foundation)

All user APIs are gated to QF‑authenticated users (`authType == quranFoundation`). For Google or Guest users the calls are silent no‑ops — no half‑completed sync state, no spurious 401s in logs.

| API | Usage |
|-----|-------|
| **Activity & Goals** | `POST /v1/activity-days` — fires non‑blocking on every ayah completion. This is what drives streaks: QF computes streak length server‑side from the activity ledger, so streaks roam with the user across devices. |
| **Reflections / Notes** | `POST /v1/notes` — every reflection (any tier) syncs as a note bound to the verse key. Tier‑1 acknowledgements include a placeholder body so they're recoverable as journal events even though the API requires a non‑empty payload. |
| **Quran Reflect (Posts)** | Same `/v1/notes` call with `saveToQR: true`. Opt‑in per reflection via a toggle that only renders for tier‑3 entries (≥80 chars) on QF‑authenticated accounts. The completion screen confirms the post landed with a small *Shared to Quran Reflect* line so the user knows their words went public. |
| **Bookmarks** | `POST /v1/bookmarks` — auto‑bookmarks any verse the user writes a tier‑2 or tier‑3 reflection on. The journal pull‑to‑refresh also calls `GET /v1/notes` to hydrate reflections written from quran.com on another device. |

#### Auth — also a QF API surface
- **OAuth2 with PKCE** against the QF identity provider, scope `note` for personal notes + Quran Reflect publishing.
- Falls back to **Google Sign‑In** or **Guest mode** (full local functionality, no remote sync) for users not in the QF identity.

---

## Core Features Summary

### Daily Ayah
Sequential progression Al‑Fatiha → An‑Nas; Uthmani Arabic; 21 translations; transliteration; 7 reciters resolved through the QF audio API with `cdn.islamic.network` fallback; surah/juz/Makki‑Madani metadata; sajdah indicator on the 15 prostration verses; thematic hook line when verified editorial content exists.

### Three‑Tier Reflection
Acknowledge (1 tap) · Respond (1–2 lines, curated prompt) · Reflect (deep, with tier‑3 question). Every entry stored locally + Firestore + QF Notes. Tier‑3 has the opt‑in *Share to Quran Reflect* toggle.

### Feelings Mode
9 emotions, 90 ayat, randomised, with context, audio, and a quiet "Take a moment for dua" line.

### Scholarly Content
1,300+ pre‑bundled tafsir summaries (Ibn Kathir EN + Al‑Muyassar AR) for offline access; 130 curated editorial entries (historical context, scholar reflection, tier‑2 prompt, tier‑3 question) verified against the QDC API; "Read more" loads the full tafsir on demand.

### Habit & Identity
Streaks with 3 freezes; milestone celebrations (3 / 7 / 14 / 30 / 100 / 365 + ayat milestones at 1 / 50 / 100); identity‑based notifications; first‑time guidance; yesterday‑continuity copy.

### Personalization
Language · Arabic level · comprehension · motivation · starting surah · reciter · font · font size · daily notification time · transliteration toggle · Hijri/Gregorian journal headers.

### Auth & Sync
Google · QF OAuth2 PKCE · Guest. Cloud sync via Firestore (deny‑by‑default rules). QF sync is non‑blocking with retry queue.

### Platforms
- Android (production‑ready, signed APK builds via `scripts/build-apk.sh`)
- iOS (configured, simulator‑tested)

---

## Submission Deliverables

- **GitHub:** [https://github.com/taukheer/Tadabbur](https://github.com/taukheer/Tadabbur)
- **Live demo:** Android APK + Play Store closed test (link to be added)
- **Demo video (2–3 min):** to be recorded — script lands on the brief's *"engagement that outlasts Ramadan"* problem, then walks Daily Ayah → Three‑tier reflection → Feelings → Journal → Quran Reflect share.
- **Contact:** thetadabburapp@gmail.com

---

## Why Tadabbur Should Win the Tiebreaker

Impact on Quran Engagement is the most heavily weighted criterion (30 pts) **and the tiebreaker**. Tadabbur was designed from day one around the brief's literal problem statement: *make the relationship lasting, not just intense*. Every architectural decision — sequential delivery, three‑tier ladder, identity nudges, Feelings mode, the journal as autobiography — bends toward that single goal.
