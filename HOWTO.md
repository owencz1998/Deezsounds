![Alchemy](./assets/banner.png?raw=true)

[![Flutter](https://img.shields.io/badge/Flutter-v3.29.2-blue?logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-v3.7.2-blue?logo=dart)](https://dart.dev/)
[![Android API](https://img.shields.io/badge/Android%20API-35-green?logo=android)](https://developer.android.com/about/versions/14)
[![Java JDK](https://img.shields.io/badge/Java%20JDK-17-blue?logo=openjdk)](https://openjdk.java.net/projects/jdk/17/)
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

To use Alchemy, you'll need API keys from Deezer, Last.fm and ACRCloud:

*   Deezer: [https://developers.deezer.com/myapps](https://developers.deezer.com/myapps) (Required for authentication)
*   LastFm: [https://www.last.fm/fr/api](https://www.last.fm/fr/api) (Required for optional scrobbling)
*   ACR Cloud [https://console.acrcloud.com/](https://console.acrcloud.com/) (Required for optional song or humming recognition)

Create a `.env` file in the `/lib` directory with your API credentials:

```bash
# Deezer GW light API credentials 
deezerClientId = '<Required_Deezer_Client_Id>';
deezerClientSecret = '<Required_Deezer_Client_Secret>';

# Deezer GW API
deezerGatewayAPI = '<Required_Deezer_Gateway_Key>';
deezerMobileKey = '<Required_Deezer_Mobile_Key>';

# LastFM API credentials
lastFmApiKey = '<LastFM_API_Key_Can_Be_Left_Empty>';
lastFmApiSecret = '<LastFM_API_Secret_Can_Be_Left_Empty>';

# ACRCloud's API Key
acrcloudHost = '<ACRCloud_host_address>'; # eg. "identify-eu-west-1.acrcloud.com"
acrcloudSongApiKey = '<ACRCloud_Song_Recognition_API_Key_Can_Be_Left_Empty>';
acrcloudSongApiSecret = '<ACRCloud_Song_Recognition_API_Secret_Can_Be_Left_Empty>';
acrcloudHumsApiKey = '<ACRCloud_Humming_Recognition_API_Key_Can_Be_Left_Empty>';
acrcloudHumsApiSecret = '<ACRCloud_Humming_Recognition_API_Secret_Can_Be_Left_Empty>';

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