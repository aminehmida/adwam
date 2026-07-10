# Dhikr — أذكار اليوم والليلة

Offline daily adhkar app (Flutter, Android). Four sessions — morning, evening,
post-prayer, before-sleep — with a principled default ordering and full
per-session customization.

## Default ordering

Within each session:

1. **Quran passages** always first
2. **Benefit tier** from the virtue hadith: protection → reward → none
   (a long reward dua outranks every no-benefit dhikr)
3. **Repetition count** ascending (1, 3, 4, 7, 10, … 100)
4. **Form**: short before long, breaking ties at the same count
5. Curated `sort_hint` for manual fine ordering (e.g. the أصبحنا cluster)

Drag-to-reorder and hide (collapse-in-place) override the defaults per session;
"reset to default order" brings them back.

## Content

55 adhkar compiled by `tool/build_content.py` into `assets/adhkar.json` from:

- [Seen-Arabic Morning-And-Evening-Adhkar-DB](https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB) (MIT) — morning/evening, incl. virtue text + hadith sources
- [hisnmuslim.com API](http://www.hisnmuslim.com) — post-prayer (ch. 25) and sleep (ch. 28)

Form and benefit-tier classification lives in `content/curation.json`
(drafted by Claude, human-reviewed — see `content/REVIEW.md`). To change
content or classification, edit those inputs and rerun the script.

## Development

Toolchain is pinned via [mise](https://mise.jdx.dev) (`mise.toml`: Java 17,
Flutter). Android SDK via `brew install --cask android-commandlinetools`
(`sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"`).

```sh
flutter pub get
flutter test          # sort logic, daily rollover, counting flow
flutter run           # on a USB device
flutter build apk --release --split-per-abi
```

Daily progress persists via shared_preferences and resets at local midnight
(date-stamp comparison — no timers).
