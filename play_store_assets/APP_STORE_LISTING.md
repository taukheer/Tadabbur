# App Store Connect Listing — Tadabbur (iOS)

Copy-paste content for [App Store Connect](https://appstoreconnect.apple.com) → My Apps → Tadabbur → App Store tab → iOS App version.

> Note: App Store fields differ from Play Store. Subtitle, Promotional Text, and Keywords are iOS-only and matter for App Store search ranking. The Description is largely the same.

---

## App Name (max 30 chars)

**Tadabbur — One Ayah a Day**

*(28 chars; same as Play Store)*

---

## Subtitle (max 30 chars)

**Daily Quran contemplation**

*(26 chars)*

iOS-specific. Shown directly under the app name on the listing page and in search results. Should be a clarifier of *what the app is*, not a tagline. *"Daily Quran contemplation"* tells someone scanning search results exactly what they're looking at.

Alternates if you want to test:
- *"One ayah, every day"* — 19 chars
- *"Reflect on the Quran daily"* — 26 chars

---

## Promotional Text (max 170 chars, updateable without review)

```
First public release. One ayah a day, sequentially through the Quran. Three reflection tiers, audio from seven reciters, scholarly tafsir, 19 languages.
```

*(154 chars)*

iOS-specific. Updatable any time without going through App Review (great for announcements, sales, Ramadan messaging). Use this for time-sensitive content; use Description for evergreen content.

---

## Keywords (max 100 chars, comma-separated)

```
quran,tadabbur,islam,muslim,daily quran,ayah,reflection,tafsir,arabic,prayer,duaa
```

*(82 chars)*

iOS-specific. Drives App Store search. Don't repeat words from the app name or subtitle (Apple already weights those). Don't use plurals if the singular is in the name. Comma-separated, no spaces around commas (saves chars).

---

## Description (max 4000 chars)

Same as Play Store description. Paste this:

```
Most Quran apps push volume. Long reading streaks. Full surahs in a sitting. Leaderboards. That works for the small minority who already have the habit. For everyone else, it produces guilt the moment Ramadan ends.

Tadabbur takes the opposite approach. Depth over volume. One ayah a day. Sixty seconds. For life.

The thesis is simple. A verse contemplated deeply, repeated daily, becomes the relationship. Not the volume.

WHAT YOU GET

• A daily ayah, sequential. From Al-Fatiha through An-Nas, one verse at a time. Uthmani Arabic, five font options, optional transliteration. Audio from seven world-renowned reciters via Quran Foundation.

• A three-tier reflection system. Acknowledge with one tap on a hard day. Respond with a line on a thoughtful one. Reflect deeply when something stirs. The all-or-nothing failure mode that kills habit apps doesn't exist here.

• Feelings mode. When you come not for the daily routine but because life is hard, pick how you're feeling: anxious, grateful, lost, hopeful. Receive one of ninety curated verses mapped to that state, with audio and context.

• A journal that grows into a spiritual autobiography. Every reflection timestamped, tied to its verse, searchable. Streaks track gently with three "freezes" that absorb life without breaking the thread. Group entries by time (a diary) or by surah (a personal commentary).

• Identity-based notifications. Most apps shame: "You broke your streak!" Tadabbur affirms self-concept: "Day 7. You're someone who shows up." The wording shifts at every milestone.

DESIGNED WITH CARE

• 19 languages with full UI translation: English, Arabic, Urdu, French, Spanish, Turkish, Indonesian, Malay, Bengali, Hindi, German, Russian, Portuguese, Persian, Tamil, Swahili, Chinese, Japanese, Korean.

• Scholarly foundation. Over 1,300 pre-bundled tafsir summaries (Ibn Kathir English and Al-Muyassar Arabic) for offline access. 130 curated editorial entries draw on Ibn Kathir, Imam Al-Sa'di, Al-Qurtubi, Al-Tabari, and Ibn al-Qayyim, each surfaced with attribution so you can see the source.

• Privacy-first. Reflections are private by default. Only Tier-3 reflections can opt into the public Quran Reflect feed via the Quran Foundation API, one at a time. No social layer. No leaderboards.

• Quran Foundation integration. Sign in with quran.com to sync streaks, reflections, and bookmarks across devices. Or stay in Guest mode for full local functionality, with nothing leaving your phone.

• Offline-first. The daily flow works on a flight or in a desert. Tafsir summaries and editorial content ship in the app.

PERSONALIZATION

• Choose your starting surah, Arabic reading level, and motivation during onboarding.
• Pick from 7 reciters, 5 Arabic fonts, 4 sizes.
• Daily reminder at the time you choose.
• Hijri or Gregorian dates in the journal.
• Translation in your preferred language.

WHAT'S NOT HERE

No social feed. No leaderboards. No public friend lists. No streak shaming. No notifications shouted at you. No memorization gamification. The Quran is not a game.

A note from the builder: I built this for the Muslim I want to be. The one who shows up to the Mushaf every day, even briefly, even imperfectly, for a long time. If it helps even one other person carry that thread past Ramadan, it was worth the time.

Mohammed Taukheer
```

---

## What's New in This Version (v1.8.1)

```
First public release. Welcome.

Tadabbur delivers one ayah a day, sequentially through the Quran. Choose how you reflect: one tap, one line, or a full journal entry. Audio from 7 reciters. Tafsir from Ibn Kathir and Imam Al-Sa'di on demand. 19 languages. Reflections private by default; share to Quran Reflect when you choose.

Built around a single bet: depth over volume.
```

*(approx 395 chars; max is 4000 but this size matches what users actually read)*

---

## Categorization

- **Primary Category:** Reference
- **Secondary Category:** Lifestyle

> Apple's "Reference" category houses the established Quran apps (Quran.com, Muslim Pro). Lifestyle as secondary picks up users searching for habit/wellness apps.

---

## Age Rating

When you fill out App Store Connect's questionnaire:

- All categories: **None**
- Result: **4+** (Apple's lowest age tier)

Tadabbur has no UGC visible to others (the journal is private; only opt-in Tier-3 sharing reaches Quran Reflect, which is hosted by Quran Foundation and they handle moderation), no advertising, no in-app purchases, no location services, no third-party analytics beyond Firebase.

---

## App Store Privacy Questionnaire

This is App Store Connect's analog of Play Store's Data Safety. Path:
*App Store Connect → Tadabbur → App Privacy*

What to declare:

| Data Type | Linked to user? | Used for tracking? | Purposes |
|---|---|---|---|
| **Email Address** *(only when user signs in with Google or Apple)* | Yes | No | App Functionality, Personalization |
| **Name** *(only when user signs in)* | Yes | No | App Functionality, Personalization |
| **User ID** *(Firebase auth UID)* | Yes | No | App Functionality, Analytics |
| **Product Interaction** *(Firebase Analytics)* | No | No | Analytics |
| **Crash Data** *(Firebase Crashlytics)* | No | No | App Functionality |
| **Other User Content** *(journal reflections in Firestore for signed-in users)* | Yes | No | App Functionality |

Everything else: **None / Not collected**.

---

## App Review Information

iOS-specific section. App Review will read this before testing your app.

**Sign-In Information** *(required because Tadabbur has authenticated features)*:

```
Demo account for App Review:

Sign in via:           Quran Foundation (OAuth via quran.com)
Username:              <create a test account at https://quran.com/login>
Password:              <password for that test account>

Alternative: tap "Continue as guest" on the sign-in screen — guest mode is fully functional with no remote sync. Reviewers can test all flows except Quran Reflect publishing in guest mode.
```

**Notes for App Review:**

```
Tadabbur is a daily Quran contemplation app. The full flow works in Guest mode (tap "Continue as guest" on the sign-in screen) with no account required. To test Sign in with Quran Foundation, please use the demo credentials above. To test Sign in with Apple or Google, please use your own Apple ID or any Google account.

The "Quran Reflect" share toggle is opt-in per reflection and only appears for tier-3 reflections (≥80 characters) on Quran Foundation-authenticated accounts. Posts go to https://quran.com/reflect (a service operated by Quran Foundation, the hackathon sponsor and an established Quran-content platform).

We use Firebase for crash reporting (Crashlytics) and product analytics (Analytics). Both are declared in PrivacyInfo.xcprivacy and the App Privacy questionnaire. We do not use third-party advertising SDKs.
```

**Contact Information:**
- First Name: Mohammed
- Last Name: Taukheer
- Phone: *(your phone)*
- Email: thetadabburapp@gmail.com

---

## URLs

- **Marketing URL:** https://github.com/taukheer/Tadabbur *(or future tadabbur.app)*
- **Support URL:** https://github.com/taukheer/Tadabbur/issues *(GitHub Issues works as a support page for v1)*
- **Privacy Policy URL:** *(same as Play Store — GitHub Pages serving PRIVACY_POLICY.md)*

---

## Pricing & Availability

- **Price:** Free
- **Availability:** All territories (Apple lets you toggle countries; default to all unless you have a reason to restrict)

---

## Build Configuration in App Store Connect

After uploading the .ipa via Xcode/Transporter, App Store Connect needs you to:

1. **Select the build** — Click "+" next to "Build" in the version, pick the build that finished processing (~10-30 min after upload).
2. **Encryption usage** — Tadabbur uses HTTPS (standard) and OAuth2 (standard). Answer "No" to the "Does your app use encryption?" question because the only encryption is exempt under Apple's standard-cryptography category. Apple has a "Yes / Yes, exempt" path you can also take if you want to be extra safe; both are fine.
3. **Content rights** — Confirm you own the content (yes — you wrote the reflections, the editorial; the Quran text is in the public domain; the tafsir summaries are bundled from public-domain or open-source sources).

---

## Screenshots Required

iOS App Store requires screenshots for at least one device size. The most efficient path:

- **6.7-inch iPhone** (iPhone 16 Pro Max, 14 Pro Max, etc.) — required, **1290 × 2796** or **1284 × 2778** pixels
- 6.5-inch iPhone — auto-derived if you provide 6.7
- 5.5-inch iPhone (older devices) — optional
- iPad — only if you support iPad (skip for v1)

The simplest path: use the iPhone 16e simulator we've been testing on (which renders at the right resolution for 6.7-inch). Screenshots captured via Cmd+S on the simulator are accepted by App Store Connect.

Capture the same 4-7 screens recommended for Play Store:
1. Daily ayah hub
2. Reflection writing surface
3. Feelings picker
4. Journal home
5. Settings (showing language picker)
6. Onboarding language picker
7. Quran Reflect share toggle (optional)

---

## TestFlight (recommended before Production)

After upload + build processes:

1. App Store Connect → Tadabbur → **TestFlight** tab
2. Add yourself as an Internal Tester (one click — uses your Apple ID)
3. Add a few external testers via email (optional)
4. Push the build to your testers
5. Once validated, **submit to App Review** for production release

For the hackathon submission, the **TestFlight public link** can be the iOS demo link in `SUBMISSION.md`. That avoids waiting for App Review.
