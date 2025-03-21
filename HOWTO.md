![Alchemy](./assets/banner.png?raw=true)

[![Flutter Version](https://shields.io/badge/Flutter-v3.29.2-darkgreen.svg)](https://docs.flutter.dev/tools/sdk)
[![Dart Version](https://shields.io/badge/Dart-v3.7.2-darkgreen.svg)](https://dart.dev/get-dart)
[![License](https://img.shields.io/github/license/PetitPrinc3/Deezer?flat)](./LICENSE)

---

> [!IMPORTANT]
> This page aims at providing compilation steps for Alchemy.
> By compiling and using this app, you have read and understood the [legal](./README.md#balance_scale-disclaimer--legal) section of the Alchemy project.
> You take full responsibility for using the app according to the aforementioned disclaimer.

# :hammer_and_wrench: Getting Started: Compilation Guide

> [!TIP]
> While individual commits should compile and produce working APKs, it is highly recommended to use releases.
> To download the latest release, visit [latest](https://github.com/PetitPrinc3/Alchemy/releases/latest)

## Prerequisites

Before you begin, ensure you have the following installed:

*   Flutter: v3.7.2 ([Flutter SDK](https://docs.flutter.dev/tools/sdk))
*   Dart: v3.29.2 ([Dart SDK](https://dart.dev/get-dart))

Alchemy relies on several custom Git submodules. Clone these repositories and their dependencies:

You will need to obtain the specified Git modules:

*   @DJDoubleD's [custom\_navigator](https://github.com/DJDoubleD/custom_navigator)
*   @DJDoubleD's [external\_path](https://github.com/DJDoubleD/external_path)
*   @DJDoubleD's [marquee](https://github.com/DJDoubleD/marquee)
*   @DJDoubleD's [move\_to\_background](https://github.com/DJDoubleD/move_to_background)
*   @DJDoubleD's [scrobblenaut](https://github.com/DJDoubleD/Scrobblenaut)
*   @SedlarDavid's [figma\_squircle](https://github.com/SedlarDavid/figma_squircle)
*   @mufassalhussain's [open\_filex](https://github.com/mufassalhussain/open_filex)
*   My [liquid\_progress\_indicator\_v2](https://github.com/PetitPrinc3/liquid_progress_indicator_v2)

For each submodule, navigate to its directory and run:

```powershell
flutter pub get
flutter pub upgrade
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
flutter clean
```

> [!TIP]
> All of this can be achieved by using the provided script:
> ```powershell -ep bypass -c .\run_build_runner.ps1```

## Providing API Keys

To use Alchemy, you'll need API keys from Deezer and Last.fm:

*   Deezer: [https://developers.deezer.com/myapps](https://developers.deezer.com/myapps) (Required for authentication)
*   LastFm: [https://www.last.fm/fr/api](https://www.last.fm/fr/api) (Required for optional scrobbling)

Create a `.env` file in the `/lib` directory with your API credentials:

```bash
deezerClientId = '<Your_Deezer_Client_Id>';
deezerClientSecret = '<Your_Deezer_Client_Secret>';

lastFmApiKey = '<Your_LastFM_API_Key>';
lastFmApiSecret = '<Your_LastFM_API_Secret>';
```

## Creating Signing Keys

Generate signing keys for your release build using Java's `keytool`:

```powershell
keytool -genkey -v -keystore ./keys.jks -keyalg RSA -keysize 2048 -validity 10000 -alias <YourKeyAlias>
```

Move `keys.jks` to `android/app` and create `android/key.properties`:

```dart
storePassword=<storePassword>
keyPassword=<keyPassword>
keyAlias=<keyAlias>
storeFile=keys.jks
```

## Building the App

Finally, build the release APK:

```bash
flutter build apk --split-per-abi --release
```

The produced APK will be under `build/app/outputs/flutter-apk`.

Don't forget to star this repo!