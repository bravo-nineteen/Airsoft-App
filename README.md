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

## Social Login Setup (Google and Facebook)

The app now supports social sign-in via Supabase OAuth.

### 1) Supabase Dashboard

1. Go to Authentication -> Providers and enable Google + Facebook.
2. Add each provider's client ID and client secret.
3. Add this mobile redirect URL in Authentication -> URL Configuration -> Additional Redirect URLs:
	- fieldops://login-callback
4. Set Site URL (or additional redirect) to include Supabase callback:
	- https://yznlhjopcqjbsweohptb.supabase.co/auth/v1/callback

Social login will not work unless both provider credentials and redirect URLs are configured in Supabase.

### 2) Google Cloud (What you need)

1. OAuth Client ID
2. OAuth Client Secret
3. Android package name:
	- com.airsoftonlinejapan.fieldops
4. Android SHA-1 signing fingerprint (debug):
	- 94:9B:CC:26:B7:01:00:3E:09:F4:08:35:7C:CC:FB:C9:38:E1:CE:D5
5. Authorized redirect URI set to:
	- https://yznlhjopcqjbsweohptb.supabase.co/auth/v1/callback

### 3) Facebook Developers (What you need)

1. Facebook App ID
2. Facebook App Secret
3. In Facebook Login settings, set Valid OAuth Redirect URI to:
	- https://yznlhjopcqjbsweohptb.supabase.co/auth/v1/callback
4. In App Settings -> Basic -> App Domains, add every domain/subdomain used by auth flow, including:
	- yznlhjopcqjbsweohptb.supabase.co
	- your production app domain (and any subdomains)
	- your staging/test app domains (and any subdomains)
5. Android package name:
	- com.airsoftonlinejapan.fieldops
6. Android activity class name:
	- com.airsoftonlinejapan.fieldops.MainActivity
7. App redirect URI used by this app:
	- fieldops://login-callback

### 4) Android callback wiring in this project

Android deep link callback is configured in [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) using:
- scheme: fieldops
- host: login-callback

### 5) iOS note

This workspace currently does not include ios/Runner/Info.plist, so iOS URL scheme setup cannot be committed here yet.
When the full iOS runner files are present, add URL scheme fieldops so the same redirect works on iOS.
