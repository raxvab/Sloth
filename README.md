# Sloth — Flutter Android V1

Sloth is a quiet, single-habit accountability app. It stores the user's daily habit question and streak locally on the device.

## V1 journey

1. First launch opens **Welcome to Sloth**. The user can change the suggested one-thing question and tap **Start**.
2. The home screen shows that question in the ring and the current day streak.
3. Tapping the ring completes today's habit, animates the ring to green, shows a check badge, and saves the completion date and streak.
4. The top-left control opens **Edit Question**. Save persists the change; Cancel leaves it unchanged.
5. The top-right control asks before resetting. Confirm clears local Sloth data and returns to onboarding.

The supplied archive contained only `pubspec.yaml`, `README.md`, and `lib/main.dart`; it did not include Figma exports, image assets, or Android scaffolding. The current UI preserves the supplied app's Cupertino style, palette, ring, streak, edit and reset concepts. The launcher icon is a simple native vector mark because no source logo was provided.

## Local development

Requirements: Flutter 3.47.9 stable, Android SDK platform 35 or newer, Android build tools, and Java 17 or newer.

```sh
flutter pub get
flutter test
flutter analyze
flutter run
```

## Android builds

```sh
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

Outputs are written under `build/app/outputs/`. The local release APK and AAB currently use Flutter's debug signing config for local testing. They are not signed with a production Google Play upload key.

### Configure a production signing key

1. Generate a private upload key with `keytool` and keep the keystore outside version control.
2. Store its path and passwords in `android/key.properties` (never commit that file or the keystore).
3. Replace the `signingConfigs.debug` reference in `android/app/build.gradle.kts` with a release signing config that reads `key.properties`.
4. Build a new release AAB and retain secure backups of the upload key and credentials.
5. Register the package `com.whyybhav.sloth` in Play Console and configure Play App Signing before uploading.

See `docs/v1-test-run.md` for the executed test list, build artifact validation, V1 feature inventory, and known limitations. See `docs/progress.md` for current release progress and handoff items.
