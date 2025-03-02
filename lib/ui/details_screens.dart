// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:deezer/ui/blind_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:deezer/fonts/alchemy_icons.dart';
import 'package:deezer/main.dart';
import 'package:deezer/settings.dart';
import 'package:deezer/utils/connectivity.dart';
import 'package:deezer/utils/navigator_keys.dart';
import 'package:share_plus/share_plus.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';
import '../ui/error.dart';
import '../ui/search.dart';
import 'cached_image.dart';
import 'menu.dart';
import 'tiles.dart';

class AlbumDetails extends StatefulWidget {
  final Album album;
  const AlbumDetails(this.album, {super.key});

  @override
  _AlbumDetailsState createState() => _AlbumDetailsState();
}

class _AlbumDetailsState extends State<AlbumDetails> {
  Album album = Album();
  bool _isLoading = true;
  bool isLibrary = false;
  bool _error = false;
  final PageController _albumController = PageController();
  int _currentPage = 0;

  Future _loadAlbum() async {
    if (mounted) setState(() => _isLoading = true);
    //Get album from API, if doesn't have tracks
    if ((album.tracks ?? []).isEmpty) {
      try {
        if (await isConnected()) {
          Album a = await deezerAPI.album(album.id ?? '');
          //Preserve library
          a.library = album.library;
          if (mounted && a.id != null) setState(() => album = a);
        } else {
          Album? a = await downloadManager.getOfflineAlbum(album.id ?? '');
          //Preserve library
          a?.library = album.library;
          if (mounted && a?.id != null) setState(() => album = a ?? Album());
        }
      } catch (e) {
        if (mounted) setState(() => _error = true);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  //Get count of CDs in album
  int get cdCount {
    int c = 1;
    for (Track t in (album.tracks ?? [])) {
      if ((t.diskNumber ?? 1) > c) c = t.diskNumber ?? 0;
    }
    return c;
  }

  Future _isLibrary() async {
    if (album.isIn(await downloadManager.getOfflineAlbums())) {
      setState(() {
        isLibrary = true;
      });
    }
    if (album.isIn(await deezerAPI.getAlbums())) {
      setState(() {
        isLibrary = true;
      });
    }
  }

  @override
  void initState() {
    album = widget.album;
    _loadAlbum();
    _isLibrary();

    super.initState();

    _albumController.addListener(() {
      setState(() {
        _currentPage = _albumController.page?.round() ?? 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _error
            ? const ErrorScreen()
            : _isLoading
                ? SplashScreen()
                : OrientationBuilder(
                    builder: (context, orientation) {
                      //Responsive
                      ScreenUtil.init(context, minTextAdapt: true);
                      //Landscape
                      if (orientation == Orientation.landscape) {
                        // ignore: prefer_const_constructors
                        return SafeArea(
                            child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height,
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4.0),
                                      child: ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          horizontalTitleGap: 8.0,
                                          leading: IconButton(
                                              onPressed: () async {
                                                await Navigator.of(context)
                                                    .maybePop();
                                              },
                                              icon: Icon(Icons.arrow_back)),
                                          title: Text(
                                            album.title ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18.0,
                                            ),
                                          ),
                                          subtitle: Text(
                                            album.artistString ?? '',
                                            style: TextStyle(
                                                fontSize: 14.0,
                                                color: Settings.secondaryText),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(AlchemyIcons.more_vert),
                                            onPressed: () {
                                              MenuSheet m = MenuSheet();
                                              m.defaultAlbumMenu(album,
                                                  context: context);
                                            },
                                          ))),
                                  SizedBox(
                                      width:
                                          MediaQuery.of(context).size.height *
                                              0.5,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.5,
                                      child: Stack(
                                        children: [
                                          PageView(
                                            controller: _albumController,
                                            onPageChanged: (index) {
                                              setState(() {
                                                _currentPage = index;
                                              });
                                            },
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Stack(
                                                    children: [
                                                      CachedImage(
                                                        url: album.art?.full ??
                                                            album.art?.thumb ??
                                                            'assets/cover.jpg',
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .height *
                                                            0.5,
                                                        fullThumb: true,
                                                        rounded: true,
                                                      ),
                                                      Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Container(
                                                              decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                      colors: [
                                                                        Theme.of(context)
                                                                            .scaffoldBackgroundColor
                                                                            .withAlpha(150),
                                                                        Colors
                                                                            .transparent
                                                                      ],
                                                                      begin: Alignment
                                                                          .bottomCenter,
                                                                      end: Alignment
                                                                          .topCenter,
                                                                      stops: [
                                                                        0.0,
                                                                        0.7
                                                                      ])),
                                                              child: SizedBox(
                                                                width: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .height *
                                                                    0.5,
                                                                height: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .height *
                                                                    0.1,
                                                              )),
                                                        ],
                                                      ),
                                                    ],
                                                  )
                                                ],
                                              ),
                                              Container(
                                                  clipBehavior: Clip.hardEdge,
                                                  decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .scaffoldBackgroundColor,
                                                      border: Border.all(
                                                          color: Colors
                                                              .transparent),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5)),
                                                  child: ListView(
                                                    children: [
                                                      ListTile(
                                                        dense: true,
                                                        visualDensity:
                                                            VisualDensity(
                                                                horizontal: 0.0,
                                                                vertical: -4),
                                                        minVerticalPadding: 0,
                                                        title: Text(
                                                          'Tracks'.i18n,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16),
                                                        ),
                                                        subtitle: Text(
                                                            (album.tracks
                                                                    ?.length)
                                                                .toString(),
                                                            style: TextStyle(
                                                                color: Settings
                                                                    .secondaryText,
                                                                fontSize: 12)),
                                                      ),
                                                      ListTile(
                                                        dense: true,
                                                        visualDensity:
                                                            VisualDensity(
                                                                horizontal: 0.0,
                                                                vertical: -4),
                                                        minVerticalPadding: 0,
                                                        title: Text(
                                                          'Duration'.i18n,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16),
                                                        ),
                                                        subtitle: Text(
                                                            album
                                                                .durationString,
                                                            style: TextStyle(
                                                                color: Settings
                                                                    .secondaryText,
                                                                fontSize: 12)),
                                                      ),
                                                      ListTile(
                                                        dense: true,
                                                        visualDensity:
                                                            VisualDensity(
                                                                horizontal: 0.0,
                                                                vertical: -4),
                                                        minVerticalPadding: 0,
                                                        title: Text(
                                                          'Fans'.i18n,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16),
                                                        ),
                                                        subtitle: Text(
                                                            (album.fans ?? 0)
                                                                .toString(),
                                                            style: TextStyle(
                                                                color: Settings
                                                                    .secondaryText,
                                                                fontSize: 12)),
                                                      ),
                                                      ListTile(
                                                        dense: true,
                                                        visualDensity:
                                                            VisualDensity(
                                                                horizontal: 0.0,
                                                                vertical: -4),
                                                        minVerticalPadding: 0,
                                                        title: Text(
                                                          'Released'.i18n,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16),
                                                        ),
                                                        subtitle: Text(
                                                            album.releaseDate ??
                                                                '',
                                                            style: TextStyle(
                                                                color: Settings
                                                                    .secondaryText,
                                                                fontSize: 12)),
                                                      ),
                                                    ],
                                                  ))
                                            ],
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Padding(
                                                padding:
                                                    EdgeInsets.only(top: 8.0),
                                                child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: List.generate(
                                                        2,
                                                        (i) => Container(
                                                              margin: EdgeInsets
                                                                  .symmetric(
                                                                      horizontal:
                                                                          2.0,
                                                                      vertical:
                                                                          8.0),
                                                              width: 12.0,
                                                              height: 4.0,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .white
                                                                    .withAlpha(
                                                                        _currentPage ==
                                                                                i
                                                                            ? 255
                                                                            : 150),
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .transparent),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            100),
                                                              ),
                                                            ))),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 6.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.max,
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: IconButton(
                                                icon: isLibrary
                                                    ? Icon(
                                                        AlchemyIcons.heart_fill,
                                                        size: 25,
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        semanticLabel:
                                                            'Unlove'.i18n,
                                                      )
                                                    : Icon(
                                                        AlchemyIcons.heart,
                                                        size: 25,
                                                        semanticLabel:
                                                            'Love'.i18n,
                                                      ),
                                                onPressed: () async {
                                                  //Add to library
                                                  if (!isLibrary) {
                                                    await deezerAPI
                                                        .addFavoriteAlbum(
                                                            album.id ?? '');
                                                    Fluttertoast.showToast(
                                                        msg: 'Added to library'
                                                            .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() =>
                                                        album.library = true);
                                                    return;
                                                  }
                                                  //Remove
                                                  await deezerAPI.removeAlbum(
                                                      album.id ?? '');
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Album removed from library!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                  setState(() =>
                                                      album.library = false);
                                                },
                                              ),
                                            ),
                                            IconButton(
                                                onPressed: () => {
                                                      Share.share(
                                                          'https://deezer.com/album/' +
                                                              (album.id ?? ''))
                                                    },
                                                icon: Icon(
                                                  AlchemyIcons.share_android,
                                                  size: 20.0,
                                                )),
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(left: 8.0),
                                              child: MakeAlbumOffline(
                                                  album: album),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              margin:
                                                  EdgeInsets.only(right: 6.0),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                border: Border.all(
                                                    color: Theme.of(context)
                                                        .scaffoldBackgroundColor
                                                        .withAlpha(0)),
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                              ),
                                              child: IconButton(
                                                  onPressed: () async {
                                                    album.tracks?.shuffle();
                                                    GetIt.I<AudioPlayerHandler>()
                                                        .playFromTrackList(
                                                            album.tracks ?? [],
                                                            album.tracks?[0]
                                                                    .id ??
                                                                '',
                                                            QueueSource(
                                                                id: album.id,
                                                                source:
                                                                    album.title,
                                                                text: album
                                                                        .title ??
                                                                    'Album' +
                                                                        ' shuffle'
                                                                            .i18n));
                                                  },
                                                  icon: Icon(
                                                    AlchemyIcons.shuffle,
                                                    size: 18,
                                                  )),
                                            )
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                children: [
                                  ...List.generate((album.tracks?.length ?? 0),
                                      (i) {
                                    Track t = (album.tracks ?? [])[i];
                                    return TrackTile(t, onTap: () {
                                      Playlist p = Playlist(
                                          title: album.title,
                                          id: album.id,
                                          tracks: album.tracks);
                                      GetIt.I<AudioPlayerHandler>()
                                          .playFromPlaylist(p, t.id ?? '');
                                    }, onHold: () {
                                      MenuSheet m = MenuSheet();
                                      m.defaultTrackMenu(t, context: context);
                                    });
                                  }),
                                  if (_isLoading)
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          CircularProgressIndicator(
                                            color:
                                                Theme.of(context).primaryColor,
                                          )
                                        ],
                                      ),
                                    ),
                                  if (_error && (album.tracks ?? []).isEmpty)
                                    const ErrorScreen(),
                                  ListenableBuilder(
                                      listenable: playerBarState,
                                      builder: (BuildContext context,
                                          Widget? child) {
                                        return AnimatedPadding(
                                          duration: Duration(milliseconds: 200),
                                          padding: EdgeInsets.only(
                                              bottom: playerBarState.state
                                                  ? 80
                                                  : 0),
                                        );
                                      }),
                                ],
                              ),
                            ),
                          ],
                        ));
                      }
                      //Portrait
                      // ignore: prefer_const_constructors
                      return ListView(
                        children: <Widget>[
                          SizedBox(
                              width: double.infinity,
                              height: MediaQuery.of(context).size.width,
                              child: Stack(
                                children: [
                                  PageView(
                                    controller: _albumController,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentPage = index;
                                      });
                                    },
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Stack(
                                            children: [
                                              CachedImage(
                                                url: album.art?.fullUrl ??
                                                    album.art?.thumbUrl ??
                                                    'assets/cover.jpg',
                                                width: MediaQuery.of(context)
                                                    .size
                                                    .width,
                                                fullThumb: true,
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                                colors: [
                                                                  Theme.of(
                                                                          context)
                                                                      .scaffoldBackgroundColor
                                                                      .withAlpha(
                                                                          150),
                                                                  Theme.of(
                                                                          context)
                                                                      .scaffoldBackgroundColor
                                                                      .withAlpha(
                                                                          0)
                                                                ],
                                                                begin: Alignment
                                                                    .topCenter,
                                                                end: Alignment
                                                                    .bottomCenter,
                                                                stops: [
                                                                  0.0,
                                                                  0.7
                                                                ])),
                                                    child: SizedBox(
                                                      width:
                                                          MediaQuery.of(context)
                                                              .size
                                                              .width,
                                                      height:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width /
                                                              6,
                                                    ),
                                                  ),
                                                  Container(
                                                      decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                              colors: [
                                                                Theme.of(
                                                                        context)
                                                                    .scaffoldBackgroundColor
                                                                    .withAlpha(
                                                                        150),
                                                                Colors
                                                                    .transparent
                                                              ],
                                                              begin: Alignment
                                                                  .bottomCenter,
                                                              end: Alignment
                                                                  .topCenter,
                                                              stops: [
                                                                0.0,
                                                                0.7
                                                              ])),
                                                      child: SizedBox(
                                                        width: MediaQuery.of(
                                                                context)
                                                            .size
                                                            .width,
                                                        height: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width /
                                                            6,
                                                      )),
                                                ],
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                      Container(
                                          decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .scaffoldBackgroundColor),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ListTile(
                                                minVerticalPadding: 1,
                                                leading: Icon(
                                                  AlchemyIcons.album,
                                                  size: 25,
                                                ),
                                                title: Text(
                                                  'Tracks'.i18n,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                                subtitle: Text(
                                                    (album.tracks?.length)
                                                        .toString(),
                                                    style: TextStyle(
                                                        color: Settings
                                                            .secondaryText,
                                                        fontSize: 12)),
                                              ),
                                              ListTile(
                                                minVerticalPadding: 1,
                                                leading: Icon(
                                                  AlchemyIcons.clock,
                                                  size: 25,
                                                ),
                                                title: Text(
                                                  'Duration'.i18n,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                                subtitle: Text(
                                                    album.durationString,
                                                    style: TextStyle(
                                                        color: Settings
                                                            .secondaryText,
                                                        fontSize: 12)),
                                              ),
                                              ListTile(
                                                minVerticalPadding: 1,
                                                leading: Icon(
                                                  AlchemyIcons.heart,
                                                  size: 25,
                                                ),
                                                title: Text(
                                                  'Fans'.i18n,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                                subtitle: Text(
                                                    (album.fans ?? 0)
                                                        .toString(),
                                                    style: TextStyle(
                                                        color: Settings
                                                            .secondaryText,
                                                        fontSize: 12)),
                                              ),
                                              ListTile(
                                                minVerticalPadding: 1,
                                                leading: Icon(
                                                  AlchemyIcons.calendar,
                                                  size: 25,
                                                ),
                                                title: Text(
                                                  'Released'.i18n,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                                subtitle: Text(
                                                    album.releaseDate ?? '',
                                                    style: TextStyle(
                                                        color: Settings
                                                            .secondaryText,
                                                        fontSize: 12)),
                                              ),
                                            ],
                                          ))
                                    ],
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            IconButton(
                                                onPressed: () async {
                                                  await Navigator.of(context)
                                                      .maybePop();
                                                },
                                                icon: Icon(Icons.arrow_back)),
                                            IconButton(
                                              icon:
                                                  Icon(AlchemyIcons.more_vert),
                                              onPressed: () {
                                                MenuSheet m = MenuSheet();
                                                m.defaultAlbumMenu(album,
                                                    context: context);
                                              },
                                            )
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(top: 8.0),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: List.generate(
                                                2,
                                                (i) => Container(
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 2.0,
                                                              vertical: 8.0),
                                                      width: 12.0,
                                                      height: 4.0,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withAlpha(
                                                                _currentPage ==
                                                                        i
                                                                    ? 255
                                                                    : 150),
                                                        border: Border.all(
                                                            color: Colors
                                                                .transparent),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(100),
                                                      ),
                                                    ))),
                                      ),
                                    ],
                                  ),
                                ],
                              )),
                          Padding(
                              padding: EdgeInsets.fromLTRB(4.0, 16.0, 4.0, 4.0),
                              child: ListTile(
                                title: Text(
                                  album.title ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.start,
                                  maxLines: 1,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 40.0,
                                      fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  album.artistString ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                      color: Settings.secondaryText,
                                      fontSize: 14.0),
                                ),
                              )),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: IconButton(
                                        icon: isLibrary
                                            ? Icon(
                                                AlchemyIcons.heart_fill,
                                                size: 25,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                semanticLabel: 'Unlove'.i18n,
                                              )
                                            : Icon(
                                                AlchemyIcons.heart,
                                                size: 25,
                                                semanticLabel: 'Love'.i18n,
                                              ),
                                        onPressed: () async {
                                          //Add to library
                                          if (!isLibrary) {
                                            await deezerAPI.addFavoriteAlbum(
                                                album.id ?? '');
                                            Fluttertoast.showToast(
                                                msg: 'Added to library'.i18n,
                                                toastLength: Toast.LENGTH_SHORT,
                                                gravity: ToastGravity.BOTTOM);
                                            setState(
                                                () => album.library = true);
                                            return;
                                          }
                                          //Remove
                                          await deezerAPI
                                              .removeAlbum(album.id ?? '');
                                          Fluttertoast.showToast(
                                              msg:
                                                  'Playlist removed from library!'
                                                      .i18n,
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.BOTTOM);
                                          setState(() => album.library = false);
                                        },
                                      ),
                                    ),
                                    IconButton(
                                        onPressed: () => {
                                              Share.share(
                                                  'https://deezer.com/album/' +
                                                      (album.id ?? ''))
                                            },
                                        icon: Icon(
                                          AlchemyIcons.share_android,
                                          size: 20.0,
                                        )),
                                    Padding(
                                      padding: EdgeInsets.only(left: 8.0),
                                      child: MakeAlbumOffline(album: album),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      margin: EdgeInsets.only(right: 6.0),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        border: Border.all(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor
                                                .withAlpha(0)),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: IconButton(
                                          onPressed: () async {
                                            album.tracks?.shuffle();
                                            GetIt.I<AudioPlayerHandler>()
                                                .playFromTrackList(
                                                    album.tracks ?? [],
                                                    album.tracks?[0].id ?? '',
                                                    QueueSource(
                                                        id: album.id,
                                                        source: album.title,
                                                        text: album.title ??
                                                            'Album' +
                                                                ' shuffle'
                                                                    .i18n));
                                          },
                                          icon: Icon(
                                            AlchemyIcons.shuffle,
                                            size: 18,
                                          )),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                          const FreezerDivider(),
                          ...List.generate((album.tracks?.length ?? 0), (i) {
                            Track t = (album.tracks ?? [])[i];
                            return TrackTile(t, onTap: () {
                              Playlist p = Playlist(
                                  title: album.title,
                                  id: album.id,
                                  tracks: album.tracks);
                              GetIt.I<AudioPlayerHandler>()
                                  .playFromPlaylist(p, t.id ?? '');
                            }, onHold: () {
                              MenuSheet m = MenuSheet();
                              m.defaultTrackMenu(t, context: context);
                            });
                          }),
                          if (_isLoading)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  )
                                ],
                              ),
                            ),
                          if (_error && (album.tracks ?? []).isEmpty)
                            const ErrorScreen(),
                          ListenableBuilder(
                              listenable: playerBarState,
                              builder: (BuildContext context, Widget? child) {
                                return AnimatedPadding(
                                  duration: Duration(milliseconds: 200),
                                  padding: EdgeInsets.only(
                                      bottom: playerBarState.state ? 80 : 0),
                                );
                              }),
                        ],
                      );
                    },
                  ));
  }
}

class MakeAlbumOffline extends StatefulWidget {
  final Album? album;
  const MakeAlbumOffline({super.key, this.album});

  @override
  _MakeAlbumOfflineState createState() => _MakeAlbumOfflineState();
}

class _MakeAlbumOfflineState extends State<MakeAlbumOffline> {
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    downloadManager.checkOffline(album: widget.album).then((v) {
      setState(() {
        _offline = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: _offline
            ? Icon(
                AlchemyIcons.download_fill,
                size: 25,
                color: Theme.of(context).primaryColor,
              )
            : Icon(
                AlchemyIcons.download,
                size: 25,
              ),
        onPressed: () async {
          //Add to offline
          if (_offline) {
            downloadManager.removeOfflineAlbum(widget.album?.id ?? '');
            Fluttertoast.showToast(
                msg: 'Removed album from offline!'.i18n,
                gravity: ToastGravity.BOTTOM,
                toastLength: Toast.LENGTH_SHORT);
            setState(() {
              _offline = false;
            });
          } else {
            await deezerAPI.addFavoriteAlbum(widget.album?.id ?? '');
            await downloadManager.addOfflineAlbum(widget.album ?? Album(),
                private: true);
            MenuSheet().showDownloadStartedToast();
            setState(() {
              _offline = true;
            });
            return;
          }
        });
  }
}

class ArtistDetails extends StatefulWidget {
  final Artist artist;
  const ArtistDetails(this.artist, {super.key});

  @override
  _ArtistDetailsState createState() => _ArtistDetailsState();
}

class _ArtistDetailsState extends State<ArtistDetails> {
  Artist artist = Artist();
  bool _isLoading = true;
  bool _error = false;
  bool isLibrary = false;

  Future _loadArtist() async {
    //Load artist from api if no albums
    if (artist.albums.isEmpty) {
      try {
        Artist a = await deezerAPI.artist(artist.id ?? '');
        setState(() => artist = a);
      } catch (e) {
        setState(() => _error = true);
      }
    }
    setState(() => _isLoading = false);
  }

  Future _isLibrary() async {
    if (artist.isIn(await deezerAPI.getArtists())) {
      setState(() {
        isLibrary = true;
      });
    }
  }

  @override
  void initState() {
    artist = widget.artist;
    _loadArtist();

    _isLibrary();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _error
            ? const ErrorScreen()
            : _isLoading
                ? SplashScreen()
                : OrientationBuilder(builder: (context, orientation) {
                    //Responsive
                    ScreenUtil.init(context, minTextAdapt: true);
                    //Landscape
                    if (orientation == Orientation.landscape) {
                      // ignore: prefer_const_constructors
                      return SafeArea(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height,
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4.0),
                                      child: ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          horizontalTitleGap: 8.0,
                                          leading: IconButton(
                                              onPressed: () async {
                                                await Navigator.of(context)
                                                    .maybePop();
                                              },
                                              icon: Icon(Icons.arrow_back)),
                                          title: Text(
                                            artist.name ?? '',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18.0),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(AlchemyIcons.more_vert),
                                            onPressed: () {
                                              MenuSheet m = MenuSheet();
                                              m.defaultArtistMenu(artist,
                                                  context: context);
                                            },
                                          ))),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.height *
                                        0.5,
                                    height: MediaQuery.of(context).size.height *
                                        0.5,
                                    child: CachedImage(
                                      url: artist.picture?.full ?? '',
                                      width:
                                          MediaQuery.of(context).size.height *
                                              0.5,
                                      fullThumb: true,
                                      circular: true,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 6.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.max,
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: IconButton(
                                                icon: isLibrary
                                                    ? Icon(
                                                        AlchemyIcons.heart_fill,
                                                        size: 25,
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        semanticLabel:
                                                            'Unlove'.i18n,
                                                      )
                                                    : Icon(
                                                        AlchemyIcons.heart,
                                                        size: 25,
                                                        semanticLabel:
                                                            'Love'.i18n,
                                                      ),
                                                onPressed: () async {
                                                  //Add to library
                                                  if (!isLibrary) {
                                                    await deezerAPI
                                                        .addFavoriteArtist(
                                                            artist.id ?? '');
                                                    Fluttertoast.showToast(
                                                        msg: 'Added to library'
                                                            .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() =>
                                                        artist.library = true);
                                                    return;
                                                  }
                                                  //Remove
                                                  await deezerAPI.removeArtist(
                                                      artist.id ?? '');
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Artist removed from library!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                  setState(() =>
                                                      artist.library = false);
                                                },
                                              ),
                                            ),
                                            IconButton(
                                                onPressed: () => {
                                                      Share.share(
                                                          'https://deezer.com/artist/' +
                                                              (artist.id ?? ''))
                                                    },
                                                icon: Icon(
                                                  AlchemyIcons.share_android,
                                                  size: 20.0,
                                                )),
                                          ],
                                        ),
                                        if ((artist.radio ?? false))
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                margin:
                                                    EdgeInsets.only(right: 6.0),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  border: Border.all(
                                                      color: Theme.of(context)
                                                          .scaffoldBackgroundColor
                                                          .withAlpha(0)),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          100),
                                                ),
                                                child: IconButton(
                                                    onPressed: () async {
                                                      List<Track> tracks =
                                                          await deezerAPI
                                                              .smartRadio(
                                                                  artist.id ??
                                                                      '');
                                                      if (tracks.isNotEmpty) {
                                                        GetIt.I<AudioPlayerHandler>()
                                                            .playFromTrackList(
                                                                tracks,
                                                                tracks[0].id!,
                                                                QueueSource(
                                                                    id:
                                                                        artist
                                                                            .id,
                                                                    text: 'Radio'
                                                                            .i18n +
                                                                        ' ${artist.name}',
                                                                    source:
                                                                        'smartradio'));
                                                      }
                                                    },
                                                    icon: Icon(
                                                      AlchemyIcons.shuffle,
                                                      size: 18,
                                                    )),
                                              )
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Top Tracks'.i18n,
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20.0),
                                    ),
                                  ),
                                  ...List.generate(3, (i) {
                                    if (artist.topTracks.length <= i) {
                                      return const SizedBox(
                                        height: 0,
                                        width: 0,
                                      );
                                    }
                                    Track t = artist.topTracks[i];
                                    return TrackTile(
                                      t,
                                      onTap: () {
                                        GetIt.I<AudioPlayerHandler>()
                                            .playFromTopTracks(artist.topTracks,
                                                t.id!, artist);
                                      },
                                      onHold: () {
                                        MenuSheet mi = MenuSheet();
                                        mi.defaultTrackMenu(t,
                                            context: context);
                                      },
                                    );
                                  }),
                                  Container(
                                    margin: EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 12.0),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Theme.of(context).hintColor,
                                          width: 1.5),
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    TrackListScreen(
                                                        artist.topTracks,
                                                        QueueSource(
                                                            id: artist.id,
                                                            text: 'Top'.i18n +
                                                                '${artist.name}',
                                                            source:
                                                                'topTracks'))));
                                      },
                                      child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 8.0, horizontal: 12.0),
                                          child: Text(
                                            'View all'.i18n,
                                            textAlign: TextAlign.center,
                                          )),
                                    ),
                                  ),
                                  //Highlight
                                  if (artist.highlight != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            artist.highlight?.title ?? '',
                                            textAlign: TextAlign.left,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20.0),
                                          ),
                                        ),
                                        if ((artist.highlight?.type ?? '') ==
                                            ArtistHighlightType.ALBUM)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16.0),
                                            child: Container(
                                              clipBehavior: Clip.hardEdge,
                                              decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Theme.of(context)
                                                          .scaffoldBackgroundColor
                                                          .withAlpha(0)),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: Colors.white
                                                      .withAlpha(30)),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                radius: 10.0,
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              AlbumDetails(
                                                                  artist
                                                                      .highlight
                                                                      ?.data)));
                                                },
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    CachedImage(
                                                      url: artist
                                                              .highlight
                                                              ?.data
                                                              ?.art
                                                              ?.full ??
                                                          '',
                                                      height: 150,
                                                      width: 150,
                                                      fullThumb: true,
                                                      rounded: true,
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(12.0),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            artist.highlight
                                                                ?.data?.title,
                                                            style: TextStyle(
                                                                fontSize: 16.0),
                                                          ),
                                                          Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(
                                                                          4.0)),
                                                          Text(
                                                              'By ' +
                                                                  artist
                                                                      .highlight
                                                                      ?.data
                                                                      ?.artistString,
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12.0,
                                                                  color: Settings
                                                                      .secondaryText)),
                                                          Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(
                                                                          4.0)),
                                                          Text(
                                                              'Released on ' +
                                                                  artist
                                                                      .highlight
                                                                      ?.data
                                                                      ?.releaseDate,
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12.0,
                                                                  color: Settings
                                                                      .secondaryText))
                                                        ],
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  //Albums
                                  Container(
                                    height: 8.0,
                                  ),
                                  Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 4.0),
                                        child: InkWell(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          DiscographyScreen(
                                                            artist: artist,
                                                          )));
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 12.0,
                                                      horizontal: 4.0),
                                                  child: Text(
                                                    'Discography'.i18n,
                                                    textAlign: TextAlign.left,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20.0),
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right,
                                                )
                                              ],
                                            )),
                                      ),
                                      Container(height: 4.0),
                                      Padding(
                                          padding: EdgeInsets.fromLTRB(
                                              12.0, 8.0, 1.0, 8.0),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics: ClampingScrollPhysics(),
                                            child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: List.generate(
                                                    artist.albums.length > 10
                                                        ? 10
                                                        : artist.albums.length,
                                                    (i) {
                                                  //Top albums
                                                  Album a = artist.albums[i];
                                                  return LargeAlbumTile(a);
                                                })),
                                          )),
                                      ListenableBuilder(
                                          listenable: playerBarState,
                                          builder: (BuildContext context,
                                              Widget? child) {
                                            return AnimatedPadding(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              padding: EdgeInsets.only(
                                                  bottom: playerBarState.state
                                                      ? 80
                                                      : 5),
                                            );
                                          }),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ]));
                    }
                    //Portrait
                    // ignore: prefer_const_constructors
                    return ListView(
                      children: <Widget>[
                        SizedBox(
                          height: MediaQuery.of(context).size.width,
                          width: MediaQuery.of(context).size.width,
                          child: Stack(
                            children: [
                              CachedImage(
                                url: artist.picture?.full ?? '',
                                width: MediaQuery.of(context).size.width,
                                fullThumb: true,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [
                                              Theme.of(context)
                                                  .scaffoldBackgroundColor
                                                  .withAlpha(150),
                                              Theme.of(context)
                                                  .scaffoldBackgroundColor
                                                  .withAlpha(0)
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: [0.0, 0.7])),
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width,
                                      height:
                                          MediaQuery.of(context).size.width / 6,
                                    ),
                                  ),
                                  Container(
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(150),
                                                Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(0)
                                              ],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              stops: [0.0, 0.7])),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height:
                                            MediaQuery.of(context).size.width /
                                                6,
                                      )),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        IconButton(
                                            onPressed: () async {
                                              await Navigator.of(context)
                                                  .maybePop();
                                            },
                                            icon: Icon(Icons.arrow_back)),
                                        IconButton(
                                          icon: Icon(AlchemyIcons.more_vert),
                                          onPressed: () {
                                            MenuSheet m = MenuSheet();
                                            m.defaultArtistMenu(artist,
                                                context: context);
                                          },
                                        )
                                      ],
                                    ),
                                  ),
                                  ListTile(
                                    title: Text(
                                      artist.name ?? '',
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 40.0,
                                          fontWeight: FontWeight.w900),
                                    ),
                                    subtitle: Text(artist.fansString + ' fans',
                                        textAlign: TextAlign.left,
                                        style: TextStyle(fontSize: 14.0)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 6.0),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: IconButton(
                                          icon: isLibrary
                                              ? Icon(
                                                  AlchemyIcons.heart_fill,
                                                  size: 25,
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  semanticLabel: 'Unlove'.i18n,
                                                )
                                              : Icon(
                                                  AlchemyIcons.heart,
                                                  size: 25,
                                                  semanticLabel: 'Love'.i18n,
                                                ),
                                          onPressed: () async {
                                            await deezerAPI.addFavoriteArtist(
                                                artist.id ?? '');
                                            Fluttertoast.showToast(
                                                msg: 'Added to library'.i18n,
                                                toastLength: Toast.LENGTH_SHORT,
                                                gravity: ToastGravity.BOTTOM);
                                          },
                                        ),
                                      ),
                                      IconButton(
                                          onPressed: () => {
                                                Share.share(
                                                    'https://deezer.com/artist/' +
                                                        (artist.id ?? ''))
                                              },
                                          icon: Icon(
                                            AlchemyIcons.share_android,
                                            size: 20.0,
                                          )),
                                    ],
                                  ),
                                  if ((artist.radio ?? false))
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          margin: EdgeInsets.only(right: 6.0),
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            border: Border.all(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(0)),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: IconButton(
                                              onPressed: () async {
                                                List<Track> tracks =
                                                    await deezerAPI.smartRadio(
                                                        artist.id ?? '');
                                                if (tracks.isNotEmpty) {
                                                  GetIt.I<AudioPlayerHandler>()
                                                      .playFromTrackList(
                                                          tracks,
                                                          tracks[0].id!,
                                                          QueueSource(
                                                              id: artist.id,
                                                              text: 'Radio'
                                                                      .i18n +
                                                                  ' ${artist.name}',
                                                              source:
                                                                  'smartradio'));
                                                }
                                              },
                                              icon: Icon(
                                                AlchemyIcons.shuffle,
                                                size: 18,
                                              )),
                                        )
                                      ],
                                    ),
                                ])),
                        //Top tracks
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Top Tracks'.i18n,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20.0),
                          ),
                        ),
                        Container(height: 4.0),
                        ...List.generate(3, (i) {
                          if (artist.topTracks.length <= i) {
                            return const SizedBox(
                              height: 0,
                              width: 0,
                            );
                          }
                          Track t = artist.topTracks[i];
                          return TrackTile(
                            t,
                            onTap: () {
                              GetIt.I<AudioPlayerHandler>().playFromTopTracks(
                                  artist.topTracks, t.id!, artist);
                            },
                            onHold: () {
                              MenuSheet mi = MenuSheet();
                              mi.defaultTrackMenu(t, context: context);
                            },
                          );
                        }),
                        Container(
                          margin: EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 12.0),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.white.withAlpha(30), width: 1.5),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => TrackListScreen(
                                      artist.topTracks,
                                      QueueSource(
                                          id: artist.id,
                                          text: 'Top'.i18n + '${artist.name}',
                                          source: 'topTracks'))));
                            },
                            child: Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 12.0),
                                child: Text(
                                  'View all'.i18n,
                                  textAlign: TextAlign.center,
                                )),
                          ),
                        ),
                        //Highlight
                        if (artist.highlight != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  artist.highlight?.title ?? '',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20.0),
                                ),
                              ),
                              if ((artist.highlight?.type ?? '') ==
                                  ArtistHighlightType.ALBUM)
                                Container(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Container(
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor
                                                .withAlpha(0)),
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.white.withAlpha(30)),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      radius: 10.0,
                                      onTap: () {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    AlbumDetails(artist
                                                        .highlight?.data)));
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CachedImage(
                                            url: artist.highlight?.data?.art
                                                    ?.full ??
                                                '',
                                            height: 150,
                                            width: 150,
                                            fullThumb: true,
                                            rounded: true,
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  artist.highlight?.data?.title,
                                                  style:
                                                      TextStyle(fontSize: 16.0),
                                                ),
                                                Padding(
                                                    padding:
                                                        EdgeInsets.all(4.0)),
                                                Text(
                                                    'By ' +
                                                        artist.highlight?.data
                                                            ?.artistString,
                                                    style: TextStyle(
                                                        fontSize: 12.0,
                                                        color: Settings
                                                            .secondaryText)),
                                                Padding(
                                                    padding:
                                                        EdgeInsets.all(4.0)),
                                                Text(
                                                    'Released on ' +
                                                        artist.highlight?.data
                                                            ?.releaseDate,
                                                    style: TextStyle(
                                                        fontSize: 12.0,
                                                        color: Settings
                                                            .secondaryText))
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        //Albums
                        Container(
                          height: 8.0,
                        ),
                        SizedBox(
                          height: 320,
                          child: Column(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 4.0),
                              child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DiscographyScreen(
                                                  artist: artist,
                                                )));
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12.0, horizontal: 4.0),
                                        child: Text(
                                          'Discography'.i18n,
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20.0),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                      )
                                    ],
                                  )),
                            ),
                            Container(height: 4.0),
                            Padding(
                                padding:
                                    EdgeInsets.fromLTRB(12.0, 8.0, 1.0, 8.0),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: ClampingScrollPhysics(),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: List.generate(
                                          artist.albums.length > 10
                                              ? 10
                                              : artist.albums.length, (i) {
                                        //Top albums
                                        Album a = artist.albums[i];
                                        return LargeAlbumTile(a);
                                      })),
                                ))
                          ]),
                        ),
                        ListenableBuilder(
                            listenable: playerBarState,
                            builder: (BuildContext context, Widget? child) {
                              return AnimatedPadding(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.only(
                                    bottom: playerBarState.state ? 80 : 5),
                              );
                            }),
                      ],
                    );
                  }));
  }
}

class DiscographyScreen extends StatefulWidget {
  final Artist artist;
  const DiscographyScreen({required this.artist, super.key});

  @override
  _DiscographyScreenState createState() => _DiscographyScreenState();
}

class _DiscographyScreenState extends State<DiscographyScreen> {
  late Artist artist;
  bool _isLoading = false;
  bool _error = false;
  final List<ScrollController> _controllers = [
    ScrollController(),
    ScrollController(),
    ScrollController()
  ];

  Future _load() async {
    if (artist.albums.length >= (artist.albumCount ?? 0) || _isLoading) return;
    setState(() => _isLoading = true);

    //Fetch data
    List<Album> data;
    try {
      data = await deezerAPI.discographyPage(artist.id ?? '',
          start: artist.albums.length);
    } catch (e) {
      setState(() {
        _error = true;
        _isLoading = false;
      });
      return;
    }

    //Save
    setState(() {
      artist.albums.addAll(data);
      _isLoading = false;
    });
  }

  //Get album tile
  Widget _tile(Album a) => AlbumTile(
        a,
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => AlbumDetails(a))),
        onHold: () {
          MenuSheet m = MenuSheet();
          m.defaultAlbumMenu(a, context: context);
        },
      );

  Widget get _isLoadingWidget {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator()],
        ),
      );
    }
    //Error
    if (_error) return const ErrorScreen();
    //Success
    return const SizedBox(
      width: 0,
      height: 0,
    );
  }

  @override
  void initState() {
    artist = widget.artist;

    //Lazy loading scroll
    for (var c in _controllers) {
      c.addListener(() {
        double off = c.position.maxScrollExtent * 0.85;
        if (c.position.pixels > off) _load();
      });
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 3,
        child: Builder(builder: (BuildContext context) {
          final TabController tabController = DefaultTabController.of(context);
          tabController.addListener(() {
            if (!tabController.indexIsChanging) {
              //Load data if empty tabs
              int nSingles =
                  artist.albums.where((a) => a.type == AlbumType.SINGLE).length;
              int nFeatures = artist.albums
                  .where((a) => a.type == AlbumType.FEATURED)
                  .length;
              if ((nSingles == 0 || nFeatures == 0) && !_isLoading) _load();
            }
          });

          return Scaffold(
            appBar: FreezerAppBar(
              'Discography'.i18n,
              bottom: TabBar(
                tabs: [
                  Tab(
                      icon: Icon(
                    Icons.album,
                    semanticLabel: 'Albums'.i18n,
                  )),
                  Tab(
                      icon: Icon(Icons.audiotrack,
                          semanticLabel: 'Singles'.i18n)),
                  Tab(
                      icon: Icon(
                    Icons.recent_actors,
                    semanticLabel: 'Featured'.i18n,
                  ))
                ],
              ),
              height: 100.0,
            ),
            body: TabBarView(
              children: [
                //Albums
                ListView.builder(
                  controller: _controllers[0],
                  itemCount: artist.albums.length + 1,
                  itemBuilder: (context, i) {
                    if (i == artist.albums.length) return _isLoadingWidget;
                    if (artist.albums[i].type == AlbumType.ALBUM) {
                      return _tile(artist.albums[i]);
                    }
                    return const SizedBox(
                      width: 0,
                      height: 0,
                    );
                  },
                ),
                //Singles
                ListView.builder(
                  controller: _controllers[1],
                  itemCount: artist.albums.length + 1,
                  itemBuilder: (context, i) {
                    if (i == artist.albums.length) return _isLoadingWidget;
                    if (artist.albums[i].type == AlbumType.SINGLE) {
                      return _tile(artist.albums[i]);
                    }
                    return const SizedBox(
                      width: 0,
                      height: 0,
                    );
                  },
                ),
                //Featured
                ListView.builder(
                  controller: _controllers[2],
                  itemCount: artist.albums.length + 1,
                  itemBuilder: (context, i) {
                    if (i == artist.albums.length) return _isLoadingWidget;
                    if (artist.albums[i].type == AlbumType.FEATURED) {
                      return _tile(artist.albums[i]);
                    }
                    return const SizedBox(
                      width: 0,
                      height: 0,
                    );
                  },
                ),
              ],
            ),
          );
        }));
  }
}

class PlaylistDetails extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetails(this.playlist, {super.key});

  @override
  _PlaylistDetailsState createState() => _PlaylistDetailsState();
}

class _PlaylistDetailsState extends State<PlaylistDetails> {
  late Playlist playlist;
  bool _isLoading = false;
  bool _isLoadingTracks = false;
  bool _error = false;
  final ScrollController _scrollController = ScrollController();
  final PageController _playlistController = PageController();
  int _currentPage = 0;
  bool isLibrary = false;

  //Load cached playlist sorting
  void _restoreSort() async {
    //Find index
    int? index = Sorting.index(SortSourceTypes.PLAYLIST, id: playlist.id);
    if (index == null) return;

    //Preload tracks
    if ((playlist.tracks?.length ?? 0) < (playlist.trackCount ?? 0)) {
      playlist = await deezerAPI.fullPlaylist(playlist.id ?? '');
    }
  }

  Future _isLibrary() async {
    if (playlist.isIn(await downloadManager.getOfflinePlaylists())) {
      setState(() {
        isLibrary = true;
      });
      return;
    }
    if (playlist.isIn(await deezerAPI.getPlaylists())) {
      setState(() {
        isLibrary = true;
      });
      return;
    }
  }

  void _loadTracks() async {
    // Got all tracks, return
    if (_isLoadingTracks ||
        (playlist.tracks?.length ?? 0) >=
            (playlist.trackCount ?? playlist.tracks?.length ?? 0)) {
      return;
    }

    setState(() => _isLoadingTracks = true);
    int pos = playlist.tracks?.length ?? 0;
    //Get another page of tracks
    List<Track> tracks;
    try {
      tracks =
          await deezerAPI.playlistTracksPage(playlist.id ?? '', pos, nb: 25);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _isLoadingTracks = false;
        });
      }
      return;
    }

    setState(() {
      playlist.tracks?.addAll(tracks);
      _isLoadingTracks = false;
    });
  }

  Future _load() async {
    setState(() => _isLoading = true);

    // Initial load if no tracks
    if (playlist.tracks?.isEmpty ?? true) {
      //If playlist is offline
      Playlist? offlinePlaylist = await downloadManager
          .getOfflinePlaylist(playlist.id ?? '')
          .catchError((e) {
        setState(() {
          _error = true;
        });
        return null;
      });
      if (offlinePlaylist?.tracks?.isNotEmpty ?? false) {
        setState(() {
          playlist = offlinePlaylist ?? Playlist();
          _isLoading = false;
        });

        //Try to update offline playlist
        Playlist? fullPlaylist =
            await deezerAPI.fullPlaylist(playlist.id ?? '');
        if (fullPlaylist.tracks != offlinePlaylist?.tracks &&
            (fullPlaylist.tracks?.isNotEmpty ?? false)) {
          setState(() {
            playlist = fullPlaylist;
          });
          await downloadManager.updateOfflinePlaylist(playlist);
        }
      } else {
        //If playlist is not offline
        Playlist? onlinePlaylist =
            await deezerAPI.playlist(playlist.id ?? '', nb: 25).catchError((e) {
          setState(() {
            _error = true;
          });
          return Playlist();
        });
        setState(() {
          playlist = onlinePlaylist;
          _isLoading = false;
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    playlist = widget.playlist;

    _load();

    _isLibrary();
    _restoreSort();
    super.initState();

    _scrollController.addListener(() {
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off &&
          widget.playlist.tracks?.length != widget.playlist.trackCount) {
        _loadTracks();
      }
    });

    _playlistController.addListener(() {
      setState(() {
        _currentPage = _playlistController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _error
            ? const ErrorScreen()
            : _isLoading
                ? SplashScreen()
                : OrientationBuilder(builder: (context, orientation) {
                    //Responsive
                    ScreenUtil.init(context, minTextAdapt: true);
                    //Landscape
                    if (orientation == Orientation.landscape) {
                      // ignore: prefer_const_constructors
                      return SafeArea(
                          child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width * 0.4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 4.0),
                                    child: ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        horizontalTitleGap: 8.0,
                                        leading: IconButton(
                                            onPressed: () async {
                                              await Navigator.of(context)
                                                  .maybePop();
                                            },
                                            icon: Icon(Icons.arrow_back)),
                                        title: Text(
                                          playlist.title ?? '',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18.0),
                                        ),
                                        subtitle: Text(
                                          playlist.user?.name ?? '',
                                          style: TextStyle(
                                              fontSize: 14.0,
                                              color: Settings.secondaryText),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(AlchemyIcons.more_vert),
                                          onPressed: () {
                                            MenuSheet m = MenuSheet();
                                            m.defaultPlaylistMenu(playlist,
                                                context: context);
                                          },
                                        ))),
                                SizedBox(
                                    width: MediaQuery.of(context).size.height *
                                        0.5,
                                    height: MediaQuery.of(context).size.height *
                                        0.5,
                                    child: Stack(
                                      children: [
                                        PageView(
                                          controller: _playlistController,
                                          onPageChanged: (index) {
                                            setState(() {
                                              _currentPage = index;
                                            });
                                          },
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Stack(
                                                  children: [
                                                    CachedImage(
                                                      url: playlist
                                                              .image?.full ??
                                                          '',
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height *
                                                              0.5,
                                                      fullThumb: true,
                                                      rounded: true,
                                                    ),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                            decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                    colors: [
                                                                      Theme.of(
                                                                              context)
                                                                          .scaffoldBackgroundColor
                                                                          .withAlpha(
                                                                              150),
                                                                      Colors
                                                                          .transparent
                                                                    ],
                                                                    begin: Alignment
                                                                        .bottomCenter,
                                                                    end: Alignment
                                                                        .topCenter,
                                                                    stops: [
                                                                      0.0,
                                                                      0.7
                                                                    ])),
                                                            child: SizedBox(
                                                              width: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .height *
                                                                  0.5,
                                                              height: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .height *
                                                                  0.1,
                                                            )),
                                                      ],
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                            Container(
                                                clipBehavior: Clip.hardEdge,
                                                decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .scaffoldBackgroundColor,
                                                    border: Border.all(
                                                        color: Theme.of(context)
                                                            .scaffoldBackgroundColor
                                                            .withAlpha(0)),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5)),
                                                child: ListView(
                                                  children: [
                                                    ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity(
                                                              horizontal: 0.0,
                                                              vertical: -4),
                                                      minVerticalPadding: 0,
                                                      title: Text(
                                                        'Tracks'.i18n,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                      subtitle: Text(
                                                          (playlist.tracks
                                                                  ?.length)
                                                              .toString(),
                                                          style: TextStyle(
                                                              color: Settings
                                                                  .secondaryText,
                                                              fontSize: 12)),
                                                    ),
                                                    ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity(
                                                              horizontal: 0.0,
                                                              vertical: -4),
                                                      minVerticalPadding: 0,
                                                      title: Text(
                                                        'Duration'.i18n,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                      subtitle: Text(
                                                          playlist
                                                              .durationString,
                                                          style: TextStyle(
                                                              color: Settings
                                                                  .secondaryText,
                                                              fontSize: 12)),
                                                    ),
                                                    ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity(
                                                              horizontal: 0.0,
                                                              vertical: -4),
                                                      minVerticalPadding: 0,
                                                      title: Text(
                                                        'Fans'.i18n,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                      subtitle: Text(
                                                          (playlist.fans ?? 0)
                                                              .toString(),
                                                          style: TextStyle(
                                                              color: Settings
                                                                  .secondaryText,
                                                              fontSize: 12)),
                                                    ),
                                                  ],
                                                ))
                                          ],
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(top: 8.0),
                                              child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: List.generate(
                                                      2,
                                                      (i) => Container(
                                                            margin: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        2.0,
                                                                    vertical:
                                                                        8.0),
                                                            width: 12.0,
                                                            height: 4.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .white
                                                                  .withAlpha(
                                                                      _currentPage ==
                                                                              i
                                                                          ? 255
                                                                          : 150),
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .transparent),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          100),
                                                            ),
                                                          ))),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4.0, horizontal: 6.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          if (playlist.user?.id !=
                                              deezerAPI.userId)
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: IconButton(
                                                icon: isLibrary
                                                    ? Icon(
                                                        AlchemyIcons.heart_fill,
                                                        size: 25,
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        semanticLabel:
                                                            'Unlove'.i18n,
                                                      )
                                                    : Icon(
                                                        AlchemyIcons.heart,
                                                        size: 25,
                                                        semanticLabel:
                                                            'Love'.i18n,
                                                      ),
                                                onPressed: () async {
                                                  //Add to library
                                                  if (!isLibrary) {
                                                    await deezerAPI.addPlaylist(
                                                        playlist.id ?? '');
                                                    Fluttertoast.showToast(
                                                        msg: 'Added to library'
                                                            .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() => playlist
                                                        .library = true);
                                                    return;
                                                  }
                                                  //Remove
                                                  await deezerAPI
                                                      .removePlaylist(
                                                          playlist.id ?? '');
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Playlist removed from library!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                  setState(() =>
                                                      playlist.library = false);
                                                },
                                              ),
                                            ),
                                          IconButton(
                                              onPressed: () => {
                                                    Share.share(
                                                        'https://deezer.com/playlist/' +
                                                            (playlist.id ?? ''))
                                                  },
                                              icon: Icon(
                                                AlchemyIcons.share_android,
                                                size: 20.0,
                                              )),
                                          Padding(
                                            padding: EdgeInsets.only(left: 8.0),
                                            child:
                                                MakePlaylistOffline(playlist),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            margin: EdgeInsets.only(right: 6.0),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            child: IconButton(
                                                onPressed: () async {
                                                  Navigator.of(context,
                                                          rootNavigator: true)
                                                      .push(MaterialPageRoute(
                                                          builder: (context) =>
                                                              BlindTestChoiceScreen(
                                                                  playlist)));
                                                },
                                                icon: Icon(
                                                  AlchemyIcons.music_quiz,
                                                  size: 20,
                                                )),
                                          ),
                                          Container(
                                            margin: EdgeInsets.only(right: 6.0),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            child: IconButton(
                                                onPressed: () async {
                                                  List<Track> tracklist =
                                                      List.from(
                                                          playlist.tracks ??
                                                              []);
                                                  if (playlist.trackCount !=
                                                      tracklist.length) {
                                                    playlist = await deezerAPI
                                                        .fullPlaylist(
                                                            playlist.id ?? '');
                                                    tracklist = List.from(
                                                        playlist.tracks ?? []);
                                                  }
                                                  tracklist.shuffle();
                                                  GetIt.I<AudioPlayerHandler>()
                                                      .playFromTrackList(
                                                          tracklist,
                                                          tracklist[0].id ?? '',
                                                          QueueSource(
                                                              id: playlist.id,
                                                              source: playlist
                                                                  .title,
                                                              text: playlist
                                                                      .title ??
                                                                  'Playlist' +
                                                                      ' shuffle'
                                                                          .i18n));
                                                  tracklist.shuffle();
                                                  GetIt.I<AudioPlayerHandler>()
                                                      .playFromTrackList(
                                                          tracklist,
                                                          tracklist[0].id ?? '',
                                                          QueueSource(
                                                              id: playlist.id,
                                                              source: playlist
                                                                  .title,
                                                              text: playlist
                                                                      .title ??
                                                                  'Playlist' +
                                                                      ' shuffle'
                                                                          .i18n));
                                                },
                                                icon: Icon(
                                                  AlchemyIcons.shuffle,
                                                  size: 18,
                                                )),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: _scrollController,
                              children: [
                                ...List.generate((playlist.tracks?.length ?? 0),
                                    (i) {
                                  Track t = (playlist.tracks ?? [])[i];
                                  return TrackTile(t, onTap: () async {
                                    (playlist.trackCount !=
                                                playlist.tracks?.length &&
                                            await isConnected())
                                        ? deezerAPI
                                            .fullPlaylist(playlist.id ?? '')
                                            .then((Playlist p) => {
                                                  GetIt.I<AudioPlayerHandler>()
                                                      .playFromPlaylist(
                                                          Playlist(
                                                              title: p.title,
                                                              id: p.id,
                                                              tracks: p.tracks),
                                                          t.id ?? '')
                                                })
                                        : GetIt.I<AudioPlayerHandler>()
                                            .playFromPlaylist(
                                                Playlist(
                                                    title: playlist.title,
                                                    id: playlist.id,
                                                    tracks: playlist.tracks),
                                                t.id ?? '');
                                  }, onHold: () async {
                                    MenuSheet m = MenuSheet();
                                    m.defaultTrackMenu(t,
                                        context: context,
                                        options: [
                                          (playlist.user?.id ==
                                                      deezerAPI.userId &&
                                                  playlist.id !=
                                                      cache.favoritesPlaylistId)
                                              ? m.removeFromPlaylist(
                                                  t, playlist, context, () {
                                                  setState(() {
                                                    playlist.tracks = playlist
                                                        .tracks
                                                        ?.where((track) =>
                                                            track.id != t.id)
                                                        .toList();
                                                  });
                                                })
                                              : const SizedBox(
                                                  width: 0,
                                                  height: 0,
                                                )
                                        ],
                                        onRemove: playlist.id ==
                                                cache.favoritesPlaylistId
                                            ? () {
                                                setState(() {
                                                  playlist.tracks = playlist
                                                      .tracks
                                                      ?.where((track) =>
                                                          track.id != t.id)
                                                      .toList();
                                                });
                                              }
                                            : null);
                                  });
                                }),
                                if (_isLoadingTracks)
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        CircularProgressIndicator(
                                          color: Theme.of(context).primaryColor,
                                        )
                                      ],
                                    ),
                                  ),
                                if (_error &&
                                    playlist.tracks?.length !=
                                        playlist.trackCount)
                                  const ErrorScreen(),
                                ListenableBuilder(
                                    listenable: playerBarState,
                                    builder:
                                        (BuildContext context, Widget? child) {
                                      return AnimatedPadding(
                                        duration: Duration(milliseconds: 200),
                                        padding: EdgeInsets.only(
                                            bottom:
                                                playerBarState.state ? 80 : 0),
                                      );
                                    }),
                              ],
                            ),
                          ),
                        ],
                      ));
                    }
                    //Portrait
                    // ignore: prefer_const_constructors
                    return ListView(
                      controller: _scrollController,
                      children: <Widget>[
                        SizedBox(
                            width: double.infinity,
                            height: MediaQuery.of(context).size.width,
                            child: Stack(
                              children: [
                                PageView(
                                  controller: _playlistController,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                  },
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Stack(
                                          children: [
                                            CachedImage(
                                              url: playlist.image?.full ?? '',
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width,
                                              fullThumb: true,
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                          colors: [
                                                            Theme.of(context)
                                                                .scaffoldBackgroundColor
                                                                .withAlpha(150),
                                                            Theme.of(context)
                                                                .scaffoldBackgroundColor
                                                                .withAlpha(0)
                                                          ],
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                          stops: [0.0, 0.7])),
                                                  child: SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width /
                                                            6,
                                                  ),
                                                ),
                                                Container(
                                                    decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                                colors: [
                                                                  Theme.of(
                                                                          context)
                                                                      .scaffoldBackgroundColor
                                                                      .withAlpha(
                                                                          150),
                                                                  Theme.of(
                                                                          context)
                                                                      .scaffoldBackgroundColor
                                                                      .withAlpha(
                                                                          0)
                                                                ],
                                                                begin: Alignment
                                                                    .bottomCenter,
                                                                end: Alignment
                                                                    .topCenter,
                                                                stops: [
                                                                  0.0,
                                                                  0.7
                                                                ])),
                                                    child: SizedBox(
                                                      width:
                                                          MediaQuery.of(context)
                                                              .size
                                                              .width,
                                                      height:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width /
                                                              6,
                                                    )),
                                              ],
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ListTile(
                                              minVerticalPadding: 1,
                                              leading: Icon(
                                                AlchemyIcons.album,
                                                size: 25,
                                              ),
                                              title: Text(
                                                'Tracks'.i18n,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              subtitle: Text(
                                                  (playlist.trackCount ??
                                                          playlist
                                                              .tracks?.length ??
                                                          0)
                                                      .toString(),
                                                  style: TextStyle(
                                                      color: Settings
                                                          .secondaryText,
                                                      fontSize: 12)),
                                            ),
                                            ListTile(
                                              minVerticalPadding: 1,
                                              leading: Icon(
                                                AlchemyIcons.clock,
                                                size: 25,
                                              ),
                                              title: Text(
                                                'Duration'.i18n,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              subtitle: Text(
                                                  playlist.durationString,
                                                  style: TextStyle(
                                                      color: Settings
                                                          .secondaryText,
                                                      fontSize: 12)),
                                            ),
                                            ListTile(
                                              minVerticalPadding: 1,
                                              leading: Icon(
                                                AlchemyIcons.heart,
                                                size: 25,
                                              ),
                                              title: Text(
                                                'Fans'.i18n,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              subtitle: Text(
                                                  (NumberFormat.decimalPattern()
                                                          .format(
                                                              playlist.fans ??
                                                                  0))
                                                      .toString(),
                                                  style: TextStyle(
                                                      color: Settings
                                                          .secondaryText,
                                                      fontSize: 12)),
                                            ),
                                          ],
                                        ))
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          IconButton(
                                              onPressed: () async {
                                                await customNavigatorKey
                                                    .currentState!
                                                    .maybePop();
                                              },
                                              icon: Icon(Icons.arrow_back)),
                                          IconButton(
                                            icon: Icon(AlchemyIcons.more_vert),
                                            onPressed: () {
                                              MenuSheet m = MenuSheet();
                                              m.defaultPlaylistMenu(playlist,
                                                  context: context);
                                            },
                                          )
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: List.generate(
                                              2,
                                              (i) => Container(
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 2.0,
                                                            vertical: 8.0),
                                                    width: 12.0,
                                                    height: 4.0,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withAlpha(
                                                              _currentPage == i
                                                                  ? 255
                                                                  : 150),
                                                      border: Border.all(
                                                          color: Colors
                                                              .transparent),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              100),
                                                    ),
                                                  ))),
                                    ),
                                  ],
                                ),
                              ],
                            )),
                        Padding(
                            padding: EdgeInsets.fromLTRB(4.0, 16.0, 4.0, 4.0),
                            child: ListTile(
                              title: Text(
                                playlist.title ?? '',
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.start,
                                maxLines: 1,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 40.0,
                                    fontWeight: FontWeight.w900),
                              ),
                              subtitle: Text(
                                playlist.user?.name ?? '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                    color: Settings.secondaryText,
                                    fontSize: 14.0),
                              ),
                            )),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.max,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (playlist.user?.id != deezerAPI.userId)
                                    Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: IconButton(
                                        icon: isLibrary
                                            ? Icon(
                                                AlchemyIcons.heart_fill,
                                                size: 25,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                semanticLabel: 'Unlove'.i18n,
                                              )
                                            : Icon(
                                                AlchemyIcons.heart,
                                                size: 25,
                                                semanticLabel: 'Love'.i18n,
                                              ),
                                        onPressed: () async {
                                          //Add to library
                                          if (!isLibrary) {
                                            await deezerAPI
                                                .addPlaylist(playlist.id!);
                                            Fluttertoast.showToast(
                                                msg: 'Added to library'.i18n,
                                                toastLength: Toast.LENGTH_SHORT,
                                                gravity: ToastGravity.BOTTOM);
                                            setState(
                                                () => playlist.library = true);
                                            return;
                                          }
                                          //Remove
                                          await deezerAPI
                                              .removePlaylist(playlist.id!);
                                          Fluttertoast.showToast(
                                              msg:
                                                  'Playlist removed from library!'
                                                      .i18n,
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.BOTTOM);
                                          setState(
                                              () => playlist.library = false);
                                        },
                                      ),
                                    ),
                                  IconButton(
                                      onPressed: () => {
                                            Share.share(
                                                'https://deezer.com/playlist/' +
                                                    (playlist.id ?? ''))
                                          },
                                      icon: Icon(
                                        AlchemyIcons.share_android,
                                        size: 20.0,
                                      )),
                                  Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: MakePlaylistOffline(playlist),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(right: 6.0),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .scaffoldBackgroundColor
                                              .withAlpha(0)),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: IconButton(
                                        onPressed: () async {
                                          Navigator.of(context,
                                                  rootNavigator: true)
                                              .push(MaterialPageRoute(
                                                  builder: (context) =>
                                                      BlindTestChoiceScreen(
                                                          playlist)));
                                        },
                                        icon: Icon(
                                          AlchemyIcons.music_quiz,
                                          size: 20,
                                        )),
                                  ),
                                  Container(
                                    margin: EdgeInsets.only(right: 6.0),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .scaffoldBackgroundColor
                                              .withAlpha(0)),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: IconButton(
                                        onPressed: () async {
                                          List<Track> tracklist =
                                              List.from(playlist.tracks ?? []);
                                          if (playlist.trackCount !=
                                                  tracklist.length &&
                                              await isConnected()) {
                                            playlist =
                                                await deezerAPI.fullPlaylist(
                                                    playlist.id ?? '');
                                            tracklist = List.from(
                                                playlist.tracks ?? []);
                                          }
                                          tracklist.shuffle();
                                          GetIt.I<AudioPlayerHandler>()
                                              .playFromTrackList(
                                                  tracklist,
                                                  tracklist[0].id ?? '',
                                                  QueueSource(
                                                      id: playlist.id,
                                                      source: playlist.title,
                                                      text: playlist.title ??
                                                          'Playlist' +
                                                              ' shuffle'.i18n));
                                          tracklist.shuffle();
                                          GetIt.I<AudioPlayerHandler>()
                                              .playFromTrackList(
                                                  tracklist,
                                                  tracklist[0].id ?? '',
                                                  QueueSource(
                                                      id: playlist.id,
                                                      source: playlist.title,
                                                      text: playlist.title ??
                                                          'Playlist' +
                                                              ' shuffle'.i18n));
                                        },
                                        icon: Icon(
                                          AlchemyIcons.shuffle,
                                          size: 18,
                                        )),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                        const FreezerDivider(),
                        ...List.generate(playlist.tracks?.length ?? 0, (i) {
                          Track t = playlist.tracks?[i] ?? Track();
                          return TrackTile(t, onTap: () async {
                            (playlist.trackCount != playlist.tracks?.length &&
                                    await isConnected())
                                ? deezerAPI
                                    .fullPlaylist(playlist.id ?? '')
                                    .then((Playlist p) => {
                                          GetIt.I<AudioPlayerHandler>()
                                              .playFromPlaylist(
                                                  Playlist(
                                                      title: p.title,
                                                      id: p.id,
                                                      tracks: p.tracks),
                                                  t.id ?? '')
                                        })
                                : GetIt.I<AudioPlayerHandler>()
                                    .playFromPlaylist(
                                        Playlist(
                                            title: playlist.title,
                                            id: playlist.id,
                                            tracks: playlist.tracks),
                                        t.id ?? '');
                          }, onHold: () {
                            MenuSheet m = MenuSheet();
                            m.defaultTrackMenu(t,
                                context: context,
                                options: [
                                  (playlist.user?.id == deezerAPI.userId &&
                                          playlist.id !=
                                              cache.favoritesPlaylistId)
                                      ? m.removeFromPlaylist(
                                          t, playlist, context, () {
                                          setState(() {
                                            playlist.tracks = playlist.tracks
                                                ?.where(
                                                    (track) => track.id != t.id)
                                                .toList();
                                          });
                                        })
                                      : const SizedBox(
                                          width: 0,
                                          height: 0,
                                        )
                                ],
                                onRemove: playlist.id ==
                                        cache.favoritesPlaylistId
                                    ? () {
                                        setState(() {
                                          playlist.tracks = playlist.tracks
                                              ?.where(
                                                  (track) => track.id != t.id)
                                              .toList();
                                        });
                                      }
                                    : null);
                          });
                        }),
                        if (_isLoadingTracks)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                )
                              ],
                            ),
                          ),
                        if (_error &&
                            playlist.tracks?.length != playlist.trackCount)
                          const ErrorScreen(),
                        ListenableBuilder(
                            listenable: playerBarState,
                            builder: (BuildContext context, Widget? child) {
                              return AnimatedPadding(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.only(
                                    bottom: playerBarState.state ? 80 : 0),
                              );
                            }),
                      ],
                    );
                  }));
  }
}

class MakePlaylistOffline extends StatefulWidget {
  final Playlist playlist;
  const MakePlaylistOffline(this.playlist, {super.key});

  @override
  _MakePlaylistOfflineState createState() => _MakePlaylistOfflineState();
}

class _MakePlaylistOfflineState extends State<MakePlaylistOffline> {
  late Playlist playlist;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    downloadManager.checkOffline(playlist: widget.playlist).then((v) {
      setState(() {
        _offline = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () async {
          if (!_offline) {
            //Add to offline
            if (widget.playlist.user?.id != deezerAPI.userId) {
              await deezerAPI.addPlaylist(widget.playlist.id!);
            }
            downloadManager.addOfflinePlaylist(widget.playlist, private: true);
            MenuSheet().showDownloadStartedToast();
            setState(() {
              _offline = true;
            });
            return;
          }
          downloadManager.removeOfflinePlaylist(widget.playlist.id!);
          Fluttertoast.showToast(
              msg: 'Playlist removed from offline!'.i18n,
              gravity: ToastGravity.BOTTOM,
              toastLength: Toast.LENGTH_SHORT);
          setState(() {
            _offline = false;
          });
        },
        icon: _offline
            ? Icon(
                AlchemyIcons.download_fill,
                size: 25,
                color: Theme.of(context).primaryColor,
              )
            : Icon(
                AlchemyIcons.download,
                size: 25,
              ));
  }
}

class ShowScreen extends StatefulWidget {
  final Show show;
  const ShowScreen(this.show, {super.key});

  @override
  _ShowScreenState createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> {
  late Show _show;
  bool _isLoading = true;
  bool _error = false;
  late List<ShowEpisode> _episodes;

  Future _load() async {
    //Fetch
    List<ShowEpisode> e;
    try {
      e = await deezerAPI.allShowEpisodes(_show.id!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = true;
      });
      return;
    }
    setState(() {
      _episodes = e;
      _isLoading = false;
    });
  }

  @override
  void initState() {
    _show = widget.show;
    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar(_show.name!),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                CachedImage(
                  url: _show.art?.full ?? '',
                  rounded: true,
                  width: MediaQuery.of(context).size.width / 2 - 16,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 2 - 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(_show.name!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20.0, fontWeight: FontWeight.bold)),
                      Container(height: 8.0),
                      Text(
                        _show.description ?? '',
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16.0),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(height: 4.0),
          const FreezerDivider(),

          //Error
          if (_error) const ErrorScreen(),

          //Loading
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [CircularProgressIndicator()],
              ),
            ),

          //Data
          if (!_isLoading && !_error)
            ...List.generate(_episodes.length, (i) {
              ShowEpisode e = _episodes[i];
              return ShowEpisodeTile(
                e,
                trailing: IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    semanticLabel: 'Options'.i18n,
                  ),
                  onPressed: () {
                    MenuSheet m = MenuSheet();
                    m.defaultShowEpisodeMenu(_show, e, context: context);
                  },
                ),
                onTap: () async {
                  await GetIt.I<AudioPlayerHandler>()
                      .playShowEpisode(_show, _episodes, index: i);
                },
              );
            }),
          ListenableBuilder(
              listenable: playerBarState,
              builder: (BuildContext context, Widget? child) {
                return AnimatedPadding(
                  duration: Duration(milliseconds: 200),
                  padding:
                      EdgeInsets.only(bottom: playerBarState.state ? 80 : 0),
                );
              }),
        ],
      ),
    );
  }
}
