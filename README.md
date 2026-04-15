# Airsoft App Foundation

Phase 1A Flutter foundation for the Airsoft app.

## Setup

1. Install Flutter.
2. Run `flutter pub get`.
3. Open `lib/core/config/app_config.local.dart`.
4. Replace the Supabase URL and anon key placeholders.
5. Run the app.

## Commands

```bash
flutter pub get
flutter run
flutter build apk --debug
flutter build apk --release
```

Release APK output:

`build/app/outputs/flutter-apk/app-release.apk`

## Build APK In GitHub

This repository includes a GitHub Actions workflow at [.github/workflows/build-apk.yml](.github/workflows/build-apk.yml).

You can trigger it in two ways:

1. Push to `main` or `clean-main`
2. Run it manually from the Actions tab (`Build Android APK`)

After the workflow finishes, download artifact `airsoft-app-release-apk`.

## Included

- App shell with bottom navigation
- Splash screen
- English/Japanese localization scaffold
- Dark/light theme setup
- Placeholder screens for root tabs
- Profile model and profile/edit screens
- Supabase initialization
