import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:deezer/fonts/alchemy_icons.dart';

import '../api/deezer.dart';
import '../api/definitions.dart';
import '../service/audio_service.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/error.dart';

class LyricsScreen extends StatefulWidget {
  final Lyrics? lyrics;
  final Track track;

  const LyricsScreen({this.lyrics, required this.track, super.key});

  @override
  _LyricsScreenState createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  String appBarTitle = 'Lyrics'.i18n;
  Lyrics? lyrics;
  bool _loading = true;
  bool _error = false;
  int _currentIndex = 0;
  int _prevIndex = 0;
  Timer? _timer;
  final ScrollController _controller = ScrollController();
  StreamSubscription? _mediaItemSub;
  final double height = 90;
  List<double> progress = [0, 0];

  @override
  void initState() {
    super.initState();
    _load();

    //Enable visualizer
    if (settings.lyricsVisualizer) {
      GetIt.I<AudioPlayerHandler>().startVisualizer();
    }

    //Track change = exit lyrics
    _mediaItemSub = GetIt.I<AudioPlayerHandler>().mediaItem.listen((event) {
      if (event?.id != widget.track.id) Navigator.of(context).pop();
    });
  }

  Future _load() async {
    if (widget.lyrics?.isLoaded() == true) {
      _updateLyricsState(widget.lyrics!);
      return;
    }

    try {
      Lyrics l = await deezerAPI.lyrics(widget.track);
      _updateLyricsState(l);
    } catch (e) {
      _timer?.cancel();
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _updateLyricsState(Lyrics lyrics) {
    String screenTitle = 'Lyrics'.i18n;

    if (lyrics.isSynced()) {
      _startSyncTimer();
    } else if ((lyrics.isUnsynced())) {
      screenTitle = 'Unsynchronized lyrics'.i18n;
      _timer?.cancel();
    }

    if (lyrics.errorMessage != null) {
      Logger.root.warning(
          'Error loading lyrics for track id ${widget.track.id}: ${lyrics.errorMessage}');
    }

    setState(() {
      appBarTitle = screenTitle;
      this.lyrics = lyrics;
      _loading = false;
      _error = false;
    });
  }

  void _startSyncTimer() {
    Timer.periodic(const Duration(milliseconds: 350), (timer) {
      _timer = timer;
      if (_loading) return;

      setState(() {
        progress = [
          progress[1],
          min(
              GetIt.I<AudioPlayerHandler>()
                      .playbackState
                      .value
                      .position
                      .inSeconds /
                  (lyrics?.syncedLyrics?.first.offset?.inSeconds ?? 1),
              1)
        ];
        if (progress == [1, 1] || progress[0] > progress[1]) timer.cancel();
      });

      //Update current lyric index
      setState(() => _currentIndex = lyrics!.syncedLyrics!.lastIndexWhere(
          (lyric) =>
              (lyric.offset ?? const Duration(seconds: 0)) <=
              GetIt.I<AudioPlayerHandler>().playbackState.value.position));

      //Scroll to current lyric
      if (_currentIndex <= 0) return;
      if (_prevIndex == _currentIndex) return;
      _prevIndex = _currentIndex;
      _controller.animateTo(
          //Lyric height, screen height, appbar height
          max((height * (_currentIndex)) + 56, 0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.ease);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mediaItemSub?.cancel();
    _controller.dispose();
    //Stop visualizer
    if (settings.lyricsVisualizer) {
      GetIt.I<AudioPlayerHandler>().stopVisualizer();
    }
    //Fix bottom buttons
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: settings.themeData.scaffoldBackgroundColor,
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Stack(
      children: [
        //Visualizer
        if (settings.lyricsVisualizer)
          Align(
            alignment: Alignment.bottomCenter,
            child: StreamBuilder(
                stream: GetIt.I<AudioPlayerHandler>().visualizerStream,
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  List<double> data = snapshot.data ?? [];
                  double width =
                      MediaQuery.of(context).size.width / data.length - 0.25;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                        data.length,
                        (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 130),
                              color: Theme.of(context).primaryColor,
                              height: data[i] * 100,
                              width: width,
                            )),
                  );
                }),
          ),

        //Lyrics

        Padding(
          padding:
              EdgeInsets.fromLTRB(0, 0, 0, settings.lyricsVisualizer ? 100 : 0),
          child: ListView(
            controller: _controller,
            children: [
              //Shouldn't really happen, empty lyrics have own text
              if (_error) const ErrorScreen(),

              //Loading
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CircularProgressIndicator()],
                  ),
                ),

              SizedBox(
                height: MediaQuery.of(context).size.height / 2 - height / 2,
                child: Align(
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: Align(
                          alignment: Alignment.center,
                          child: Icon(AlchemyIcons.microphone),
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: progress[0], end: progress[1]),
                          duration: Duration(milliseconds: 350),
                          builder: (context, value, _) =>
                              CircularProgressIndicator(
                            value: value,
                            strokeWidth: 1,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Synced Lyrics
              if (lyrics != null && lyrics!.syncedLyrics?.isNotEmpty == true)
                ...List.generate(lyrics!.syncedLyrics!.length, (i) {
                  return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            color: (_currentIndex == i &&
                                    lyrics!.syncedLyrics![i].text != '')
                                ? Colors.grey.withAlpha(75)
                                : Colors.transparent,
                          ),
                          height: height,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                final offset = lyrics!.syncedLyrics![i].offset;
                                if (offset != null) {
                                  GetIt.I<AudioPlayerHandler>().seek(offset);
                                }
                              },
                              child: Text(
                                lyrics!.syncedLyrics![i].text ?? '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26.0,
                                  fontWeight: (_currentIndex == i)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          )));
                }),

              // Unsynced Lyrics
              if (lyrics != null &&
                  (lyrics!.syncedLyrics?.isEmpty ?? true) &&
                  lyrics!.unsyncedLyrics != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Center(
                      child: Text(
                        lyrics!.unsyncedLyrics!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26.0,
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                height: MediaQuery.of(context).size.height / 2 - height / 2,
              ),
            ],
          ),
        ),

        Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: IconButton(
                            onPressed: () {
                              Navigator.of(context).canPop()
                                  ? Navigator.of(context).pop()
                                  : null;
                            },
                            icon: Icon(AlchemyIcons.cross)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              GetIt.I<AudioPlayerHandler>()
                                      .mediaItem
                                      .value
                                      ?.title ??
                                  '',
                              style: TextStyle(
                                  fontSize: 16.0, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              GetIt.I<AudioPlayerHandler>()
                                      .mediaItem
                                      .value
                                      ?.artist ??
                                  '',
                              style: TextStyle(
                                  fontSize: 12.0,
                                  color: Settings.secondaryText),
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: IconButton(
                            onPressed: () {},
                            icon: Icon(
                              AlchemyIcons.heart,
                              color: Colors.white.withOpacity(0),
                            )),
                      ),
                    ]),
              ),
            )
          ],
        )
      ],
    )));
  }
}
