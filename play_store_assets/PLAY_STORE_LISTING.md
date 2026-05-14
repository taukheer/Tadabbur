# Play Store Listing — Tadabbur

Copy-paste content for [Play Console](https://play.google.com/console) → Tadabbur → Main Store Listing.

---

## App name (max 30 chars)

**Tadabbur — One Ayah a Day**

*(28 chars)*

Alternates if you want to test:
- *Tadabbur · Daily Quran* — 22 chars
- *Tadabbur — Daily Quran* — 22 chars

---

## Short description (max 80 chars)

**One ayah a day. Sit with it. A daily Quran practice that lasts past Ramadan.**

*(78 chars)*

Alternate:
- *Daily Quran contemplation. One verse a day. Reflect, journal, return.* (69 chars)

---

## Full description (max 4000 chars)

```
Most Quran apps optimise for volume — long reading streaks, full-surah sessions, leaderboards. That works for the small minority who already have the habit. For everyone else, it produces guilt the moment Ramadan ends.

Tadabbur takes the opposite bet: depth over volume. One ayah a day. Sixty seconds. For life.

The thesis is simple — a verse contemplated deeply, repeated daily, becomes the relationship. Not the volume.

WHAT YOU GET

• A daily ayah, sequential. From Al-Fatiha through An-Nas, one verse at a time. Uthmani Arabic, 5 font options, optional transliteration. Audio from 7 world-renowned reciters via Quran Foundation.

• A three-tier reflection system. Acknowledge with one tap on a hard day. Respond with a line on a thoughtful one. Reflect deeply when something stirs. The all-or-nothing failure mode that kills habit apps doesn't exist here.

• Feelings mode. When you come not for the daily routine but because life is hard, pick how you're feeling — anxious, grateful, lost, hopeful — and receive one of 90 curated ayat mapped to that state, with audio and context.

• A journal that becomes a spiritual autobiography. Every reflection timestamped, tied to its verse, searchable. Streaks track gently with three "freezes" that absorb life without breaking the thread. Group entries by time (a diary) or by surah (a personal commentary).

• Identity-based notifications. Most apps shame ("You broke your streak!"). Tadabbur affirms self-concept ("Day 7. You're someone who shows up."). The wording shifts at every milestone.

DESIGNED WITH CARE

• 19 languages with full UI translation: English, Arabic, Urdu, French, Spanish, Turkish, Indonesian, Malay, Bengali, Hindi, German, Russian, Portuguese, Persian, Tamil, Swahili, Chinese, Japanese, Korean.

• Scholarly foundation. 1,300+ pre-bundled tafsir summaries (Ibn Kathir English + Al-Muyassar Arabic) for offline access. 130 curated editorial entries draw on Ibn Kathir, Imam Al-Sa'di, Al-Qurtubi, Al-Tabari, Ibn al-Qayyim — each surfaced with attribution so you can see the source.

• Privacy-first. Deny-by-default Firestore rules. Reflections are private by default; only Tier-3 reflections can opt into the public Quran Reflect feed via the Quran Foundation API, one at a time. No social layer. No leaderboards.

• Quran Foundation integration. Sign in with quran.com to sync streaks, reflections, and bookmarks across devices. Or stay in Guest mode — full local functionality, nothing leaves your phone.

• Offline-first. The daily flow works on a flight or in a desert. Tafsir summaries and editorial content ship in the app.

PERSONALIZATION

• Choose your starting surah, Arabic reading level, and motivation during onboarding.
• Pick from 7 reciters, 5 Arabic fonts, 4 sizes.
• Daily reminder at the time you choose.
• Hijri or Gregorian dates in the journal.
• Translation in your preferred language.

WHAT'S DELIBERATELY NOT HERE

No social feed. No leaderboards. No public friend lists. No streak shaming. No notifications shouted at you. No memorization gamification. The Quran is not a game.

A note from the builder: I built this for the Muslim I want to be — the one who shows up to the Mushaf every day, even briefly, even imperfectly, for a long time. If it helps even one other person carry that thread past Ramadan, it was worth the time.

— Mohammed Taukheer
```

*(approx 3,250 characters)*

---

## Category

**Books & Reference** (primary)

Alternate consideration: *Lifestyle*. But Books & Reference is where the established Quran apps live (Quran.com, Muslim Pro Quran, etc.) and where users searching for *"Quran"* expect to find apps. Lifestyle would underplay the scholarly foundation.

---

## Content rating questionnaire — expected outcome

When you fill out the IARC questionnaire in Play Console, your answers should land Tadabbur at:

- **Everyone** rating
- **No** to: violence, sexual content, profanity, controlled substances, gambling, user-generated content visible to others (the journal is private; only opt-in Tier-3 sharing reaches Quran Reflect, which is hosted by quran.com — they handle moderation), in-app purchases, location sharing, advertising.

---

## Tags / keywords

Play Console doesn't have explicit keyword fields anymore (search uses the full description). But for discoverability, ensure these phrases appear naturally in the description above (they do):

- *Quran*, *Quran app*, *Daily Quran*
- *Tadabbur*, *contemplation*, *reflection*
- *Ayah*, *daily verse*
- *Tafsir*, *Ibn Kathir*
- *Muslim*, *Islamic app*

---

## Contact details

- **Email:** thetadabburapp@gmail.com
- **Website:** https://tadabbur-jet.vercel.app
- **Phone:** *leave blank — not required for Play Console*

---

## Privacy Policy URL

`https://tadabbur-jet.vercel.app/privacy`

(Served by the Tadabbur landing site on Vercel. Updates ship with the
site repo. Previous URLs — `tadabbur-beige.vercel.app/privacy` and
`taukheer.github.io/Tadabbur/PRIVACY_POLICY.html` — return 404 and
must NOT be used in Play Console / App Store Connect.)

---

## Account Deletion URL

`https://tadabbur-jet.vercel.app/delete-account`

(Required by Play Console's Data Safety declaration whenever the app
supports account creation. Page explains how to delete the account
in-app and offers an email-fallback for account removal.)

---

## Graphics required for the listing

Already in `play_store_assets/`:

- ✅ **App icon (512×512 PNG)** — `app_icon_512.png`. Updated with the new design.
- ✅ **Feature graphic (1024×500 PNG)** — `feature_graphic.png`. Just regenerated with "19 languages."
- ⚠️ **Phone screenshots (4–8)** — `screenshots/Image 1.png` through `Image 7.png` exist but are from April 8, predate the new icon, splash, and Tamil/Arabic translations. **Should be re-captured before submission.** Best screens to capture:
  1. Daily ayah hub (with audio button + tier buttons visible)
  2. Reflection writing surface (mid-flow)
  3. Feelings picker
  4. Journal home (heatmap visible)
  5. Journal entry detail
  6. Settings (showing "Names and styles synced from Quran Foundation")
  7. Onboarding language picker (shows the 19-language reach)
- *(Optional)* **Tablet screenshots** — skip unless targeting iPad later. The Play Store doesn't penalize phone-only listings.
- *(Optional)* **Promo video** — skip for first submission. Add post-hackathon if you record a real one.

---

## Track strategy (recommended)

For a hackathon-context first submission, use:

1. **Internal testing** track first — invite yourself + a few testers via Google Group. Confirms signing, Firebase wiring, OAuth deep links work in production.
2. **Closed testing** (open to a small Muslim community list, friends, hackathon judges) — gather real feedback for ~7 days.
3. **Production** track — only after Step 2 surfaces no critical bugs.

For the hackathon submission itself, the **Closed testing track URL** is what you'd put in SUBMISSION.md — judges install from there without you needing to publish to public production.

---

## Release notes for this version (1.8.0+62)

```
First public release.

• 19 languages with full UI translation
• Three-tier reflection system: Acknowledge, Respond, Reflect
• Daily ayah from Al-Fatiha to An-Nas, with audio from 7 reciters
• 1,300+ pre-bundled tafsir summaries for offline reading
• Sign in with Quran Foundation, Google, or stay in Guest mode
• Privacy-first: reflections are private by default
```
