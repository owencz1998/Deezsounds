import 'dart:math';

import 'package:deezer/ui/cached_image.dart';
import 'package:deezer/ui/downloads_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:deezer/fonts/alchemy_icons.dart';
import 'package:deezer/main.dart';
import 'package:deezer/ui/details_screens.dart';
import 'package:deezer/ui/library.dart';
import 'package:deezer/ui/menu.dart';
import 'package:deezer/ui/tiles.dart';
import 'package:deezer/utils/connectivity.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../settings.dart';
import '../translations.i18n.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  String offlineTrackCount = '0';
  String favoriteArtists = '0';
  String favoriteAlbums = '0';

  List<Playlist>? _playlists;

  Playlist? favoritesPlaylist;
  bool _loading = false;

  List<Track> tracks = [];
  List<Track> allTracks = [];
  List<Track> randomTracks = [];
  int? trackCount;

  //Get 3 random favorite titles
  void selectRandom3(List<Track> trackList) {
    if (trackList.isEmpty) {
      setState(() {
        randomTracks = [];
        cache.favoriteTracks = [];
      });
      return;
    }
    List<Track> tcopy = List.from(trackList);
    tcopy.shuffle(); // More efficient shuffling
    setState(() {
      randomTracks = tcopy.take(min(trackList.length, 3)).toList();
      cache.favoriteTracks = randomTracks;
    });
  }

  void _makeFavorite() {
    for (final track in tracks) {
      track.favorite = true;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Load cached playlist and tracks (initial fast load)
    if (cache.favoritePlaylists.isNotEmpty &&
        cache.favoritePlaylists[0].id != null) {
      setState(() {
        _playlists = cache.favoritePlaylists;
      });
    }
    if (cache.favoriteTracks.isNotEmpty) {
      selectRandom3(cache.favoriteTracks);
    }

    // Load offline and online data concurrently
    final isOnline = await isConnected();
    final favPlaylistFuture =
        downloadManager.getOfflinePlaylist(cache.favoritesPlaylistId);
    final offlinePlaylistsFuture = downloadManager.getOfflinePlaylists();
    final snapDataFuture = downloadManager.getStats();
    final onlineFutures = isOnline
        ? [
            deezerAPI.fullPlaylist(cache.favoritesPlaylistId),
            deezerAPI.getPlaylists(),
            deezerAPI.getArtists(),
            deezerAPI.getAlbums(),
          ]
        : [];

    final results = await Future.wait<Object?>([
      // Explicit type parameter <Object?>
      snapDataFuture,
      favPlaylistFuture,
      offlinePlaylistsFuture,
      ...onlineFutures,
    ]);

    List<String> snapData = results[0] as List<String>;

    Playlist? favPlaylist = results[1] as Playlist?;
    List<Playlist> playlists = results[2] as List<Playlist>;
    Playlist? onlineFavPlaylist =
        isOnline && results.length > 3 ? results[3] as Playlist? : null;
    List<Playlist>? onlinePlaylists =
        isOnline && results.length > 4 ? results[4] as List<Playlist>? : null;
    List<Artist>? userArtists =
        isOnline && results.length > 5 ? results[5] as List<Artist> : null;
    List<Album>? userAlbums =
        isOnline && results.length > 6 ? results[6] as List<Album> : null;

    if (mounted) {
      setState(() {
        if (favPlaylist != null) {
          tracks = favPlaylist.tracks ?? [];
          trackCount = favPlaylist.tracks?.length;
          selectRandom3(tracks); // Reselect random tracks after loading
        }
        if (playlists.length > (_playlists?.length ?? 0)) {
          _playlists = playlists;
        }
        if (isOnline) {
          if (onlineFavPlaylist?.id != null) {
            trackCount = onlineFavPlaylist?.trackCount;
            if (tracks.isEmpty) tracks = onlineFavPlaylist?.tracks ?? [];
            _makeFavorite();
            favoritesPlaylist = onlineFavPlaylist;
            selectRandom3(tracks); // Reselect random tracks after online load
          }
          if (onlinePlaylists != null) {
            playlists = onlinePlaylists;
          }
        } else {
          downloadManager.allOfflineTracks().then((offlineTracks) {
            if (mounted) {
              setState(() {
                allTracks = offlineTracks;
                trackCount = offlineTracks.length;
                favoritesPlaylist = null;
                selectRandom3(allTracks); // Reselect random tracks for offline
              });
            }
          });
        }
        _playlists = playlists;
        _loading = false;
        cache.favoritePlaylists =
            playlists.isEmpty ? cache.favoritePlaylists : playlists;
        offlineTrackCount = snapData[0];
        favoriteArtists = userArtists?.length.toString() ?? '0';
        favoriteAlbums = userAlbums?.length.toString() ?? '0';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    cache.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.only(top: 12.0),
            children: <Widget>[
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: CachedImage(
                        url: deezerAPI.userPicture?.fullUrl ?? '',
                      ),
                    ),
                  ),
                ),
                title: const Center(
                  child: Text(
                    'Library',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                trailing: SizedBox(
                  width: 60,
                  child: IconButton(
                      onPressed: () {}, icon: const Icon(AlchemyIcons.shuffle)),
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Padding(
                  padding:
                      EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Downloads'.i18n,
                              subtitle: '$offlineTrackCount Songs'.i18n,
                              icon: AlchemyIcons.download,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        const DownloadsScreen()));
                              },
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width *
                                  0.05), // Spacing between items
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Artists'.i18n,
                              subtitle: '$favoriteArtists Artists'.i18n,
                              icon: AlchemyIcons.human,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => LibraryArtists()));
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.width *
                              0.05), // Spacing between rows
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Favorites'.i18n,
                              subtitle: '${trackCount ?? 0} Songs'.i18n,
                              icon: AlchemyIcons.heart,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => PlaylistDetails(
                                        favoritesPlaylist ?? Playlist())));
                              },
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width *
                                  0.05), // Spacing between items
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Albums'.i18n,
                              subtitle: '$favoriteAlbums Albums'.i18n,
                              icon: AlchemyIcons.album,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => LibraryAlbums()));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_playlists?.isEmpty ?? true)
                SizedBox(
                  height: 260,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.05),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Favorite Playlists'.i18n,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      trailing: Transform.scale(
                          scale: 0.5,
                          child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor)),
                      onTap: () => {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const LibraryPlaylists()))
                      },
                    ),
                  ),
                ),
              if (_playlists?.isNotEmpty ?? false)
                SizedBox(
                  height: 260,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal:
                                MediaQuery.of(context).size.width * 0.05),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Favorite Playlists'.i18n,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          trailing: _loading
                              ? Transform.scale(
                                  scale: 0.5,
                                  child: CircularProgressIndicator(
                                      color: Theme.of(context).primaryColor))
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text((_playlists!.length).toString(),
                                        style: TextStyle(
                                            color: Settings.secondaryText)),
                                    const Icon(
                                      Icons.chevron_right,
                                    )
                                  ],
                                ),
                          onTap: () => {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => const LibraryPlaylists()))
                          },
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width * 0.03),
                        child: Row(children: [
                          if (_playlists != null)
                            ...List.generate(_playlists!.length,
                                (int i) => LargePlaylistTile(_playlists![i]))
                        ]),
                      ),
                    ],
                  ),
                ),
              if (randomTracks.isEmpty)
                Column(children: [
                  SizedBox(
                    height: 224,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Favorite Tracks'.i18n,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        trailing: Transform.scale(
                            scale: 0.5,
                            child: CircularProgressIndicator(
                                color: Theme.of(context).primaryColor)),
                        onTap: () => (favoritesPlaylist != null)
                            ? Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => PlaylistDetails(
                                    favoritesPlaylist ?? Playlist())))
                            : null,
                      ),
                    ),
                  ),
                ]),
              if (randomTracks.isNotEmpty)
                SizedBox(
                  child: Column(children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Favorite Tracks'.i18n,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        trailing: _loading
                            ? Transform.scale(
                                scale: 0.5,
                                child: CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text((trackCount ?? 0).toString(),
                                      style: TextStyle(
                                          color: Settings.secondaryText)),
                                  const Icon(
                                    Icons.chevron_right,
                                  )
                                ],
                              ),
                        onTap: () => (favoritesPlaylist != null)
                            ? Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => PlaylistDetails(
                                    favoritesPlaylist ?? Playlist())))
                            : null,
                      ),
                    ),
                    ...List.generate(
                      randomTracks.length,
                      (int index) => Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: SimpleTrackTile(
                              randomTracks[index], favoritesPlaylist)),
                    ),
                  ]),
                ),
              ListenableBuilder(
                  listenable: playerBarState,
                  builder: (BuildContext context, Widget? child) {
                    return AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.only(
                          bottom: playerBarState.state ? 80 : 0),
                    );
                  }),
            ]),
      ),
    );
  }
}

class PlayerMenuButton extends StatelessWidget {
  final Track track;
  const PlayerMenuButton(this.track, {super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        AlchemyIcons.more_vert,
        semanticLabel: 'Options',
      ),
      onPressed: () {
        MenuSheet m = MenuSheet();
        m.defaultTrackMenu(track, context: context);
      },
    );
  }
}

class LibraryGridItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const LibraryGridItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(25),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
        decoration: ShapeDecoration(
          color: Colors.white.withAlpha(30),
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: 25,
              cornerSmoothing: 0.6,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0, top: 4.0),
              child: Icon(icon, size: 20),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
