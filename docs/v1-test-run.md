# Sloth V1 — Figma Flow, Features, and Test Run

**Build date:** 2026-11-10

**Source:** `raxvab/Sloth` working copy plus the supplied `sloth_flutter_app_enhanced (1).zip`

**Package:** `com.whyybhav.sloth` · **Version:** `1.0.0+1`

## Design flow represented

The shared design conversation describes the Sloth screen as a minimal, Apple-inspired single-habit app with a question, a large circular completion ring, green completion check, day streak, an edit control, and a reset/logout control. The supplied archive did not include Figma exports, screenshots, fonts, or logo assets, so the build retains the existing UI and uses a small native vector launcher mark.

Figma Make link referenced in the shared conversation: [Design premium mobile app](https://www.figma.com/make/QkxWQOLmYH54OIiCn5zCm2/Design-premium-mobile-app?t=L7Kaen8YeVmgCStX-1).

## 1.0 screens and user journeys

| Screen / flow | V1 behavior | Status |
| --- | --- | --- |
| First launch — onboarding | Suggested question is editable; Start saves it and opens the habit screen. Empty input falls back to the suggested question. | Implemented; widget-tested |
| Daily habit — home | Shows the current question, a yellow ring, and day streak. Tapping completes the day, animates the ring green, shows a check badge, and persists the date and streak. | Implemented; widget-tested |
| Edit question | Header control opens an edit sheet. Save persists a non-empty replacement; blank input preserves the existing question; Cancel dismisses without saving. | Implemented; save path widget-tested |
| Reset local data | Header control asks for confirmation. Reset clears question, onboarding state, and streak, then returns to onboarding. Cancel leaves data in place. | Implemented; confirm path widget-tested |

## Feature inventory

- One daily habit question, initially “Did I walk today?”
- Persistent onboarding state, question, streak count, and last completion date using `shared_preferences`.
- Loading indicators and retry UI for saved-state reads; save/reset failures leave the UI honest and show an error instead of claiming success.
- Daily completion state restored when the app starts again.
- Haptic feedback and spring-style ring completion animation.
- Streak increments only for consecutive calendar days, does not increment twice on one day, and restarts at one after a missed day.
- Accessible semantic label for the ring completion action.
- Native Android app name **Sloth**, application ID `com.whyybhav.sloth`, version `1.0.0+1`, and vector launcher mark.

## Automated test run

Commands executed from the repository root:

```sh
flutter test
flutter analyze
```

**Result: 13 tests passed; static analysis reported no issues.** The suite includes 3 unit tests and 10 widget tests.

| Test | Result |
| --- | --- |
| Empty history starts streak at one | PASS |
| Yesterday increments streak; a missed day resets it | PASS |
| Same-day completion does not increment twice | PASS |
| Onboarding saves the chosen question and opens home | PASS |
| Onboarding remains usable with a reduced keyboard viewport | PASS |
| Habit home fits a compact Android viewport without overflow | PASS |
| Completing the habit shows completion state and persists streak/date | PASS |
| Rapid repeated taps record one completion | PASS |
| Editing the question saves the change | PASS |
| Canceling edit preserves the existing question | PASS |
| Empty edit input is rejected and preserves the saved question | PASS |
| Question and completion restore after an app restart | PASS |
| Reset confirmation clears local data and returns to onboarding | PASS |

## Android artifacts

Commands executed:

```sh
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

All three builds completed with Flutter 3.47.9 / Dart 3.13.7. APK signatures verify with Android `apksigner`; the AAB signature verifies with `jarsigner`, and its ZIP structure contains `BundleConfig.pb`, the Android manifest, and compiled DEX code.

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `sloth-v1-debug.apk` | 160,735,697 bytes | `1ed90e3f42149121208ceac51b82a4b828252b5d5efe7055b48d1c89a8085ef4` |
| `sloth-v1-release.apk` | 47,606,420 bytes | `0701a9d4d4483adc06a510745f6d0bce8f5b2b7d735a50bbb54d3f9b641e3702` |
| `sloth-v1-release.aab` | 47,594,930 bytes | `63de46962288eb6ff45b04eef9896f1ee669816b20cf36b1459175f0b169c436` |

The local release APK and AAB use the debug signing key, as requested for local testing. They are not signed with a production Google Play upload key. Follow the README signing instructions before publishing.

## Google Play release preparation checklist

- [ ] Create and securely back up a production upload keystore; do not put it in Git.
- [ ] Add local `android/key.properties` and configure the release signing block to use the production upload key.
- [ ] Increment `version` in `pubspec.yaml` before the next release; keep application ID `com.whyybhav.sloth` stable.
- [ ] Confirm the final app name, launcher icon, supported Android versions, and requested permissions.
- [ ] Prepare store listing text, screenshots, feature graphic, privacy policy, content rating, and Data safety answers.
- [ ] Test the production-signed AAB in Play Console's internal testing track before broader rollout.
- [ ] Review Play Console pre-launch report and crash/ANR results; resolve blockers before production rollout.
- [ ] Enable/confirm Play App Signing and retain the upload key separately from the app-signing key.

Do not upload the current debug-signed AAB to a production track.

## Smoke test and known limitations

- **Emulator smoke test:** not performed here; the user asked to run this test themselves. Install `sloth-v1-debug.apk`, then verify first launch, editing and starting a habit, ring completion, restart persistence, edit/save, reset confirmation, and back navigation.
- **Storage is local to this installation.** There is no account service, cloud sync, cross-device restore, or server-side authentication. The reset action clears this device's Sloth preferences.
- **Single habit only.** Multiple habits, schedules, reminders, analytics, and social sharing are outside the supplied V1 design/code.
- **Visual comparison is limited** because the supplied ZIP has no Figma screenshots or image assets. The referenced Figma link is included above for manual review.
- The launcher mark is a vector approximation because no Sloth logo file was supplied.
- Storage-failure UI is implemented, but automated tests do not currently inject a failing `shared_preferences` platform call.
