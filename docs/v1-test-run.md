# Sloth V1 — Feature Inventory, Test Run, and Release Handoff

**Build date:** 2026-11-10 · **Package:** `com.whyybhav.sloth` · **Version:** `1.0.0+1` · **Toolchain:** Flutter 3.47.9 stable / Dart 3.13.7 · Android SDK 36 · min API 24 · target API 36

## Source and design review

The supplied `sloth_flutter_app_enhanced (1).zip` contains `pubspec.yaml`, `README.md`, and `lib/main.dart`. It has one Cupertino-style habit screen and its ring, question editor, and reset control, but no Android project, tests, fonts, exported Figma assets, or persistence layer. The linked [Figma Make preview](https://www.figma.com/make/QkxWQOLmYH54OIiCn5zCm2/Design-premium-mobile-app?t=L7Kaen8YeVmgCStX-1) and [shared design conversation](https://chatgpt.com/share/6af2cf3e-2e24-83e8-ad00-60b1e646c9ca) were reviewed. The app retains the single-question circle, top controls, streak, quiet Cupertino layout, and warm background; it implements the described greeting/date, long-press editing, completion, skip, and sloth icon.

## Screens and journeys

| Screen or state | V1 behavior | Verification |
| --- | --- | --- |
| First launch — onboarding | Edit the suggested daily question and start. Empty input uses the default; input is limited to 64 characters. | Widget-tested |
| Home — pending | Shows a time-based greeting, local date, one question in a circular control, and current streak. Tap to complete; long-press to edit. | Widget-tested at four viewport sizes; accessibility-tested |
| Home — completed | The circle fills with sage, animates in a white check, and persists the date and streak. Same-day repeat taps do not double-count. | Widget-tested |
| Home — skipped | **Skip today** records the date and shows a coral X and zero active streak. Undo the skip or mark the habit complete later that day. | Widget-tested; persistence across restart tested |
| Edit question | Available from the top-left control and long-press. Save validates the question; Cancel leaves it unchanged. | Save, cancel, empty validation, and long-press widget-tested |
| Reset confirmation | The top-right control asks before clearing local Sloth data and returning to onboarding. | Confirm and cancel widget-tested |
| Loading and local-storage errors | Reads show a loading indicator and retry action; failed saves/resets report errors without showing false success. | Implemented; platform failure injection is not automated |

## Implemented features

- Single daily habit question with first-run onboarding and edit examples.
- Local persistence for onboarding, question, completion record, and skip date using `shared_preferences`. Completion date and streak are written together; the reader falls back to the separate keys used by the first V1 build.
- Calendar-based streak rules: first completion starts at one, consecutive days increment, a missed day resets on the next completion, and repeat taps on the same day do not increment.
- Daily status refresh when the app resumes and at the next local midnight.
- Sage completion state with checkmark, coral skipped state with X, undo skip, haptic feedback, and spring/color transitions.
- Responsive, scroll-safe layout with a greeting/date, semantic completion and long-press edit actions, and a vector sloth-on-branch launcher icon.
- Android app label **Sloth**, ID `com.whyybhav.sloth`, version `1.0.0+1`, minimum API 24, target API 36.
- Release manifest has no Internet permission. The V1 app makes no network calls and requires no runtime permissions.

## Automated test execution

Commands run from the repository root:

```sh
flutter analyze
flutter test
```

**Result: 30 tests passed; `flutter analyze` reported no issues.**

### Unit tests (11)

- Completion date and streak round-trip together in one saved record.
- Existing completion data from the first V1 build loads through the legacy fallback.
- A malformed completion record falls back to legacy values.
- Morning, afternoon, and evening greeting selection.
- Friendly date includes weekday and month.
- Daily state is pending without a record for today.
- Today’s skip restores as skipped.
- Completion takes precedence over a same-day skip.
- A first completion starts the streak at one.
- Yesterday increments; a missed day resets the streak.
- Same-day completion does not increment twice.

### Widget tests (19)

- Fresh onboarding saves the question and opens home.
- Onboarding remains usable with a reduced keyboard viewport.
- Compact 360×420 home has no overflow.
- Home adapts to 320×568, 390×844, and 600×960 viewports.
- Completion circle exposes its question, tap, and long-press actions to accessibility.
- Completing the habit shows the check state and persists the streak/date.
- Rapid repeated taps record one completion.
- Question editing saves correctly.
- Long-pressing the circle opens the edit sheet.
- System Back dismisses the edit sheet without saving.
- Canceling an edit preserves the saved question.
- Empty edit validation preserves the saved question.
- Skip shows the coral X and survives restart.
- A skipped habit can still be completed later that day.
- Question and completion survive an app restart.
- Home reloads stored state when the app resumes.
- Reset clears progress and returns to onboarding.
- Canceling reset preserves habit and progress.
- Fresh-install primary journey completes through editing and reset.

The onboarding keyboard test uses a 360×640 viewport with a 280 px bottom inset. Tests use Flutter’s shared-preferences mock store; they do not simulate Android process death or platform storage failures.

## Android builds and validation

Built from this source with Flutter 3.47.9:

```sh
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

Both APKs passed `apksigner verify` using APK Signature Scheme v2. The AAB passed `jarsigner -verify` and `unzip -t`; the signature is valid but uses the self-signed debug certificate, which produces the expected trust-chain warnings. The AAB contains its bundle config, manifest, and DEX code.

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `outputs/sloth-v1-debug.apk` | 160,745,470 bytes | `e7f5a99faddb4f1d860a8563aa541a52ea8f28f32b6f6954e84be5930aadb725` |
| `outputs/sloth-v1-release.apk` | 47,667,459 bytes | `f7f8e88a065c5b703e7812e9df71a64c78851d9555ad1f8680c07f2b6b452261` |
| `outputs/sloth-v1-release.aab` | 47,729,558 bytes | `44be3a09cbe9706f2f88f732349c1724fa45df86758f01ec1be68e839779a841` |

`aapt dump badging` confirmed the package, label, version, min/target SDK, and launcher resource. The APKs and AAB use the debug signing key for local testing; they are not production Play uploads.

## Device smoke test handoff

The user chose to run the device/emulator smoke test. It has **not** been performed here. Install the debug build and check:

```sh
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

1. Fresh launch → edit the suggested question → Start.
2. Tap the circle → see sage fill/check and streak increment.
3. Close and relaunch → question, completion, and streak restore.
4. Edit by long-press and by the top-left control; save and cancel.
5. On a fresh day, skip → see coral X; restart; undo skip or complete instead.
6. Reset → confirm, then separately verify Cancel leaves data intact.
7. Use Android system Back while the edit sheet is open and check that it dismisses without saving.

## Known limitations

- Data is local to this installation. There is no account, server, cloud sync, multi-device restore, reminders, analytics, or social sharing.
- One daily question is supported by design. It is limited to 64 characters; the greeting name is currently “Vaibhav.”
- The visual theme is light-only. The app uses Flutter/Cupertino system typography rather than bundling licensed SF Pro font files.
- The archive had no exported Figma assets; the Android launcher mark is a native vector recreation.
- Local-storage error UI is implemented, but shared-preferences failures are not injected in automated tests.
- Emulator/device rendering and interaction remain for the user’s smoke test.
- Release APK/AAB use debug signing. Configure a private production upload key before Play submission.

## Google Play release preparation checklist

- [ ] Create and securely back up a production upload keystore; keep it out of Git.
- [ ] Add local `android/key.properties` and configure release signing in Gradle.
- [ ] Increment the app version before the next release; keep `com.whyybhav.sloth` stable.
- [ ] Confirm app name, launcher icon, supported Android versions, and permissions.
- [ ] Prepare store listing text, screenshots, feature graphic, privacy policy, content rating, and Data safety answers.
- [ ] Upload a production-signed AAB to an internal testing track and install through Play.
- [ ] Review the Play pre-launch report for crashes, ANRs, and device-specific rendering issues.
- [ ] Confirm Play App Signing and keep the upload key separate from the app-signing key.

Do not upload the current debug-signed AAB to a production track.
