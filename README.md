![Deezer](./assets/banner.png?raw=true)

[![Latest Version](https://img.shields.io/github/v/release/PetitPrinc3/Deezer?color=blue)](../../releases/latest)
[![Release date](https://img.shields.io/github/release-date/PetitPrinc3/Deezer)](../../releases/latest)
[![Downloads Original](https://img.shields.io/github/downloads/DJDoubleD/ReFreezer/total?color=blue&label=ReFreezer%20downloads)](../../releases)
[![Downloads MOD](https://img.shields.io/github/downloads/PetitPrinc3/Deezer/total?color=blue&label=MOD%20downloads)](../../releases)
[![Flutter Version](https://shields.io/badge/Flutter-v3.24.4-darkgreen.svg)](https://docs.flutter.dev/tools/sdk)
[![Dart Version](https://shields.io/badge/Dart-v3.5.4-darkgreen.svg)](https://dart.dev/get-dart)
[![Crowdin](https://badges.crowdin.net/refreezer/localized.svg)](https://crowdin.com/project/refreezer)
[![License](https://img.shields.io/github/license/PetitPrinc3/Deezer?flat)](./LICENSE)

[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Java](https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)](https://www.java.com/)

---

This repo is a MOD of the [ReFreezer](https://github.com/DJDoubleD/ReFreezer) app by @DJDoubleD.  
My goal is to have a style closer to Deezer's original app.
To apply the Deezer theme, select it under Settings > Appearance > Theme.

> I am looking for contributors, feel free to reach out !  
> :mailbox: [e-mail me](mailto:gavrochebackups@gmail.com)  
> :space_invader: [Discord : @petitprinc3#1380](https://discordapp.com/users/PetitPrince#1380)

## Screenshots

<p align="center">
    <img src="./assets/screenshots/Mod_home.png" width=100>
    <img src="./assets/screenshots/Mod_player.png" width=100>
    <img src="./assets/screenshots/Mod_search.png" width=100>
    <img src="./assets/screenshots/Mod_favorites.png" width=100>
    <img src="./assets/screenshots/Mod_playlists.png" width=100>
    <img src="./assets/screenshots/Mod_artists.png" width=100>
    <img src="./assets/screenshots/Mod_menu.png" width=100>
</p>

<details><summary><b>Original ReFreezer App</b></summary>
<p align="center">
    <img src="./assets/screenshots/Login.jpg" width=150>
    <img src="./assets/screenshots/Home.jpg" width=150>
    <img src="./assets/screenshots/Player.jpg" width=150>
    <img src="./assets/screenshots/Lyrics.jpg" width=150>
    <img src="./assets/screenshots/Search.jpg" width=150>
    <img src="./assets/screenshots/SearchResults.jpg" width=150>
    <img src="./assets/screenshots/Library.jpg" width=150>
    <img src="./assets/screenshots/DownloadRunning.jpg" width=150>
    <img src="./assets/screenshots/DownloadFinished.jpg" width=150>
    <img src="./assets/screenshots/PlayerHorizontal.jpg" height=150>
</p>
</details>
<details><summary><b>Android Auto</b></summary>
  <p align="center">
    <img src="./assets/screenshots/Android_Auto-Head_Unit-home.png" max-height=400>
    <img src="./assets/screenshots/Android_Auto-Head_Unit-more.png" max-height=400>
    <img src="./assets/screenshots/Android_Auto-Head_Unit-play.png" max-height=400>
    <img src="./assets/screenshots/Android_Auto-Head_Unit-wide-playing.png" max-height=400>
  </p>
</details>

## Features & changes

### :lady_beetle: Bugs
- Menu doesn't close when track is added/removed from playlist (wrong navigation context ?)

### :building_construction: Upcoming features
- Merge offline tracks and online tracks under tracks (same for playlists, albums, etc.)
- Caching information to avoid reloading every time (eg. favorites screen)
- Dynamic padding when player_bar is up
- Responsive layout for screens
- Re-think the offline/download scheme. Currently :
  - Offline = downloaded "within" the app and accessible ofline through the app only
  - Download = donwloaded to local storage and accessible as such, but not accessible through the app in offline mode

### :rocket: MOD Features :
- Floating player bar with background color based on title artwork
- Deezer original icons
- Deezer font
- Deezer original navigation menu (+ settings)
- Deezer like player screen
- Deezer like info menu
- Deezer like favorite screen (Offline : offline playlists and random offline tracks)
- Most deezer pages (artists, playlists, albums)

### :rocket: ReFreezer Features :
- Restored all features of the old Freezer app, most notably:
  - Restored all login options
  - Restored Highest quality streaming and download options (premium account required, free accounts limited to MP3 128kbps)
- Support downloading to external storage (sdcard) for android 11 and up
- Restored homescreen and added new Flow & Mood smart playlist options
- Fixed Log-out (no need for restart anymore)
- Improved/fixed queue screen and queue handling (shuffle & rearranging)
- Updated lyrics screen to also support unsynced lyrics
- Some minor UI changes to better accomadate horizontal/tablet view
- Updated entire codebase to fully support latest flutter & dart SDK versions
- Updated to gradle version 8.5.1
- Removed included c libraries (openssl & opencrypto) and replaced them with custom native java implementation
- Replaced the included decryptor-jni c library with a custom native java implementation
- Implemented null-safety
- Removed the need of custom just_audio & audio_service plugin versions & refactored source code to use the latest version of the official plugins
- Multiple other fixes

## Compile from source

Follow the steps from [@DJDoubleD](https://github.com/DJDoubleD/refreezer).

## Disclaimer & Legal

**ReFreezer** was not developed for piracy, but educational and private usage.
It may be illegal to use this in your country!
I will not be responsible for how you use **ReFreezer**.

**ReFreezer** uses both Deezer's public and internal API's, but is not endorsed, certified or otherwise approved in any way by Deezer.

The Deezer brand and name is the registered trademark of its respective owner.

**ReFreezer** has no partnership, sponsorship or endorsement with Deezer.

By using **ReFreezer** you agree to the following: <https://www.deezer.com/legal/cgu>
