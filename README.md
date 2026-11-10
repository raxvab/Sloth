# Sloth — Flutter Android V1

**Slow down. Do one thing. Keep going.**

Sloth is a calm, single-habit accountability app. Choose one daily question, record whether you completed or skipped it, and keep a local streak. It follows the supplied Cupertino-style Sloth screen and runs offline.

## V1 experience

- First launch asks for one habit question. The 64-character field starts with “Did I walk today?” and can be changed before starting.
- The home screen shows a time-based greeting, today’s date, the question in a large circular control, and the active streak.
- Tap the circle to complete today. It fills with muted sage, animates a white checkmark, gives haptic feedback, and saves the completion date and streak.
- Use **Skip today** to record a skip in coral with an X. The skip persists across restarts; it can be undone or replaced with a completion later that day.
- Long-press the circle or use the top-left control to edit the question. The top-right control confirms before clearing local data.
- The Sloth launcher mark is a native vector drawing of a sloth hanging from a branch.

## Data and privacy

The question, completion date, skip date, and streak are stored locally with `shared_preferences`. The release manifest has no Internet permission and the app makes no network calls. There is no account, cloud sync, multi-device restore, reminder service, or server-side authentication.

## Requirements

- Flutter 3.47.9 stable / Dart 3.13.7 (or a compatible later stable release)
- Android SDK 36 and Java 17 or newer
- Android API 24 or newer

## Run and verify

From the project root:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The widget suite checks onboarding, the complete primary journey, persistence, skip and completion states, editing, reset confirmation, lifecycle refresh, accessibility actions, keyboard handling, and narrow, standard, and wide layouts.

## Build and install Android

```sh
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Build outputs are written under `build/app/outputs/`. Refreshed V1 APKs and the AAB are delivered in the workspace `outputs/` directory. `docs/v1-test-run.md` records the executed tests, build validation, feature inventory, smoke-test handoff, and Play checklist.

The release APK and AAB currently use Flutter’s debug signing configuration for local testing. They are **not** signed with a production Google Play upload key.

### Configure a production signing key

1. Generate a private upload key with `keytool` and keep the keystore outside version control.
2. Store its path and passwords in local `android/key.properties`; never commit that file or the keystore.
3. Replace `signingConfigs.debug` in `android/app/build.gradle.kts` with a release signing config that reads `key.properties`.
4. Build and validate a new release AAB; securely back up the upload key and credentials.
5. Register `com.whyybhav.sloth` in Play Console and configure Play App Signing.

See `docs/progress.md` for the current handoff and `docs/v1-test-run.md` for known limitations and release preparation.
