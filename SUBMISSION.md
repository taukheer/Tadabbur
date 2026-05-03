# Tadabbur

**One ayah. Every day. For life.**

A daily Quran contemplation app, submitted to the Quran Foundation Hackathon 2026.

---

## The problem we set out to solve

The hackathon brief named it directly:

> *"Many reconnect during Ramadan, but maintaining engagement afterwards is difficult."*

That sentence describes most Muslims I know. The relationship with the Quran spikes for a month and then quietly fades. The apps that exist today don't help with this — they optimise for *volume*: long reading streaks, full surahs in a sitting, leaderboards. That works for the small minority who already have the habit. For everyone else, it produces guilt the moment Ramadan ends.

Tadabbur takes the opposite bet: **depth over volume.** One ayah a day. Sixty seconds. Forever. The thesis is that a verse contemplated deeply, repeated daily, becomes the relationship — not the volume.

---

## What we built

A Flutter app for Android and iOS that does five things, all in service of that thesis:

**A daily ayah, sequential.** From Al-Fatiha through An-Nas, one verse a day. The user is on a personal walk through the entire Mushaf — not picking from a feed. The Arabic is Uthmani script (5 font options, 4 sizes, locale-aware shaping). The translation is in the user's chosen language, alongside optional transliteration. Audio is from seven world-renowned reciters, resolved through Quran Foundation's recitations API with a fallback CDN so playback never fails silently.

**A three-tier reflection ladder.** *Acknowledge* (one tap, "I felt this"). *Respond* (one or two lines, with a curated prompt). *Reflect* (a full journal entry, with a deeper contemplation question for the 130 verses where we ship editorial content). The user picks the depth on a given day. A bad day is one tap and still counts. A thoughtful day fills the journal. The all-or-nothing failure mode that kills habit apps doesn't exist here.

**Feelings mode.** When a user opens the app not for the daily routine but because life is hard, they pick how they're feeling — anxious, lonely, grateful, lost, hopeful — and receive one of ninety curated ayat mapped to that state. With audio, with context, with a quiet *"take a moment for dua"* line at the end. Most Quran apps treat the Quran as a corpus to navigate; this treats it as a counsellor.

**A journal that becomes a spiritual autobiography.** Every reflection is timestamped, tied to its verse, searchable, and groupable two ways — by time (a diary) or by surah (a personal commentary). A heatmap shows the practice. Streaks track gently, with three "freezes" that absorb life without breaking the thread. The longer the user stays, the more the journal accrues — that's what compounds engagement past Ramadan.

**Identity-based notifications.** Most habit apps shame ("You broke your streak!"). Tadabbur affirms self-concept ("Day 7. You're someone who shows up."). The wording shifts at every milestone — Day 3, 7, 14, 30, 100, 365 — a quiet, principled departure from gamification orthodoxy.

---

## How it's built

**Stack:** Flutter 3.41 / Dart 3.11 · Riverpod for state · GoRouter for navigation · Dio for HTTP (with retry, exponential backoff, and jitter) · just_audio · Firebase (Firestore + Crashlytics + Analytics) · flutter_local_notifications · flutter_secure_storage for token persistence.

**Quran Foundation integration runs through almost every screen:**

The daily verse, its translation, word-by-word breakdown, full tafsir on demand, surah metadata, and the audio URL are all resolved through the QDC content APIs. The reciter catalogue under Settings is live-fetched from `/audio/reciters` on every Settings open and cached for seven days. Audio playback attempts the QF recitations endpoint first; when it returns nothing (which it does on the public unauth path for non-Mishary reciters today), the app falls back to `cdn.islamic.network` and logs the fallback as a non-fatal Crashlytics event so we'd notice if either source regressed.

For QF-authenticated users, the app speaks the User APIs end-to-end: every ayah completion logs a day to `/v1/activity-days` (which is what drives streaks server-side, so the streak roams across devices). Every reflection writes to `/v1/notes` bound to the verse key. Tier-3 reflections that opt into the share toggle land on the public Quran Reflect feed via the same `/v1/notes` call with `saveToQR: true`. Tier-2 and Tier-3 reflections also auto-bookmark the verse via `/v1/bookmarks`. The journal's pull-to-refresh hydrates remote notes back from `/v1/notes` so a reflection a user wrote on quran.com from another device shows up here too. All of this is gated to QF-authenticated users — Google and Guest users get silent no-ops, never spurious 401s in the logs.

Authentication is OAuth2 with PKCE against the QF identity provider, with `note` scope. Falls back to Google Sign-In or Guest mode (full local functionality, no remote sync) for users not in the QF identity.

**Offline-first.** Tafsir summaries (1,300+ passages, Ibn Kathir English plus Al-Muyassar Arabic) and 130 curated editorial entries are bundled into the app at build time, so the daily flow works on a flight or in a desert. Firestore writes are fire-and-forget with a 50-operation replay queue. QF sync is non-blocking with graceful degradation.

**Security.** OAuth secrets are injected at build time via `--dart-define`, never committed. Tokens are encrypted via `flutter_secure_storage` (Android EncryptedSharedPreferences, iOS Keychain). Firestore rules deny by default — only the owner can read or write their own `users/{uid}` doc and journal/bookmarks subcollections; per-document size caps cap a worst-case payload at 16 KiB; the `feedback/` collection is create-only with no client read. The rules are repo-tracked in `firestore.rules` and deployed via `firebase.json`, so we never shipped on Test Mode. Debug API logging is guarded by `kDebugMode` so production builds don't leak request URIs.

**Languages.** Nineteen languages with end-to-end UI coverage — English, Arabic, Urdu, French, Spanish, Turkish, Indonesian, Malay, Bengali, Hindi, German, Russian, Portuguese, Persian, Tamil, Swahili, Chinese (Simplified), Japanese, Korean. Every visible string — onboarding, daily screen, reflection, journal, settings, feelings, audio player, scholar tab, font descriptions, streak copy, tier badges — is translated. The streak copy is the same "thread" metaphor in every language for brand coherence (الخيط in Arabic, le fil in French, இழை in Tamil, 糸 in Japanese), and the year-card tagline *"may these be written in your scales"* uses each language's word for the Quranic *mizan*.

---

## What's deliberately out of scope

A few things we considered and didn't build, to keep the thesis honest:

- **No social or community layer.** No leaderboards, no friend lists, no public commenting on each other's reflections. The journal is private by default; only Tier-3 reflections can opt into the public Quran Reflect feed, one at a time. The brand bet is that depth happens in private; making the user *compete* would betray it.
- **No hifz / memorization mode.** The audio service has a loop-count primitive in code, but we didn't build a memorization workflow on top of it. That's a different product. We chose not to dilute.
- **No tajwīd analysis.** Not a contemplation feature. Out of scope.
- **No verse-search.** The user navigates by sequential daily flow or Feelings, not by full-text query. This is a deliberate constraint — it forces engagement with what's served, not what the user wishes for.

---

## What's still scaffolding

Two languages — Malayalam and Somali — are present in `lib/core/constants/translations.dart` but hidden from the language picker. The translations exist as English fallback so the architecture is ready, but they need a native Mappila or East African Sunni-Sufi reviewer before we can stand behind them. Tamil, Bengali, and Swahili were translated end-to-end as best-effort by a non-native; native review is recommended before launch.

A handful of low-traffic UI surfaces (Year-in-Ayat share card text, sign-out-of-quran.com confirmation dialog) still ship in English fallback for non-English users. The architecture goes through `AppTranslations.get` everywhere; just a final translation pass remains.

---

## Editorial content

The 130 curated editorial entries (one per ~50 of the most-engaged-with verses) draw on Ibn Kathir's *Tafsīr al-Qurʾān al-ʿAẓīm*, Imam Al-Sa'di's *Taysīr al-Karīm al-Raḥmān*, and select passages from Al-Qurṭubī, Al-Ṭabarī, and Ibn al-Qayyim. Each entry surfaces in the daily ayah card with a one-line attribution — *"Drawing on Ibn Kathir"*, *"Drawing on Imam Al-Sa'di"*, etc. — so a careful reader can see the curated layer is grounded in classical tafsir, not LLM paraphrase.

For the other 6,106 verses, the app uses pre-bundled Ibn Kathir summaries (English) and Al-Muyassar summaries (Arabic), pulled from QDC at build time and stored locally. "Read more" on any verse opens the full tafsir from the QDC API on demand.

A native scholar review of the editorial layer is on the post-hackathon roadmap — flagged in the README as something we're aware of, not pretending to have already done.

---

## Try it

- **GitHub:** https://github.com/taukheer/Tadabbur
- **Demo video (2–3 min):** *to be recorded; opens with the brief's "engagement past Ramadan" problem and walks the daily flow, the three-tier ladder, Feelings, the journal, and a Quran Reflect share*
- **APK / Play Store closed test:** *link to be added*
- **Contact:** thetadabburapp@gmail.com

---

## A note from the builder

I built this for the Muslim I want to be — the one who shows up to the Mushaf every day, even briefly, even imperfectly, for a long time. If it helps even one other person carry that thread past Ramadan, it was worth the time.

— Mohammed Taukheer
