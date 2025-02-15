import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttericon/octicons_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:deezer/settings.dart';
import 'package:deezer/ui/details_screens.dart';
import 'package:deezer/ui/favorite_screen.dart';
import 'package:deezer/ui/menu.dart';
import 'package:lottie/lottie.dart';

import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';
import 'cached_image.dart';

class TrackTile extends StatefulWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  final Widget? trailing;

  const TrackTile(this.track,
      {this.onTap, this.onHold, this.trailing, super.key});

  @override
  _TrackTileState createState() => _TrackTileState();
}

enum PlayingState { NONE, PLAYING, PAUSED }

class _TrackTileState extends State<TrackTile> {
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _downloadItemSub;
  bool _isOffline = false;
  PlayingState nowPlaying = PlayingState.NONE;
  bool nowDownloading = false;
  double downloadProgress = 0;

  /*bool get nowPlaying {
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value == null) return false;
    return GetIt.I<AudioPlayerHandler>().mediaItem.value!.id == widget.track.id;
  }*/

  @override
  void initState() {
    //Listen to media item changes, update text color if currently playing
    _mediaItemSub = GetIt.I<AudioPlayerHandler>().mediaItem.listen((item) {
      if (widget.track.id == item?.id) {
        if (mounted) {
          setState(() {
            nowPlaying =
                GetIt.I<AudioPlayerHandler>().playbackState.value.playing
                    ? PlayingState.PLAYING
                    : PlayingState.PAUSED;
            _stateSub =
                GetIt.I<AudioPlayerHandler>().playbackState.listen((state) {
              if (mounted) {
                setState(() {
                  nowPlaying = state.playing
                      ? PlayingState.PLAYING
                      : PlayingState.PAUSED;
                });
              }
            });
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _stateSub?.cancel();
            nowPlaying = PlayingState.NONE;
          });
        }
      }
    });
    //Check if offline
    downloadManager.checkOffline(track: widget.track).then((b) {
      if (mounted) {
        setState(() => _isOffline = b || (widget.track.offline ?? false));
      }
    });

    //Listen to download change to drop progress indicator
    _downloadItemSub = downloadManager.serviceEvents.stream.listen((e) async {
      List<Download> downloads = await downloadManager.getDownloads();

      if (e['action'] == 'onProgress' && mounted) {
        setState(() {
          for (Map su in e['data']) {
            downloads
                .firstWhere((d) => d.id == su['id'], orElse: () => Download())
                .updateFromJson(su);
          }
        });
      }

      for (int i = 0; i < downloads.length; i++) {
        if (downloads[i].trackId == widget.track.id) {
          if (downloads[i].state != DownloadState.DONE) {
            if (mounted) {
              setState(() {
                nowDownloading = true;
                downloadProgress = downloads[i].progress;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                nowDownloading = false;
                _isOffline = true;
              });
            }
          }
        }
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _mediaItemSub?.cancel();
    _downloadItemSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        dense: true,
        title: Text(
          widget.track.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
              fontWeight:
                  nowPlaying != PlayingState.NONE ? FontWeight.bold : null),
        ),
        subtitle: Text(
          widget.track.artistString ?? '',
          maxLines: 1,
        ),
        leading: Stack(
          children: [
            CachedImage(
              url: widget.track.albumArt?.thumb ?? '',
              width: 48,
              rounded: true,
            ),
            if (nowPlaying == PlayingState.PLAYING)
              Container(
                width: 48,
                height: 48,
                color: Colors.black.withAlpha(30),
                child: Center(
                    child: Lottie.asset('assets/animations/playing_wave.json',
                        repeat: true,
                        frameRate: FrameRate(60),
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40)),
              ),
            if (nowPlaying == PlayingState.PAUSED)
              Container(
                width: 48,
                height: 48,
                color: Colors.black.withAlpha(30),
                child: Center(
                    child: Lottie.asset('assets/animations/pausing_wave.json',
                        repeat: false,
                        frameRate: FrameRate(60),
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40)),
              ),
          ],
        ),
        onTap: widget.onTap,
        onLongPress: widget.onHold,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isOffline)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.0),
                child: Icon(
                  Octicons.primitive_dot,
                  color: Colors.green,
                  size: 12.0,
                ),
              ),
            if (widget.track.explicit ?? false)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.0),
                child: Text(
                  'E',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(
              width: 42.0,
              child: Text(
                widget.track.durationString ?? '',
                textAlign: TextAlign.center,
              ),
            ),
            widget.trailing ?? const SizedBox(width: 0, height: 0)
          ],
        ),
      ),
      if (nowDownloading)
        LinearProgressIndicator(
          value: downloadProgress,
          color: Colors.green.shade400,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          minHeight: 1,
        )
    ]);
  }
}

class SimpleTrackTile extends StatelessWidget {
  final Track track;
  final Playlist? playlist;

  const SimpleTrackTile(this.track, this.playlist, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      minVerticalPadding: 0,
      visualDensity: VisualDensity.compact,
      leading: CachedImage(
        url: track.albumArt?.full ?? '',
        height: 40,
        width: 40,
      ),
      title: Text(track.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(track.artistString ?? '',
          style: TextStyle(color: Settings.secondaryText, fontSize: 12)),
      trailing: PlayerMenuButton(track),
      onTap: () {
        GetIt.I<AudioPlayerHandler>().playFromTrackList(
            playlist?.tracks ?? [track],
            track.id ?? '',
            QueueSource(
                id: playlist?.id, text: 'Favorites'.i18n, source: 'playlist'));
      },
      onLongPress: () {
        MenuSheet m = MenuSheet();
        m.defaultTrackMenu(track, context: context);
      },
    );
  }
}

class AlbumTile extends StatelessWidget {
  final Album album;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  final Widget? trailing;

  const AlbumTile(this.album,
      {super.key, this.onTap, this.onHold, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        album.title ?? '',
        maxLines: 1,
      ),
      subtitle: Text(
        album.artistString ?? '',
        maxLines: 1,
      ),
      leading: CachedImage(
        url: album.art?.thumb ?? '',
        width: 48,
      ),
      onTap: onTap,
      onLongPress: onHold,
      trailing: trailing,
    );
  }
}

class ArtistTile extends StatelessWidget {
  final Artist artist;
  final VoidCallback? onTap;
  final VoidCallback? onHold;

  const ArtistTile(this.artist, {super.key, this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 150,
        child: InkWell(
          onTap: onTap,
          onLongPress: onHold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 4,
              ),
              CachedImage(
                url: artist.picture?.thumb ?? '',
                circular: true,
                width: 100,
              ),
              Container(
                height: 8,
              ),
              Text(
                artist.name ?? '',
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.0),
              ),
              Container(
                height: 4,
              ),
            ],
          ),
        ));
  }
}

class PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  final Widget? trailing;

  const PlaylistTile(this.playlist,
      {super.key, this.onHold, this.onTap, this.trailing});

  String get subtitle {
    if (playlist.user?.name == '' || playlist.user?.id == deezerAPI.userId) {
      if (playlist.trackCount == null) return '';
      return '${playlist.trackCount} ' + 'Tracks'.i18n;
    }
    return playlist.user?.name ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        playlist.title ?? '',
        maxLines: 1,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
      ),
      leading: CachedImage(
        url: playlist.image?.thumb ?? '',
        width: 48,
      ),
      onTap: onTap,
      onLongPress: onHold,
      trailing: trailing,
    );
  }
}

class ArtistHorizontalTile extends StatelessWidget {
  final Artist artist;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  final Widget? trailing;

  const ArtistHorizontalTile(this.artist,
      {super.key, this.onHold, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        title: Text(
          artist.name ?? '',
          maxLines: 1,
        ),
        leading: CachedImage(
          url: artist.picture?.thumb ?? '',
          circular: true,
        ),
        onTap: onTap,
        onLongPress: onHold,
        trailing: trailing,
      ),
    );
  }
}

class PlaylistCardTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  const PlaylistCardTile(this.playlist, {super.key, this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 180.0,
        child: InkWell(
          onTap: onTap,
          onLongPress: onHold,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8),
                child: CachedImage(
                  url: playlist.image?.thumb ?? '',
                  width: 128,
                  height: 128,
                  rounded: true,
                ),
              ),
              Container(height: 2.0),
              SizedBox(
                width: 144,
                child: Text(
                  playlist.title ?? '',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.0),
                ),
              ),
              Container(
                height: 4.0,
              )
            ],
          ),
        ));
  }
}

class SmartTrackListTile extends StatelessWidget {
  final SmartTrackList smartTrackList;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  const SmartTrackListTile(this.smartTrackList,
      {super.key, this.onHold, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 212.0,
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        child: Column(
          children: <Widget>[
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  children: [
                    CachedImage(
                      width: 128,
                      height: 128,
                      url: smartTrackList.cover?.full ?? '',
                      rounded: true,
                    ),
                    SizedBox(
                      width: 128.0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        child: Text(
                          smartTrackList.title ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18.0,
                            shadows: [
                              Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black)
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                )),
            SizedBox(
              width: 144.0,
              child: Text(
                smartTrackList.subtitle ?? '',
                maxLines: 3,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.0),
              ),
            ),
            Container(
              height: 8.0,
            )
          ],
        ),
      ),
    );
  }
}

class FlowTrackListTile extends StatelessWidget {
  final DeezerFlow deezerFlow;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  const FlowTrackListTile(this.deezerFlow,
      {super.key, this.onHold, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 120,
        child: InkWell(
          onTap: onTap,
          onLongPress: onHold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 4,
              ),
              CachedImage(
                url: deezerFlow.cover?.full ?? '',
                circular: true,
                width: 90,
              ),
              Container(
                height: 8,
              ),
              Text(
                deezerFlow.title ?? '',
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.0),
              ),
              Container(
                height: 4,
              ),
            ],
          ),
        ));
  }
}

class AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback? onTap;
  final VoidCallback? onHold;

  const AlbumCard(this.album, {super.key, this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onHold,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CachedImage(
                width: 128.0,
                height: 128.0,
                url: album.art?.thumb ?? '',
                rounded: true),
          ),
          SizedBox(
            width: 144.0,
            child: Text(
              album.title ?? '',
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14.0),
            ),
          ),
          Container(height: 4.0),
          SizedBox(
            width: 144.0,
            child: Text(
              album.artistString ?? '',
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.0,
                  color: (Theme.of(context).brightness == Brightness.light)
                      ? Colors.grey[800]
                      : Colors.white70),
            ),
          ),
          Container(
            height: 8.0,
          )
        ],
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  final DeezerChannel channel;
  final VoidCallback? onTap;
  const ChannelTile(this.channel, {super.key, this.onTap});

  Color _textColor() {
    if (channel.backgroundImage == null) {
      double luminance = channel.backgroundColor!.computeLuminance();
      return (luminance > 0.5) ? Colors.black : Colors.white;
    } else {
      // Deezer website seems to always use white for title over logo image
      return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Card(
        color: channel.backgroundImage == null ? channel.backgroundColor : null,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 148,
            height: 75,
            child: Center(
                child: Stack(
              children: [
                if (channel.backgroundImage != null)
                  CachedImage(
                    url: channel.backgroundImage
                            ?.customUrl('134', '264', quality: '100') ??
                        '',
                    width: 150,
                    height: 75,
                  ),
                if (channel.logoImage != null)
                  CachedImage(
                    url: channel.logoImage?.thumbUrl ?? '',
                    width: 150,
                    height: 75,
                  ),
                if (channel.title != null && channel.logo == null)
                  Center(
                      child: Text(
                    channel.title!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: _textColor()),
                  ))
              ],
            )),
          ),
        ),
      ),
    );
  }
}

class ShowCard extends StatelessWidget {
  final Show show;
  final VoidCallback? onTap;
  final VoidCallback? onHold;

  const ShowCard(this.show, {super.key, this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onHold,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CachedImage(
              url: show.art?.thumb ?? '',
              width: 128.0,
              height: 128.0,
              rounded: true,
            ),
          ),
          SizedBox(
            width: 144.0,
            child: Text(
              show.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.0),
            ),
          ),
        ],
      ),
    );
  }
}

class ShowTile extends StatelessWidget {
  final Show show;
  final VoidCallback? onTap;
  final VoidCallback? onHold;

  const ShowTile(this.show, {super.key, this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        show.name ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        show.description ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      onLongPress: onHold,
      leading: CachedImage(
        url: show.art?.thumb ?? '',
        width: 48,
      ),
    );
  }
}

class ShowEpisodeTile extends StatelessWidget {
  final ShowEpisode episode;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  final Widget? trailing;

  const ShowEpisodeTile(this.episode,
      {super.key, this.onTap, this.onHold, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onHold,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(episode.title ?? '', maxLines: 2),
            trailing: trailing,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              episode.description ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.color
                      ?.withOpacity(0.9)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8.0, 0, 0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  '${episode.publishedDate} | ${episode.durationString}',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.color
                          ?.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class LargePlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;

  const LargePlaylistTile(this.playlist, {this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap ??
                  () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => PlaylistDetails(playlist))),
              onLongPress: () {
                MenuSheet m = MenuSheet();
                m.defaultPlaylistMenu(playlist, context: context);
              },
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.transparent),
                    borderRadius: BorderRadius.circular(10)),
                child: CachedImage(
                  url: playlist.image?.fullUrl ?? '',
                  height: 180,
                  width: 180,
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 6.0),
                child: Text(playlist.title ?? '',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.start,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            if (playlist.user?.name != null && playlist.user?.name != '')
              SizedBox(
                  width: 180,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text('By '.i18n + (playlist.user?.name ?? ''),
                        maxLines: 1,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                            color: Settings.secondaryText, fontSize: 8)),
                  )),
            if (playlist.user?.name == null || playlist.user?.name == '')
              SizedBox(
                  width: 180,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text('By '.i18n + (deezerAPI.userName ?? ''),
                        maxLines: 1,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                            color: Settings.secondaryText, fontSize: 8)),
                  ))
          ],
        ));
  }
}

class LargeAlbumTile extends StatelessWidget {
  final Album album;

  const LargeAlbumTile(this.album, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AlbumDetails(album))),
              onLongPress: () {
                MenuSheet m = MenuSheet();
                m.defaultAlbumMenu(album, context: context);
              },
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.transparent),
                    borderRadius: BorderRadius.circular(10)),
                child: CachedImage(
                  url: album.art?.fullUrl ?? '',
                  height: 180,
                  width: 180,
                ),
              ),
            ),
            SizedBox(
                width: 180,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 6.0),
                  child: Text(album.title ?? '',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      textAlign: TextAlign.start,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )),
            SizedBox(
                width: 180,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text('By '.i18n + (album.artistString ?? ''),
                      maxLines: 1,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                          color: Settings.secondaryText, fontSize: 8)),
                )),
            SizedBox(
                width: 180,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Text('Out on '.i18n + (album.releaseDate ?? ''),
                      maxLines: 1,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                          color: Settings.secondaryText, fontSize: 8)),
                )),
          ],
        ));
  }
}
