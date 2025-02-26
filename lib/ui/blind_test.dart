import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:deezer/api/cache.dart';
import 'package:deezer/api/deezer.dart';
import 'package:deezer/api/definitions.dart';
import 'package:deezer/fonts/alchemy_icons.dart';
import 'package:deezer/main.dart';
import 'package:deezer/service/audio_service.dart';
import 'package:deezer/settings.dart';
import 'package:deezer/translations.i18n.dart';
import 'package:deezer/ui/cached_image.dart';
import 'package:deezer/ui/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:logging/logging.dart';

class BlindTestChoiceScreen extends StatefulWidget {
  final Playlist playlist;
  const BlindTestChoiceScreen(this.playlist, {super.key});

  @override
  _BlindTestChoiceScreen createState() => _BlindTestChoiceScreen();
}

class _BlindTestChoiceScreen extends State<BlindTestChoiceScreen> {
  int bestScore = 0;
  int rank = 1;

  Future<void> _score() async {
    //Get best score
    if (settings.blindTestType == BlindTestType.DEEZER) {
      Map<String, dynamic> score = await deezerAPI.callPipeApi(params: {
        'operationName': 'Score',
        'query':
            'query Score(\$id: String!) {\n  me {\n    games {\n      blindTest {\n        bestScore(id: \$id, type: PLAYLIST)\n        hasPlayed\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}',
        'variables': {'id': widget.playlist.id}
      });

      if (mounted) {
        setState(() {
          bestScore =
              score['data']['me']['games']['blindTest']['bestScore'] ?? 0;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          bestScore = 0;
        });
      }
    }
  }

  Future<void> _rank() async {
    if (settings.blindTestType == BlindTestType.DEEZER) {
      Map<String, dynamic> apiBoard = await deezerAPI.callPipeApi(params: {
        'operationName': 'Leaderboard',
        'query':
            'query Leaderboard(\$blindtestId: String!) {\n  blindTest(id: \$blindtestId, type: PLAYLIST) {\n    ...UserScoreAndRank\n    leaderboard {\n      topRankedPlayers {\n        user {\n          name\n          id\n          picture {\n            ...Picture\n            __typename\n          }\n          __typename\n        }\n        rank\n        bestScore\n        __typename\n      }\n      playersCount\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment UserScoreAndRank on BlindTest {\n  id\n  userRank\n  userBestScore\n  __typename\n}\n\nfragment Picture on Picture {\n  ...PictureSmall\n  ...PictureMedium\n  ...PictureLarge\n  __typename\n}\n\nfragment PictureSmall on Picture {\n  id\n  small: urls(pictureRequest: {height: 100, width: 100})\n  __typename\n}\n\nfragment PictureMedium on Picture {\n  id\n  medium: urls(pictureRequest: {width: 264, height: 264})\n  __typename\n}\n\nfragment PictureLarge on Picture {\n  id\n  large: urls(pictureRequest: {width: 500, height: 500})\n  __typename\n}',
        'variables': {'blindtestId': widget.playlist.id}
      });

      if (mounted) {
        setState(() {
          rank = apiBoard['data']['blindTest']['userRank'] ?? 0;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          rank = 0;
        });
      }
    }
  }

  @override
  void initState() {
    GetIt.I<AudioPlayerHandler>().stop();
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.lightBlue.withAlpha(70)));
    _score();
    _rank();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: settings.themeData.bottomAppBarTheme.color,
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return Scaffold(
        body: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      GetIt.I<AudioPlayerHandler>().stop();
                      GetIt.I<AudioPlayerHandler>().clearQueue();
                      Navigator.of(context).maybePop();
                    },
                    icon: Icon(AlchemyIcons.cross),
                    iconSize: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          widget.playlist.title ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Blind test'.i18n,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          BlindTestType blindTestType = settings.blindTestType;
                          return StatefulBuilder(builder: (context, setState) {
                            return AlertDialog(
                              title: Text('Choose blind test type'.i18n),
                              content: SizedBox(
                                  // Wrap ListView with SizedBox to control its size
                                  width: double
                                      .maxFinite, // Set width to maximum to allow list to expand
                                  child: ListView(
                                    shrinkWrap:
                                        true, //  Important: set shrinkWrap to true for ListView in Dialog
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                            color: blindTestType ==
                                                    BlindTestType.DEEZER
                                                ? Theme.of(context)
                                                            .scaffoldBackgroundColor ==
                                                        Colors.white
                                                    ? Colors.black.withAlpha(70)
                                                    : Colors.white.withAlpha(70)
                                                : Colors.transparent,
                                            border: Border.all(
                                                color: blindTestType ==
                                                        BlindTestType.DEEZER
                                                    ? Theme.of(context)
                                                                .scaffoldBackgroundColor ==
                                                            Colors.white
                                                        ? Colors.black
                                                            .withAlpha(150)
                                                        : Colors.white
                                                            .withAlpha(150)
                                                    : Colors.transparent,
                                                width: 1.5),
                                            borderRadius:
                                                BorderRadius.circular(15)),
                                        clipBehavior: Clip.hardEdge,
                                        child: ListTile(
                                          leading: Image.asset(
                                            'assets/deezer.png',
                                            width: 30,
                                            height: 30,
                                          ),
                                          title: Text(
                                            'Deezer'.i18n,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Official deezer blindtest (premium)',
                                            style: TextStyle(
                                              color: Settings.secondaryText,
                                              fontSize: 14,
                                            ),
                                          ),
                                          onTap: () {
                                            if (mounted) {
                                              setState(() {
                                                settings.blindTestType =
                                                    BlindTestType.DEEZER;
                                                settings.save();
                                                blindTestType =
                                                    BlindTestType.DEEZER;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                            color: blindTestType ==
                                                    BlindTestType.ALCHEMY
                                                ? Theme.of(context)
                                                            .scaffoldBackgroundColor ==
                                                        Colors.white
                                                    ? Colors.black.withAlpha(70)
                                                    : Colors.white.withAlpha(70)
                                                : Colors.transparent,
                                            border: Border.all(
                                                color: blindTestType ==
                                                        BlindTestType.ALCHEMY
                                                    ? Theme.of(context)
                                                                .scaffoldBackgroundColor ==
                                                            Colors.white
                                                        ? Colors.black
                                                            .withAlpha(150)
                                                        : Colors.white
                                                            .withAlpha(150)
                                                    : Colors.transparent,
                                                width: 1.5),
                                            borderRadius:
                                                BorderRadius.circular(15)),
                                        clipBehavior: Clip.hardEdge,
                                        child: ListTile(
                                          leading: Image.asset(
                                            'assets/icon.png',
                                            width: 30,
                                            height: 30,
                                          ),
                                          title: Text(
                                            'Alchemy'.i18n,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Local blind test with extended features',
                                            style: TextStyle(
                                              color: Settings.secondaryText,
                                              fontSize: 14,
                                            ),
                                          ),
                                          onTap: () {
                                            if (mounted) {
                                              setState(() {
                                                settings.blindTestType =
                                                    BlindTestType.ALCHEMY;
                                                settings.save();
                                                blindTestType =
                                                    BlindTestType.ALCHEMY;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  )),
                            );
                          });
                        },
                      );
                    },
                    icon: Icon(AlchemyIcons.settings),
                    iconSize: 20,
                  ),
                ],
              )),
          Column(
            children: [
              CachedImage(
                url: widget.playlist.image?.full ?? '',
                rounded: true,
                width: MediaQuery.of(context).size.width * 3 / 5,
              ),
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context)
                        .scaffoldBackgroundColor
                        .withAlpha(100),
                  ),
                  child: Text('Your best score : '.i18n),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                        decoration: BoxDecoration(
                            color: settings.primaryColor,
                            borderRadius: BorderRadius.circular(5)),
                        child: Text(
                          bestScore.toString(),
                          style: TextStyle(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                              fontSize: 18),
                          textHeightBehavior: TextHeightBehavior(
                            applyHeightToFirstAscent:
                                false, // Disable height for ascent
                            applyHeightToLastDescent:
                                false, // Apply height for descent
                          ),
                        )),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      '#' + rank.toString(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          fontSize: 18),
                      textHeightBehavior: TextHeightBehavior(
                        applyHeightToFirstAscent:
                            false, // Disable height for ascent
                        applyHeightToLastDescent:
                            false, // Apply height for descent
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.3,
              child: Padding(
                padding: EdgeInsets.all(0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15)),
                    color: Colors.lightBlue,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(children: [
                    LiquidLinearProgressIndicator(
                      value: 0.05,
                      valueColor: AlwaysStoppedAnimation(Theme.of(context)
                          .scaffoldBackgroundColor
                          .withAlpha(70)),
                      backgroundColor: Colors.lightBlue,
                      direction: Axis.vertical,
                      waveLength: 1.7,
                      waveHeight: 20,
                      speed: 1.5,
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Text(
                            'Choose your game'.i18n,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(8, 34, 8, 0),
                          child: Container(
                            decoration: BoxDecoration(boxShadow: [
                              BoxShadow(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                spreadRadius: 0, // Spread value
                                blurRadius: 8, // Blur value
                                offset: Offset(0, 8),
                              ),
                            ]),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pushReplacement(MaterialPageRoute(
                                        builder: (context) => BlindTestScreen(
                                              BlindTestSubType.TRACKS,
                                              widget.playlist,
                                            )));
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: ListTile(
                                visualDensity: VisualDensity.compact,
                                leading: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      AlchemyIcons.music,
                                      color: settings.primaryColor,
                                    )
                                  ],
                                ),
                                title: Text(
                                  'Titles'.i18n,
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      fontSize: 20),
                                ),
                                subtitle: Text(
                                  'Guess track titles',
                                  style: TextStyle(
                                      color: Settings.secondaryText,
                                      fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(8, 12, 8, 44),
                          child: Container(
                            decoration: BoxDecoration(boxShadow: [
                              BoxShadow(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                spreadRadius: 0, // Spread value
                                blurRadius: 8, // Blur value
                                offset: Offset(0, 8),
                              ),
                            ]),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pushReplacement(MaterialPageRoute(
                                        builder: (context) => BlindTestScreen(
                                              BlindTestSubType.ARTISTS,
                                              widget.playlist,
                                            )));
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: ListTile(
                                visualDensity: VisualDensity.compact,
                                leading: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      AlchemyIcons.user,
                                      color: settings.primaryColor,
                                    ),
                                  ],
                                ),
                                title: Text(
                                  'Artists'.i18n,
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      fontSize: 20),
                                ),
                                subtitle: Text(
                                  'Guess track artists',
                                  style: TextStyle(
                                      color: Settings.secondaryText,
                                      fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class BlindTestScreen extends StatefulWidget {
  final BlindTestSubType blindTestSubType;
  final Playlist playlist;
  const BlindTestScreen(this.blindTestSubType, this.playlist, {super.key});

  @override
  _BlindTestScreenState createState() => _BlindTestScreenState();
}

class _BlindTestScreenState extends State<BlindTestScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  StreamSubscription? _mediaItemSub;
  List<double> trackProgress = [0, 0];
  Timer? _timer;
  int remaining = 30;
  final BlindTest _blindTest = BlindTest();
  int _testLegnth = 0;
  Question? _currentQuestion;
  bool _error = false;
  String? _errorMsg;
  String _goodAnswer = '';
  String _badAnswer = '';
  bool _isLoading = true;

  void _startSyncTimer() {
    Timer.periodic(const Duration(milliseconds: 350), (timer) {
      _timer = timer;
      if (mounted) {
        setState(() {
          remaining = _remaining;
          if (_remaining == 0 && trackProgress[0] != 0) {
            trackProgress = [0, 0];
            timer.cancel();
            _submitAnswer('');
          } else {
            trackProgress = [trackProgress[1], _progress];
          }
        });
      }
    });
  }

  void _loadBlindTest() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    if (settings.blindTestType == BlindTestType.DEEZER) {
      Map<String, dynamic> res = await deezerAPI.callPipeApi(params: {
        'operationName': 'StartBlindtestSession',
        'query':
            'mutation StartBlindtestSession(\$id: String!, \$additionalPlayers: Int = 0, \$questionType: BlindTestQuestionTypeInput = TRACKS) {\n  blindTestStartSession(\n    id: \$id\n    type: PLAYLIST\n    additionalPlayers: \$additionalPlayers\n    questionType: \$questionType\n  ) {\n    token\n    additionalTokens {\n      token\n      __typename\n    }\n    maxScorePerQuestion\n    blindTest {\n      id\n      title\n      cover {\n        ...Picture\n        __typename\n      }\n      __typename\n    }\n    questions {\n      mediaToken {\n        payload\n        expiresAt\n        __typename\n      }\n      choices {\n        ...Choices\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment Picture on Picture {\n  ...PictureSmall\n  ...PictureMedium\n  ...PictureLarge\n  __typename\n}\n\nfragment PictureSmall on Picture {\n  id\n  small: urls(pictureRequest: {height: 100, width: 100})\n  __typename\n}\n\nfragment PictureMedium on Picture {\n  id\n  medium: urls(pictureRequest: {width: 264, height: 264})\n  __typename\n}\n\nfragment PictureLarge on Picture {\n  id\n  large: urls(pictureRequest: {width: 500, height: 500})\n  __typename\n}\n\nfragment Choices on Track {\n  id\n  title\n  contributors {\n    edges {\n      node {\n        ... on Artist {\n          id\n          name\n          picture {\n            ...Picture\n            __typename\n          }\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n  album {\n    id\n    cover {\n      ...Picture\n      __typename\n    }\n    __typename\n  }\n  __typename\n}',
        'variables': {
          'additionalPlayers': 0,
          'id': widget.playlist.id,
          'questionType': widget.blindTestSubType == BlindTestSubType.TRACKS
              ? 'TRACKS'
              : 'ARTISTS'
        }
      });

      if (res['data'] == null) {
        if (mounted) {
          setState(() {
            _error = true;
          });
        }
        return;
      }
      Map<String, dynamic>? blindTestSession =
          res['data']['blindTestStartSession'];

      if (blindTestSession != null && mounted) {
        setState(() {
          _blindTest.testToken = blindTestSession['token'];
          _testLegnth = blindTestSession['questions'].length;
        });

        for (int i = 0; i < _testLegnth; i++) {
          Map<String, dynamic>? question = blindTestSession['questions'][i];
          List<Track> trackChoices = [];
          List<Artist> artistChoices = [];
          for (int j = 0; j < question?['choices'].length; j++) {
            Map<String, dynamic> artistDetails =
                question?['choices'][j]['contributors']['edges'][0]['node'];
            if (question?['choices'][j]['id'] != null) {
              trackChoices.add(Track(
                  id: question?['choices'][j]['id'],
                  title: question?['choices'][j]['title']));
              artistChoices.add(Artist(
                  id: artistDetails['id'],
                  name: artistDetails['name'],
                  picture: ImageDetails(
                      fullUrl: artistDetails['picture']['large'][0],
                      thumbUrl: artistDetails['picture']['small'][0])));
            }
          }
          if (mounted) {
            setState(() {
              _blindTest.questions.add(Question(
                  mediaToken: question?['mediaToken']['payload'],
                  index: i,
                  trackChoices: trackChoices,
                  artistChoices: artistChoices));
            });
          }
        }
      }
    } else {
      _testLegnth = 10;
      List<Track> tracks = List.from(widget.playlist.tracks ?? []);
      tracks.shuffle();

      for (int i = 0; i < _testLegnth; i++) {
        List<Track> trackChoices = [];
        List<Artist> artistChoices = [];

        List<int> indexes = List<int>.generate(tracks.length, (index) => index);

        indexes.removeAt(i);
        trackChoices.add(tracks[i]);
        artistChoices.add(tracks[i].artists![0]);

        for (int j = 0; j < 3; j++) {
          int index = indexes.removeAt(Random().nextInt(indexes.length));
          trackChoices.add(tracks[index]);
          artistChoices.add(tracks[index].artists![0]);
        }

        List<int> originalIndexes = [0, 1, 2, 3];
        originalIndexes.shuffle();

        List<Track> shuffledTrackChoices =
            List.generate(4, (int k) => trackChoices[originalIndexes[k]]);
        List<Artist> shuffledArtistChoices =
            List.generate(4, (int k) => artistChoices[originalIndexes[k]]);

        if (mounted) {
          setState(() {
            _blindTest.questions.add(Question(
              mediaToken: null,
              index: i,
              track: tracks[i],
              artist: tracks[i].artists![0],
              trackChoices: shuffledTrackChoices,
              artistChoices: shuffledArtistChoices,
            ));
          });
        }
      }
    }

    _startQuestion(0);
  }

  void _startQuestion(int index) async {
    if (index >= _blindTest.questions.length) {
      GetIt.I<AudioPlayerHandler>().stop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => ResultsScreen(
              widget.playlist, widget.blindTestSubType, _blindTest)));
    }

    Question question = _blindTest.questions[index];

    if (settings.blindTestType == BlindTestType.DEEZER) {
      await GetIt.I<AudioPlayerHandler>()
          .playDeezerPreview(
              question.mediaToken ?? '', widget.playlist.image?.full)
          .catchError((e) => {
                setState(() {
                  _error = true;
                  _errorMsg = e.toString();
                })
              });
    } else {
      await GetIt.I<AudioPlayerHandler>()
          .playBlindTrack(question.track?.id ?? '', widget.playlist.image?.full)
          .catchError((e) => {
                if (mounted)
                  {
                    setState(() {
                      _error = true;
                      _errorMsg = e.toString();
                    })
                  }
              });
    }
    if (mounted) {
      setState(() {
        _goodAnswer = '';
        _badAnswer = '';
        _currentQuestion = question;
        _isLoading = false;
      });
    }

    _startSyncTimer();
  }

  void _submitAnswer(String id) async {
    if (_goodAnswer != '') return;

    int questionScore = max(0, ((_remaining * 99) / 30)).toInt();

    if (settings.blindTestType == BlindTestType.DEEZER) {
      Map<String, dynamic> res = await deezerAPI.callPipeApi(params: {
        'operationName': 'MakeBlindtestGuess',
        'query':
            'mutation MakeBlindtestGuess(\$token: String!, \$answerId: String!, \$questionScore: String!, \$step: Int!) {\n  blindTestMakeAGuess(\n    token: \$token\n    guess: \$answerId\n    value: \$questionScore\n    step: \$step\n  ) {\n    answer {\n      id\n      __typename\n    }\n    state {\n      token\n      __typename\n    }\n    scoreVariation\n    __typename\n  }\n}',
        'variables': {
          'answerId': id,
          'questionScore': questionScore.toString(),
          'step': _blindTest.questions.indexOf(_currentQuestion!),
          'token': _blindTest.testToken
        }
      });

      if (res['data'] == null) {
        if (mounted) {
          setState(() {
            _error = true;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _blindTest.testToken =
              res['data']['blindTestMakeAGuess']['state']['token'];
          _goodAnswer = res['data']['blindTestMakeAGuess']['answer']['id'];
          _badAnswer = _goodAnswer != id ? id : '';
          _blindTest.questions[_blindTest.questions.indexOf(_currentQuestion!)]
              .track = Track(id: _goodAnswer);
          _blindTest.points +=
              (res['data']['blindTestMakeAGuess']['scoreVariation']) as int;
        });
      }
    } else {
      String? trackId = _currentQuestion?.track?.id;
      Logger.root.info("Wrong answer, expected '$trackId' and got '$id'.");
      if (mounted) {
        setState(() {
          _goodAnswer = _currentQuestion?.track?.id ?? '';
          _badAnswer = _currentQuestion?.track?.id != id ? id : '';
          _blindTest.points +=
              _currentQuestion?.track?.id == id ? questionScore : 0;
        });
      }
    }

    Timer(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _startQuestion(_blindTest.questions.indexOf(_currentQuestion!) + 1);
        });
      }
    });
  }

  @override
  void initState() {
    GetIt.I<AudioPlayerHandler>().stop();
    WidgetsBinding.instance.addObserver(this);
    _loadBlindTest();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.lightBlue.withAlpha(70)));
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: settings.themeData.bottomAppBarTheme.color,
    ));
    _mediaItemSub?.cancel();
    _timer?.cancel();
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      GetIt.I<AudioPlayerHandler>().pause();
      SystemChrome.setPreferredOrientations([]);
    } else {
      GetIt.I<AudioPlayerHandler>().play();
    }
    super.didChangeAppLifecycleState(state);
  }

  double get _progress {
    if (GetIt.I<AudioPlayerHandler>().playbackState.value.processingState ==
        AudioProcessingState.idle) {
      return 0.0;
    }
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value == null) return 0.0;
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value?.duration?.inSeconds ==
        0) {
      return 0.0;
    } //Division by 0
    return GetIt.I<AudioPlayerHandler>()
            .playbackState
            .value
            .position
            .inSeconds /
        (GetIt.I<AudioPlayerHandler>().mediaItem.value?.duration?.inSeconds ??
            1);
  }

  int get _remaining {
    if (GetIt.I<AudioPlayerHandler>().playbackState.value.processingState ==
        AudioProcessingState.idle) {
      return 0;
    }
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value == null) return 0;
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value?.duration?.inSeconds ==
        0) {
      return 0;
    } //Division by 0
    return (GetIt.I<AudioPlayerHandler>()
                .mediaItem
                .value
                ?.duration
                ?.inSeconds ??
            1) -
        GetIt.I<AudioPlayerHandler>().playbackState.value.position.inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    //Avoid async gap
    return _error
        ? Scaffold(
            backgroundColor: Colors.red.shade400,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            GetIt.I<AudioPlayerHandler>().stop();
                            GetIt.I<AudioPlayerHandler>().clearQueue();
                            Navigator.of(context, rootNavigator: true)
                                .maybePop();
                          },
                          icon: Icon(AlchemyIcons.cross),
                          iconSize: 20,
                        ),
                        Column(
                          children: [
                            Text(
                              widget.playlist.title ?? '',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Blind test'.i18n,
                              style: TextStyle(
                                  fontWeight: FontWeight.w400, fontSize: 10),
                            ),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (1 + (_currentQuestion?.index ?? 0)).toString() +
                                  '/' +
                                  _testLegnth.toString(),
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor)),
                              child: SizedBox(
                                width: 35,
                                height: 10,
                                child: LinearProgressIndicator(
                                  value: (_currentQuestion?.index ?? 0) /
                                      (_testLegnth != 0 ? _testLegnth : 1),
                                  color: Color(0xFF96F9F3),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text('Oops, something went wrong...'.i18n),
                      if (_errorMsg != null) Text(_errorMsg ?? '')
                    ],
                  ))
                ],
              ),
            ))
        : _isLoading
            ? SplashScreen()
            : PopScope(
                canPop: true,
                onPopInvokedWithResult: (bool didPop, dynamic) {
                  GetIt.I<AudioPlayerHandler>().stop();
                  GetIt.I<AudioPlayerHandler>().clearQueue();
                  Navigator.of(context, rootNavigator: true).maybePop();
                },
                child: Scaffold(
                    backgroundColor: Colors.lightBlue,
                    body: SafeArea(
                        child: Stack(children: [
                      Container(
                        decoration: BoxDecoration(color: Colors.lightBlue),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: LiquidLinearProgressIndicator(
                            value: 0.35,
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context)
                                  .scaffoldBackgroundColor
                                  .withAlpha(70),
                            ),
                            backgroundColor: Colors.lightBlue,
                            direction: Axis.vertical,
                            waveLength: 1.7,
                            waveHeight: 20,
                            speed: 1.5,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    GetIt.I<AudioPlayerHandler>().stop();
                                    GetIt.I<AudioPlayerHandler>().clearQueue();
                                    Navigator.of(context, rootNavigator: true)
                                        .maybePop();
                                  },
                                  icon: Icon(AlchemyIcons.cross),
                                  iconSize: 20,
                                ),
                                Column(
                                  children: [
                                    Text(
                                      widget.playlist.title ?? '',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      'Blind test'.i18n,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 10),
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      (1 + (_currentQuestion?.index ?? 0))
                                              .toString() +
                                          '/' +
                                          _testLegnth.toString(),
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .scaffoldBackgroundColor)),
                                      child: SizedBox(
                                        width: 35,
                                        height: 10,
                                        child: LinearProgressIndicator(
                                          value:
                                              (_currentQuestion?.index ?? 0) /
                                                  (_testLegnth != 0
                                                      ? _testLegnth
                                                      : 1),
                                          color: Color(0xFF96F9F3),
                                          backgroundColor: Colors.transparent,
                                        ),
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                          widget.blindTestSubType == BlindTestSubType.TRACKS
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      remaining.toString(),
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 50),
                                      textHeightBehavior: TextHeightBehavior(
                                        applyHeightToFirstAscent:
                                            true, // Disable height for ascent
                                        applyHeightToLastDescent:
                                            false, // Apply height for descent
                                      ),
                                    ),
                                    SizedBox(
                                      width:
                                          MediaQuery.of(context).size.width / 2,
                                      height:
                                          MediaQuery.of(context).size.width / 2,
                                      child: TweenAnimationBuilder<double>(
                                          tween: Tween(
                                              begin: trackProgress[0],
                                              end: trackProgress[1]),
                                          duration: Duration(milliseconds: 350),
                                          builder: (context, value, _) =>
                                              CircularProgressIndicator(
                                                value: value,
                                                strokeWidth: 10,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color,
                                                backgroundColor: Theme.of(
                                                        context)
                                                    .scaffoldBackgroundColor,
                                                strokeCap: StrokeCap.round,
                                              )),
                                    ),
                                    SizedBox(
                                      width:
                                          MediaQuery.of(context).size.width / 2,
                                      height:
                                          MediaQuery.of(context).size.width /
                                                  2 +
                                              30,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 18),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor,
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            child: Text(
                                              _blindTest.points.toString() +
                                                  ' pt',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Poppins',
                                                  fontSize: 18),
                                              textHeightBehavior:
                                                  TextHeightBehavior(
                                                applyHeightToFirstAscent:
                                                    false, // Disable height for ascent
                                                applyHeightToLastDescent:
                                                    false, // Apply height for descent
                                              ),
                                            )),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    SizedBox(
                                      width:
                                          MediaQuery.of(context).size.width / 5,
                                      child: Center(
                                        child: Text(
                                          remaining.toString() + "'",
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w900,
                                              fontSize: 50),
                                          textHeightBehavior:
                                              TextHeightBehavior(
                                            applyHeightToFirstAscent:
                                                true, // Disable height for ascent
                                            applyHeightToLastDescent:
                                                false, // Apply height for descent
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          3 /
                                          5,
                                      height: 10,
                                      child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(
                                                begin: trackProgress[0],
                                                end: trackProgress[1]),
                                            duration:
                                                Duration(milliseconds: 350),
                                            builder: (context, value, _) =>
                                                LinearProgressIndicator(
                                              value: value,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                              backgroundColor: Theme.of(context)
                                                  .scaffoldBackgroundColor,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                          )),
                                    ),
                                    SizedBox(
                                      width:
                                          MediaQuery.of(context).size.width / 5,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 18),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor,
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            child: Text(
                                              _blindTest.points.toString() +
                                                  ' pt',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Poppins',
                                                  fontSize: 18),
                                              textHeightBehavior:
                                                  TextHeightBehavior(
                                                applyHeightToFirstAscent:
                                                    false, // Disable height for ascent
                                                applyHeightToLastDescent:
                                                    false, // Apply height for descent
                                              ),
                                            )),
                                      ),
                                    ),
                                  ],
                                ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: widget.blindTestSubType ==
                                    BlindTestSubType.TRACKS
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      widget.blindTestSubType ==
                                              BlindTestSubType.TRACKS
                                          ? _currentQuestion
                                                  ?.trackChoices.length ??
                                              0
                                          : _currentQuestion
                                                  ?.artistChoices.length ??
                                              0,
                                      (int index) => Padding(
                                        padding: EdgeInsets.only(top: 12),
                                        child: Container(
                                          decoration: BoxDecoration(boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .scaffoldBackgroundColor,
                                              spreadRadius: 0, // Spread value
                                              blurRadius: 8, // Blur value
                                              offset: Offset(0, 8),
                                            ),
                                          ]),
                                          child: ElevatedButton(
                                              onPressed: () {
                                                _submitAnswer(_currentQuestion
                                                        ?.trackChoices[index]
                                                        .id ??
                                                    '');
                                              },
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: _currentQuestion
                                                              ?.trackChoices[
                                                                  index]
                                                              .id ==
                                                          _goodAnswer
                                                      ? Colors.green.shade400
                                                      : _currentQuestion
                                                                  ?.trackChoices[
                                                                      index]
                                                                  .id ==
                                                              _badAnswer
                                                          ? Colors.red.shade400
                                                          : Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10))),
                                              child: SizedBox(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width -
                                                    48,
                                                height: 50,
                                                child: Align(
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    _currentQuestion
                                                            ?.trackChoices[
                                                                index]
                                                            .title ??
                                                        '',
                                                    style: TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.black,
                                                        fontSize: 20),
                                                  ),
                                                ),
                                              )),
                                        ),
                                      ),
                                    ),
                                  )
                                : GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    children: List.generate(
                                      _currentQuestion?.artistChoices.length ??
                                          0,
                                      (int index) => Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Container(
                                          decoration: BoxDecoration(boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .scaffoldBackgroundColor,
                                              spreadRadius: 0, // Spread value
                                              blurRadius: 8, // Blur value
                                              offset: Offset(0, 8),
                                            ),
                                          ]),
                                          child: ElevatedButton(
                                              onPressed: () {
                                                _submitAnswer(_currentQuestion
                                                        ?.trackChoices[index]
                                                        .id ??
                                                    '');
                                              },
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: _currentQuestion
                                                              ?.trackChoices[
                                                                  index]
                                                              .id ==
                                                          _goodAnswer
                                                      ? Colors.green.shade400
                                                      : _currentQuestion
                                                                  ?.trackChoices[
                                                                      index]
                                                                  .id ==
                                                              _badAnswer
                                                          ? Colors.red.shade400
                                                          : Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10))),
                                              child: Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    CachedImage(
                                                      url: _currentQuestion
                                                              ?.artistChoices[
                                                                  index]
                                                              .picture
                                                              ?.full ??
                                                          '',
                                                      rounded: true,
                                                    ),
                                                    Center(
                                                        child: Padding(
                                                      padding: EdgeInsets.only(
                                                          top: 8),
                                                      child: Text(
                                                        _currentQuestion
                                                                ?.artistChoices[
                                                                    index]
                                                                .name ??
                                                            '',
                                                        maxLines: 1,
                                                        style: TextStyle(
                                                            fontFamily:
                                                                'Deezer',
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color: Colors.black,
                                                            fontSize: 18),
                                                      ),
                                                    ))
                                                  ],
                                                ),
                                              )),
                                        ),
                                      ),
                                    ),
                                  ),
                          )
                        ],
                      )
                    ]))));
  }
}

class ResultsScreen extends StatefulWidget {
  final Playlist playlist;
  final BlindTestSubType blindTestSubType;
  final BlindTest blindTest;
  const ResultsScreen(this.playlist, this.blindTestSubType, this.blindTest,
      {super.key});

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int bestScore = 0;
  int rank = 1;
  int playerCount = 1;
  final List<Track> _tracklist = [];
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoadingTracks = false;
  bool _isLoadingLeaderboard = false;

  Future<void> _score() async {
    if (settings.blindTestType == BlindTestType.DEEZER) {
      //Save score
      await deezerAPI.callPipeApi(params: {
        'operationName': 'SaveScore',
        'query':
            'mutation SaveScore(\$id: String!, \$score: Int!) {\n  saveBlindTestScore(id: \$id, type: PLAYLIST, score: \$score) {\n    status\n    __typename\n  }\n}',
        'variables': {
          'id': widget.playlist.id,
          'score': widget.blindTest.points
        }
      });

      //Get best score
      Map<String, dynamic> score = await deezerAPI.callPipeApi(params: {
        'operationName': 'Score',
        'query':
            'query Score(\$id: String!) {\n  me {\n    games {\n      blindTest {\n        bestScore(id: \$id, type: PLAYLIST)\n        hasPlayed\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}',
        'variables': {'id': widget.playlist.id}
      });

      if (mounted) {
        setState(() {
          bestScore = score['data']['me']['games']['blindTest']['bestScore'];
        });
      }
    }
  }

  Future<void> _loadTracks() async {
    List<Track> trackList = [];

    if (mounted) {
      setState(() {
        _isLoadingTracks = true;
      });
    }

    if (settings.blindTestType == BlindTestType.DEEZER) {
      for (int i = 0; i < widget.blindTest.questions.length; i++) {
        trackList.add(await deezerAPI
            .track(widget.blindTest.questions[i].track?.id ?? ''));
      }

      if (mounted) {
        setState(() {
          _tracklist.addAll(trackList);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _tracklist.addAll(List.generate(widget.blindTest.questions.length,
                  (int i) => widget.blindTest.questions[i].track)
              .whereType<Track>()
              .toList());
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingTracks = false;
      });
    }
  }

  Future<void> _leaderBoard() async {
    if (mounted) {
      setState(() {
        _isLoadingLeaderboard = true;
      });
    }

    if (settings.blindTestType == BlindTestType.DEEZER) {
      Map<String, dynamic> apiBoard = await deezerAPI.callPipeApi(params: {
        'operationName': 'Leaderboard',
        'query':
            'query Leaderboard(\$blindtestId: String!) {\n  blindTest(id: \$blindtestId, type: PLAYLIST) {\n    ...UserScoreAndRank\n    leaderboard {\n      topRankedPlayers {\n        user {\n          name\n          id\n          picture {\n            ...Picture\n            __typename\n          }\n          __typename\n        }\n        rank\n        bestScore\n        __typename\n      }\n      playersCount\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment UserScoreAndRank on BlindTest {\n  id\n  userRank\n  userBestScore\n  __typename\n}\n\nfragment Picture on Picture {\n  ...PictureSmall\n  ...PictureMedium\n  ...PictureLarge\n  __typename\n}\n\nfragment PictureSmall on Picture {\n  id\n  small: urls(pictureRequest: {height: 100, width: 100})\n  __typename\n}\n\nfragment PictureMedium on Picture {\n  id\n  medium: urls(pictureRequest: {width: 264, height: 264})\n  __typename\n}\n\nfragment PictureLarge on Picture {\n  id\n  large: urls(pictureRequest: {width: 500, height: 500})\n  __typename\n}',
        'variables': {'blindtestId': widget.playlist.id}
      });

      if (mounted) {
        setState(() {
          rank = apiBoard['data']['blindTest']['userRank'];
          playerCount =
              apiBoard['data']['blindTest']['leaderboard']['playersCount'];
          _leaderboard = [];
          for (int i = 0;
              i <
                  apiBoard['data']['blindTest']['leaderboard']
                          ['topRankedPlayers']
                      .length;
              i++) {
            _leaderboard.add(apiBoard['data']['blindTest']['leaderboard']
                ['topRankedPlayers'][i]);
          }
        });
      }
    } else {
      _leaderboard.add({
        'user': {'name': cache.userName},
        'bestScore': widget.blindTest.points
      });
    }

    if (mounted) {
      setState(() {
        _isLoadingLeaderboard = false;
      });
    }
  }

  Future<void> _load() async {
    _score();
    _leaderBoard();
    _loadTracks();
  }

  @override
  void initState() {
    _load();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.lightBlue.withAlpha(70)));
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: settings.themeData.bottomAppBarTheme.color,
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.lightBlue),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: LiquidLinearProgressIndicator(
                  value: 0.9,
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).scaffoldBackgroundColor.withAlpha(70),
                  ),
                  backgroundColor: Colors.lightBlue,
                  direction: Axis.vertical,
                  waveLength: 1.7,
                  waveHeight: 20,
                  speed: 1.5,
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          GetIt.I<AudioPlayerHandler>().stop();
                          GetIt.I<AudioPlayerHandler>().clearQueue();
                          Navigator.of(context, rootNavigator: true).maybePop();
                        },
                        icon: Icon(AlchemyIcons.cross),
                        iconSize: 20,
                      ),
                      Column(
                        children: [
                          Text(
                            widget.playlist.title ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Blind test'.i18n,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (context) => BlindTestScreen(
                                      widget.blindTestSubType,
                                      widget.playlist)));
                        },
                        icon: Icon(Icons.refresh),
                        iconSize: 25,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                        decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(5)),
                        child: Text(
                          '${widget.blindTest.points} pt',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                              fontSize: 18),
                          textHeightBehavior: TextHeightBehavior(
                            applyHeightToFirstAscent:
                                false, // Disable height for ascent
                            applyHeightToLastDescent:
                                false, // Apply height for descent
                          ),
                        )),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context)
                          .scaffoldBackgroundColor
                          .withAlpha(100),
                    ),
                    child:
                        Text('Your best score : '.i18n + bestScore.toString()),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                    child: Column(
                      children: [
                        Row(
                          textBaseline: TextBaseline.ideographic,
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                AlchemyIcons.crown,
                                size: 34,
                              ),
                            ),
                            Text(
                              'Leaderboard'.i18n,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: _isLoadingLeaderboard
                              ? [Center(child: CircularProgressIndicator())]
                              : List.generate(
                                  _leaderboard.length,
                                  (int i) => ListTile(
                                        leading: Text(
                                          '#${i + 1}',
                                          style: TextStyle(
                                            fontSize: 46,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        title: Text(
                                            _leaderboard[i]['user']['name']),
                                        trailing: Text(_leaderboard[i]
                                                ['bestScore']
                                            .toString()),
                                      )),
                        ),
                        settings.blindTestType == BlindTestType.DEEZER
                            ? Text(
                                'You are #'.i18n +
                                    rank.toString() +
                                    ' out of '.i18n +
                                    playerCount.toString() +
                                    ' players'.i18n,
                                textAlign: TextAlign.center,
                              )
                            : Row(
                                children: [
                                  IconButton(
                                      onPressed: () {
                                        showDialog(
                                            context: context,
                                            builder: (context) {
                                              return StatefulBuilder(
                                                  builder: (context, setState) {
                                                return AlertDialog(
                                                  title: Text(
                                                      'About leaderboard'.i18n),
                                                  content: Text(
                                                    "Because Alchemy Blind Tests are stored only on your device, there isn't an online leaderboard to track global scores."
                                                        .i18n,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                );
                                              });
                                            });
                                      },
                                      icon: Icon(
                                        Icons.info_outline,
                                        size: 20,
                                      )),
                                  Text(
                                    'About this leaderboard'.i18n,
                                    style: TextStyle(
                                        color: Settings.secondaryText,
                                        fontSize: 12),
                                  )
                                ],
                              )
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                      child: Column(
                        children: [
                          Row(
                            textBaseline: TextBaseline.ideographic,
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  AlchemyIcons.note_list,
                                  size: 34,
                                ),
                              ),
                              Text(
                                'Played tracks'.i18n,
                                textHeightBehavior: TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: true,
                                ),
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: _isLoadingTracks
                                ? Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ListView.builder(
                                    itemCount: _tracklist.length,
                                    itemBuilder: (context, i) {
                                      return TrackTile(_tracklist[i]);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
