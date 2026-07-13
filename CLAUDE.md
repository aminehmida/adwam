# Workflow

- Always work in a git worktree (via EnterWorktree) when starting a new feature or fixing an issue — never work directly on `main`.
- **Cross-platform rule: the app currently ships on Android, but iOS is planned and other platforms may follow. Do NOT introduce anything platform-specific (Android or otherwise) — in Dart code, plugins, or design decisions — unless the user explicitly allows it for that case.** Platform-specific build/test tooling below (adb, APKs, emulator) is fine; it's the app itself that must stay portable.
- After every change, the user usually wants the release APK installed and launched on his Samsung Galaxy S24 Ultra, verified with a screenshot.
- Tests: only what is useful — no coverage padding.

# App

Adwam (أدوَم) — Flutter adhkar app (currently released on Android; iOS planned). Application ID `dev.amine.adwam`, Dart package `adwam`, repo `aminehmida/adwam` (private). Four sessions (morning, evening, post-prayer, sleep), 56 reviewed adhkar. Tap-to-count with haptics, long-press mark-done, auto-scroll to next incomplete, virtue text behind a "الفضل / Virtue" expander, midnight progress rollover. i18n via gen-l10n (ar/en .arb), RTL in Arabic, language toggle on home page only. Theme: hand-built manuscript palette in `lib/theme.dart` (night-green surfaces, muted gold `#D9A441`, Amiri font).

# Toolchain & environment

- All dev tools (flutter, dart, java) are mise-managed and NOT on PATH in non-interactive shells: run via `mise exec -- <cmd>` (alias `mise x --`), pinned in `mise.toml` (Flutter 3.44.6, temurin-17). A fresh git worktree needs `mise trust` before `mise exec` works in it.
- Android SDK: `/opt/homebrew/share/android-commandlinetools` (brew cask). For sdkmanager/keytool: `export JAVA_HOME="$(mise where java)/Contents/Home"`.
- The Galaxy S24 Ultra drops off USB regularly: usually cable/charge-only mode; diagnose with `system_profiler SPUSBDataType | grep -i samsung`. Two adb binaries exist (brew vs platform-tools) — if they fight, kill and restart the adb server.
- Interrupted `sdkmanager` downloads hang on retry: kill the process and `rm -rf $SDK/.temp` first. A first Gradle build downloads a ~2.8GB NDK and is very slow — run it in background, never start a second build concurrently; if killed mid-download, delete the partial `ndk/<version>` dir.

# Commands (all Flutter/Dart via mise)

- `mise exec -- flutter test` (unit/widget), `mise exec -- flutter analyze`
- `mise exec -- flutter gen-l10n` — rerun before trusting analyze if l10n changed (stale generated files cause phantom errors)
- Release build: `mise exec -- flutter build apk --release --split-per-abi --target-platform android-arm64` → `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Install+launch: `adb install -r <apk> && adb shell monkey -p dev.amine.adwam -c android.intent.category.LAUNCHER 1`
- Screenshot: `adb exec-out screencap -p > file.png`; tap: `adb shell input tap X Y`
- E2E: `mise exec -- flutter test integration_test -d emulator-5554` on AVD `adwam_test`; boot headless with `emulator -avd adwam_test -no-window -no-audio -no-boot-anim -no-snapshot` (emulator bin under `/opt/homebrew/share/android-commandlinetools/emulator/`), poll `adb shell getprop sys.boot_completed`
- Icons: `mise exec -- dart run flutter_launcher_icons` (adaptive layers in `assets/icon/`)

# Releasing on GitHub

- Cut a release by pushing a `v*` tag (`git tag v1.0.1 && git push origin v1.0.1`) — `.github/workflows/release.yml` runs analyze + tests, builds, and publishes a GitHub Release with two APKs: `adwam-<tag>-arm64-v8a.apk` (17MB, any modern phone) and `adwam-<tag>-universal.apk` (46MB, all ABIs). `workflow_dispatch` runs build the artifact only, no Release.
- Versioning: versionName comes from the tag (`v1.2.0` → `1.2.0`); versionCode is `3000 + run_number`, so CI APKs install over local 2xxx builds — a local `--build-number` deploy after installing a CI release must exceed the CI number.
- CI signs with the real upload key via repo secrets `KEYSTORE_BASE64`/`KEYSTORE_PASSWORD`/`KEY_PASSWORD`/`KEY_ALIAS` (from local `android/key.properties` + keystore; re-set with `gh secret set` if the key rotates). Without them it silently falls back to debug signing — verify with `apksigner verify --print-certs` (cert CN=Amine Hmida, OU=Dhikr) if in doubt.
- Workflow gotcha: the `secrets` context is not allowed in a step-level `if` — pass secrets via `env` and guard in bash.
- Warm runs take ~6.5 min (Gradle + pub + Flutter SDK caches); the first run after a cache bust is ~3 min slower.

# Content pipeline

- `tool/build_content.py` merges raw sources in `content/sources/` (Seen-Arabic Morning-And-Evening-Adhkar-DB; hisnmuslim.com API ch. 25 + 28) with the hand-reviewed overlay `content/curation.json` → generates `assets/adhkar.json` (the app's only content asset) and `content/REVIEW.md`.
- `curation.json` is the source of truth for classification (form quran|short|long|surah, repetitions, benefit_tier, sort_hint, benefit_text/_en overrides). Always rerun `python3 tool/build_content.py` after editing it; `test/content_test.dart` validates the generated asset.
- Reading these source JSONs in Python needs `encoding='utf-8-sig'`.

# Sort rules (final, user-approved — one global comparator `compareDhikrs`)

1. Quran passages first; `surah` form (full surahs, shown by name only) pinned last; user-added custom duas (id `custom-*`, added via edit mode, always 1x) pinned after even those, in their own "My duas / أدعيتي" section
2. Benefit tier: exactly 3 tiers — protection → reward → other/none
3. Repetitions ascending
4. Shorter before longer at same count
5. Cluster `sort_hint` (أصبحنا/أمسينا shorts clustered; the three Quls in mushaf order)
6. Word count ascending (lowest priority)

Drag-reorder in edit mode is constrained to the dhikr's own tier section. The user verifies order changes with computed sort-order dumps (`from build_content import default_sort_key`) and gives corrections by dhikr id (e.g. "me-14 is reward").

# Gotchas

- Autoscroll: `ListView.builder` only builds ~250px around the viewport, so `GlobalKey` contexts for far-away items are null — never scroll via a target item's key; step-scroll toward unbuilt items (`_scrollToNextIncomplete` in `lib/screens/session_screen.dart`).
- A bare `Center` in a pinned bottom slot expands to claim all available height and can squeeze the list to nothing.
- Release signing: `android/key.properties` + `android/upload-keystore.jks` are gitignored and local-only; Gradle falls back to debug signing when absent.
- Logo design history and SVG masters live in `logos/` (export/logo.svg; 512px PNG = Play Store icon).
