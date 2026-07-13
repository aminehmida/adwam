<p align="center">
  <img src="logos/export/logo-512.png" alt="Adwam logo" width="160"/>
</p>

# Adwam (أدوَم) — أذكار اليوم والليلة

> «أحبُّ الأعمالِ إلى الله أدومُها وإن قلّ»

The most beloved deeds to Allah are the most lasting, even if small. The app is named after this hadith and built around it: a simple, fully offline app for the daily adhkar of the Prophet ﷺ, covering morning, evening, after prayer, and before sleep.

## Download

Grab the APK from the **[latest release](https://github.com/aminehmida/adwam/releases/latest)**:

- `adwam-<version>-arm64-v8a.apk` — for any modern Android phone
- `adwam-<version>-universal.apk` — larger; for older or unusual devices

Past versions are on the [releases page](https://github.com/aminehmida/adwam/releases).

## Ordering

All of the Prophet's adhkar are beneficial, but on a busy day you may not get through the whole session. Adwam orders each session so that the time you do have counts:

1. Adhkar whose virtue is protection come first, so you are covered as early as possible.
2. Short adhkar with large promised rewards come before longer ones, so more good deeds are earned early in the session.
3. If you only have a couple of minutes, you have still done the most important part. If you have more time, keep going down the list.

The order also keeps related adhkar next to each other, which makes the session easier to memorize over time.

## Stopping and picking up

When you return to a session, the adhkar you already completed are collapsed, so the remaining ones are easy to see. Progress resets at midnight.

## Counting

- Tap a dhikr to count one repetition, with haptic feedback.
- The volume-down button also counts, so you can keep going without touching the screen.
- The list scrolls to the next unfinished dhikr automatically.
- Long-press to mark a dhikr as done.
- Each dhikr has a "الفضل / Virtue" expander showing the hadith about its reward.

## Customization

- Drag adhkar to reorder them however you prefer.
- Hide adhkar you don't need, for example to focus on memorizing a subset, and unhide them later.
- One tap restores the default order.

## Languages

Arabic and English interface, with right-to-left layout in Arabic. The adhkar themselves are always in Arabic.

## Installing on Android

The app is not on an app store yet. To install it, download the APK from the
[latest release](https://github.com/aminehmida/adwam/releases/latest) and open
it on your phone. Android will ask you to allow installing apps from unknown
sources the first time. Pick `adwam-<version>-arm64-v8a.apk` for most modern
phones, or `adwam-<version>-universal.apk` if the first one doesn't install.

## What's next

Features under consideration:

- More adhkar categories
- More interface and translation/transliteration languages
- iOS support
- Releasing on Google Play and the Apple App Store, and potentially other open stores

## Content

55 adhkar, hand-reviewed, sourced from the [Seen-Arabic Morning-And-Evening-Adhkar-DB](https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB) (MIT) and the [hisnmuslim.com](http://www.hisnmuslim.com) collection (Hisn al-Muslim).

## Development

Flutter app (currently on Android; iOS planned). Toolchain pinned via [mise](https://mise.jdx.dev).

The code was written using [Claude Code](https://claude.com/claude-code), and reviewed and tested manually.

PRs, bug reports, and ideas are welcome.

```sh
flutter pub get
flutter test
flutter run
```
