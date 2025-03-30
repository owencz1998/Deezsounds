import 'dart:math';

import 'package:alchemy/service/audio_service.dart';
import 'package:alchemy/ui/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/main.dart';
import 'package:alchemy/ui/details_screens.dart';
import 'package:alchemy/ui/library.dart';
import 'package:alchemy/ui/menu.dart';
import 'package:alchemy/ui/tiles.dart';
import 'package:alchemy/utils/connectivity.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:get_it/get_it.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../settings.dart';
import '../translations.i18n.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String? favoriteShows = '0';
  String? favoriteArtists = '0';
  String? favoriteAlbums = '0';
  Playlist? topPlaylist;

  List<Playlist>? _playlists;

  Playlist? favoritesPlaylist;
  bool _loading = false;

  List<Track> tracks = [];
  List<Track> randomTracks = [];
  int? trackCount;

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
      tracks = cache.favoriteTracks;
    }

    // Load offline and online data concurrently
    final isOnline = await isConnected();
    final favPlaylistFuture =
        downloadManager.getOfflinePlaylist(cache.favoritesPlaylistId);
    final offlinePlaylistsFuture = downloadManager.getOfflinePlaylists();
    final offlineAlbumsFuture = downloadManager.getOfflineAlbums();
    final offlinePodcastsFuture = downloadManager.getOfflineShows();
    final onlineFutures = isOnline
        ? [
            deezerAPI.fullPlaylist(cache.favoritesPlaylistId),
            deezerAPI.getPlaylists(),
            deezerAPI.getArtists(),
            deezerAPI.getAlbums(),
            deezerAPI.userTracks(),
            deezerAPI.getUserShows(),
          ]
        : [];

    final results = await Future.wait<Object?>([
      // Explicit type parameter <Object?>
      offlinePodcastsFuture,
      favPlaylistFuture,
      offlinePlaylistsFuture,
      offlineAlbumsFuture,
      ...onlineFutures,
    ]);

    List<Show> shows = results[0] as List<Show>;
    Playlist? favPlaylist = results[1] as Playlist?;
    List<Playlist> playlists = results[2] as List<Playlist>;
    List<Album> albums = results[3] as List<Album>;
    Playlist? onlineFavPlaylist =
        isOnline && results.length > 4 ? results[4] as Playlist? : null;
    List<Playlist>? onlinePlaylists =
        isOnline && results.length > 5 ? results[5] as List<Playlist>? : null;
    List<Artist>? userArtists =
        isOnline && results.length > 6 ? results[6] as List<Artist> : null;
    List<Album>? userAlbums =
        isOnline && results.length > 7 ? results[7] as List<Album> : null;
    List<Track>? topTracks =
        isOnline && results.length > 8 ? results[8] as List<Track>? : null;
    List<Show>? userShows =
        isOnline && results.length > 9 ? results[9] as List<Show> : null;

    if (mounted) {
      setState(() {
        tracks =
            topTracks ?? onlineFavPlaylist?.tracks ?? favPlaylist?.tracks ?? [];
        topPlaylist = topTracks != null
            ? Playlist(
                id: '0',
                title: 'Your top tracks',
                image: ImageDetails.fromJson(cache.userPicture),
                duration: Duration.zero,
                user: User(id: '0', name: 'Deezer'),
                tracks: topTracks,
              )
            : onlineFavPlaylist ?? favPlaylist;
        cache.favoriteTracks = tracks;
        if (onlineFavPlaylist?.id != null) {
          favoritesPlaylist = onlineFavPlaylist;
          trackCount = onlineFavPlaylist?.tracks?.length;
        } else if (favPlaylist?.id != null) {
          favoritesPlaylist = favPlaylist;
          trackCount = favPlaylist?.tracks?.length;
          _makeFavorite();
        } else {
          downloadManager.allOfflineTracks().then((offlineTracks) {
            if (mounted) {
              setState(() {
                tracks = offlineTracks;
                trackCount = offlineTracks.length;
                favoritesPlaylist = Playlist(
                    id: '0',
                    title: 'Offline tracks',
                    duration: Duration.zero,
                    tracks: offlineTracks);
              });
            }
          });
        }
        _playlists = onlinePlaylists ?? playlists;
        _loading = false;
        cache.favoritePlaylists = _playlists ?? cache.favoritePlaylists;
        favoriteShows = userShows?.length.toString() ?? shows.length.toString();
        favoriteArtists = userArtists?.length.toString();
        favoriteAlbums =
            userAlbums?.length.toString() ?? albums.length.toString();
        cache.save();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.only(top: 12.0),
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.05),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CachedImage(
                        url: ImageDetails.fromJson(cache.userPicture).fullUrl ??
                            '',
                        circular: true,
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
                  height: 60,
                  width: 60,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      splashRadius: 20,
                      alignment: Alignment.center,
                      onPressed: () {
                        List<Track> trackList = List.from(tracks);
                        trackList.shuffle();
                        GetIt.I<AudioPlayerHandler>().playFromTrackList(
                            trackList,
                            trackList[0].id ?? '',
                            QueueSource(
                                id: '',
                                source: 'Library',
                                text: 'Library shuffle'.i18n));
                      },
                      icon: const Icon(AlchemyIcons.shuffle),
                    ),
                  ),
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
                              title: 'Favorites'.i18n,
                              subtitle: '${trackCount ?? 0} Songs'.i18n,
                              icon: AlchemyIcons.heart,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => PlaylistDetails(
                                        favoritesPlaylist ??
                                            Playlist(
                                                id: cache
                                                    .favoritesPlaylistId))));
                              },
                            ),
                          ),

                          SizedBox(
                              width: MediaQuery.of(context).size.width *
                                  0.05), // Spacing between items
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Artists'.i18n,
                              subtitle: favoriteArtists != null
                                  ? '$favoriteArtists Artists'.i18n
                                  : 'You are offline',
                              icon: AlchemyIcons.human_circle,
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
                              title: 'Podcasts'.i18n,
                              subtitle: '$favoriteShows Shows'.i18n,
                              icon: AlchemyIcons.podcast,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        const LibraryShows()));
                              },
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width *
                                  0.05), // Spacing between items
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Albums'.i18n,
                              subtitle: favoriteAlbums != null
                                  ? '$favoriteAlbums Albums'.i18n
                                  : 'You are offline',
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
              if ((_playlists?.isEmpty ?? true) && _loading)
                SizedBox(
                  height: 260,
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.05),
                    title: Text(
                      'Your Playlists'.i18n,
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
              if (_playlists?.isNotEmpty ?? false)
                SizedBox(
                  height: 260,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal:
                                MediaQuery.of(context).size.width * 0.05),
                        title: Text(
                          'Your Playlists'.i18n,
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
              if (tracks.isEmpty && _loading)
                Column(children: [
                  SizedBox(
                    height: 224,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05),
                      title: Text(
                        'Your Top Tracks'.i18n,
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
                ]),
              if (tracks.isNotEmpty)
                SizedBox(
                  child: Column(children: [
                    ListTile(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05),
                      title: Text(
                        'Your Top Tracks'.i18n,
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
                                Text((tracks.length).toString(),
                                    style: TextStyle(
                                        color: Settings.secondaryText)),
                                const Icon(
                                  Icons.chevron_right,
                                )
                              ],
                            ),
                      onTap: () =>
                          (topPlaylist != null || favoritesPlaylist != null)
                              ? Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => PlaylistDetails(
                                      topPlaylist ??
                                          favoritesPlaylist ??
                                          Playlist())))
                              : null,
                    ),
                    ...List.generate(
                      min(5, tracks.length),
                      (int index) => Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: SimpleTrackTile(tracks[index], topPlaylist)),
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
          color: settings.theme == Themes.Light
              ? Colors.black.withAlpha(30)
              : Colors.white.withAlpha(30),
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
