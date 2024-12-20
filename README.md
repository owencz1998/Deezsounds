![Deezer](./assets/banner.png?raw=true)

[![Latest Version](https://img.shields.io/github/v/release/PetitPrinc3/Deezer?color=blue)](../../releases/latest)
[![Release date](https://img.shields.io/github/release-date/PetitPrinc3/Deezer)](../../releases/latest)
[![Downloads NotDeezer](https://img.shields.io/github/downloads/PetitPrinc3/Deezer/total?color=blue&label=NotDeezer%20downloads)](../../releases)
[![Downloads Refreezer](https://img.shields.io/github/downloads/DJDoubleD/ReFreezer/total?color=blue&label=ReFreezer%20downloads)](../../releases)
[![Flutter Version](https://shields.io/badge/Flutter-v3.27.1-darkgreen.svg)](https://docs.flutter.dev/tools/sdk)
[![Dart Version](https://shields.io/badge/Dart-v3.6.0-darkgreen.svg)](https://dart.dev/get-dart)
[![Crowdin](https://badges.crowdin.net/refreezer/localized.svg)](https://crowdin.com/project/refreezer)
[![License](https://img.shields.io/github/license/PetitPrinc3/Deezer?flat)](./LICENSE)

[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Java](https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)](https://www.java.com/)

---

This is definitely not Deezer.  
This is an app that uses both public and internal Deezer APIs to provide similar features.  

This repository originates from [ReFreezer](https://github.com/DJDoubleD/ReFreezer) by @DJDoubleD.  

>[!CAUTION]
> Providing this app is illegal.  
> I will only maintain this app for a short period of time because of my personal lyability.

>[!NOTE]
> I am looking for contributors, feel free to reach out !  
> :mailbox: [e-mail me](mailto:gavrochebackups@gmail.com)  
> :space_invader: [Discord : @petitprinc3#1380](https://discordapp.com/users/PetitPrince#1380)

## :camera_flash: Screenshots

<p align="center">
    <img src="./assets/screenshots/Mod_login.png" width=100>
    <img src="./assets/screenshots/Mod_home.png" width=100>
    <img src="./assets/screenshots/Mod_player.png" width=100>
    <img src="./assets/screenshots/Mod_search.png" width=100>
    <img src="./assets/screenshots/Mod_favorites.png" width=100>
    <img src="./assets/screenshots/Mod_playlists.png" width=100>
    <img src="./assets/screenshots/Mod_artists.png" width=100>
    <img src="./assets/screenshots/Mod_menu.png" width=100>
</p>
<p align="center">
    <img src="./assets/screenshots/landscape_artist.png" height=150>
    <img src="./assets/screenshots/landscape_playlist.png" height=150>
</p>

## :star2: Features & changes

#### :lady_beetle: Bugs
- If queue is cleared and player bar is dismissed, it will not be brought back up if the user clicks back on the formerly playing track.
- Lyrics are re-fetched from api each time the player is brought back. This is because the API does not include informations regarding the lyrics in the track model.
- Player bar does not always update its color on track tile tap or various other scenarios.
- Favorite tracks playlist id is not properly saved (no/minor UX consequences).
- Queue screen is laggy. This seems to be because of how the images are loaded.
- Tracks removed from playlist/favorites will not disappear immediately from the detailed screen.

#### :building_construction: Upcoming features
- Caching information to avoid reloading every time (eg. favorites screen)
- Turn the mod into a skin for the official refreezer app
- Deezer "playing" animation instead of highlight

#### :rocket: Definitely Not Deezer Features :
- Floating player bar with background color based on title artwork
- Deezer original icons
- Deezer font
- Deezer original navigation menu (+ settings)
- Deezer like player screen
- Deezer like info menu
- Deezer like favorite screen (Offline : offline playlists and random offline tracks)
- Most deezer pages (artists, playlists, albums)
- Downloads are stored within the app storage (Android/data/package) and can be exported to local storage under settings with full tags
- Fixed lyrics support

#### :rocket: [ReFreezer Features](https://github.com/DJDoubleD/refreezer)

## :pick: Compile from source

Follow the steps from [@DJDoubleD](https://github.com/DJDoubleD/refreezer).

## :balance_scale: Disclaimer & Legal

**Definitely not Deezer** was not developed for piracy, but educational and private use.
It may be illegal to use this in your country!
You are responsible for how you use **Definitely not Deezer**.

**Definitely not Deezer** uses both Deezer's public and internal API's, but is not endorsed, certified or otherwise approved in any way by Deezer.

The Deezer brand and name is the registered trademark of its respective owner.

**Definitely not Deezer** has no partnership, sponsorship or endorsement with Deezer.

By using **Definitely not Deezer** you do not abide by Deezer's [CGU](https://www.deezer.com/legal/cgu>)
