# Baraka30

Baraka30 is a Ramadan-focused Quran companion app built with Flutter.
It is designed for two groups:

1. People who are struggling to read Quran consistently and need structure.
2. People who can read well but do not have a clear daily plan.

The app helps both groups build a simple, repeatable routine with progress tracking, prayer-time awareness, dhikr support, and guided Quran reading.

---

## Who this app is for

### 1) Beginner or inconsistent reader
Use Baraka30 if you are asking:
- “Where do I start?”
- “How much should I read today?”
- “How do I keep going every day?”

Baraka30 gives you:
- a daily target,
- a monthly target,
- a checklist you can mark manually,
- and a safe “Go to Reading” return button if you accidentally move away from your reading page.

### 2) Good reader but no plan
Use Baraka30 if you can read Quran well but want:
- clear Ramadan completion goals,
- page-based tracking,
- and accountability without over-complication.

---

## Main functionality

## Home page
- Prayer timing section (12-hour format with AM/PM).
- Daily inspiration cards:
  - Ayah of the Day,
  - Dua of the Day,
  - Hadith of the Day.
- Daily checklist (manual checkboxes, not auto-checked by page reading).
- Language-aware content for supported app languages.

## Quran page
- Mushaf-style page reading (604 pages).
- Default first-time open in Reading Mode (translation hidden by default).
- Optional translation mode and translation language picker.
- Verse interactions:
  - play verse audio,
  - highlight/unhighlight,
  - show translation,
  - continuous playback.
- Continuous playback can auto-move to the page of the currently playing verse.
- Bookmark support:
  - save/remove bookmark,
  - jump to bookmark.
- Navigation tools:
  - go to page,
  - Surah index drawer.
- Progress bars:
  - Daily,
  - Ramadan (monthly),
  - Mushaf position.
- Safety return flow:
  - If user jumps/swipes away from reading page accidentally,
  - “Go to Reading” action appears in the Daily progress row,
  - user can return in one tap.

## Planner page
- Set Quran completion goal (number of rounds in Ramadan).
- Automatically calculates:
  - daily pages target,
  - monthly target,
  - per-prayer reading split.
- Shows daily and monthly progress against your selected goal.

## Dhikr page
- Tap-based tasbih counter.
- Supports multiple dhikr options.
- Optional vibration feedback.
- Quick reset flow.

## Offline downloads page
- Download translation files by Surah, Juz, or all Surahs.
- Download recitation audio.
- Set preferred offline translation/reciter.
- Toggle using downloaded translation/audio when available.

---

## Progress behavior (important)

- Daily progress resets automatically at calendar day change.
- Monthly progress resets automatically when calendar month changes.
- Checklist items are manual so prayer tracking stays honest.
- Read pages are tracked uniquely (revisiting same page does not inflate count).

---

## Language and translation support

The app has in-app language support and localized UI text.

For maintainers/translators, Baraka30 includes a hybrid translation workflow:
- machine translation draft + manual review.

Files:
- `assets/i18n/translation_workbench.csv`
- `assets/i18n/translation_workbench.json`
- `assets/i18n/README.md`
- `tool/export_i18n_workbench.dart`

Regenerate translation workbench:

`dart run tool/export_i18n_workbench.dart`

---

## Recommended usage path

### If you are a beginner
1. Open Planner page and choose 1 round (or your comfortable goal).
2. Open Quran page and read from Reading Mode.
3. Watch Daily progress bar and complete your target pages.
4. Use Home checklist to manually confirm prayer + worship routine.

### If you are already fluent
1. Set a higher rounds goal in Planner.
2. Use Quran page bookmark and page search for efficient flow.
3. Use continuous playback for revision/listening sessions.
4. Use “Go to Reading” if navigation is interrupted.

---

## Why Baraka30 helps

- It removes the “Where do I start?” problem.
- It separates planning from execution.
- It supports consistency more than intensity.
- It is useful for both weak-routine and strong-reading users.

---

## Development

### Run
1. Install Flutter SDK.
2. From project root:

`flutter pub get`

`flutter run`

### Test

`flutter test`

---

May Allah place barakah in your reading, understanding, and consistency.
