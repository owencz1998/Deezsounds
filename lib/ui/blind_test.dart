import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:deezer/api/deezer.dart';
import 'package:deezer/api/definitions.dart';
import 'package:deezer/fonts/alchemy_icons.dart';
import 'package:deezer/service/audio_service.dart';
import 'package:deezer/settings.dart';
import 'package:deezer/translations.i18n.dart';
import 'package:deezer/ui/cached_image.dart';
import 'package:deezer/ui/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

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
    Map<String, dynamic> score = await deezerAPI.callPipeApi(params: {
      'operationName': 'Score',
      'query':
          'query Score(\$id: String!) {\n  me {\n    games {\n      blindTest {\n        bestScore(id: \$id, type: PLAYLIST)\n        hasPlayed\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}',
      'variables': {'id': widget.playlist.id}
    });

    if (mounted) {
      setState(() {
        bestScore = score['data']['me']['games']['blindTest']['bestScore'] ?? 0;
      });
    }
  }

  Future<void> _rank() async {
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
  }

  @override
  void initState() {
    GetIt.I<AudioPlayerHandler>().stop();
    super.initState();
    _score();
    _rank();
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
              child: Stack(
                alignment: Alignment.topLeft,
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
                  Center(
                    child: Padding(
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
                              fontFamily: 'MontSerrat',
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
                          fontFamily: 'MontSerrat',
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
              height: MediaQuery.of(context).size.height / 3,
              child: Padding(
                padding: EdgeInsets.all(0),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/wave.png',
                      ),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15)),
                    color: Colors.lightBlue,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        'Choose your game'.i18n,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'MontSerrat',
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 34),
                        child: Container(
                          decoration: BoxDecoration(boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).scaffoldBackgroundColor,
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
                                            BlindTestType.TRACKS,
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
                                    fontFamily: 'MontSerrat',
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
                        padding: EdgeInsets.only(top: 12, bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).scaffoldBackgroundColor,
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
                                            BlindTestType.ARTISTS,
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
                                    fontFamily: 'MontSerrat',
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
                  ),
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
  final BlindTestType blindTestType;
  final Playlist playlist;
  const BlindTestScreen(this.blindTestType, this.playlist, {super.key});

  @override
  _BlindTestScreenState createState() => _BlindTestScreenState();
}

class _BlindTestScreenState extends State<BlindTestScreen>
    with WidgetsBindingObserver {
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

  void _startSyncTimer() {
    Timer.periodic(const Duration(milliseconds: 350), (timer) {
      _timer = timer;

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
    });
  }

  void _loadBlindTest() async {
    Map<String, dynamic> res = await deezerAPI.callPipeApi(params: {
      'operationName': 'StartBlindtestSession',
      'query':
          'mutation StartBlindtestSession(\$id: String!, \$additionalPlayers: Int = 0, \$questionType: BlindTestQuestionTypeInput = TRACKS) {\n  blindTestStartSession(\n    id: \$id\n    type: PLAYLIST\n    additionalPlayers: \$additionalPlayers\n    questionType: \$questionType\n  ) {\n    token\n    additionalTokens {\n      token\n      __typename\n    }\n    maxScorePerQuestion\n    blindTest {\n      id\n      title\n      cover {\n        ...Picture\n        __typename\n      }\n      __typename\n    }\n    questions {\n      mediaToken {\n        payload\n        expiresAt\n        __typename\n      }\n      choices {\n        ...Choices\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment Picture on Picture {\n  ...PictureSmall\n  ...PictureMedium\n  ...PictureLarge\n  __typename\n}\n\nfragment PictureSmall on Picture {\n  id\n  small: urls(pictureRequest: {height: 100, width: 100})\n  __typename\n}\n\nfragment PictureMedium on Picture {\n  id\n  medium: urls(pictureRequest: {width: 264, height: 264})\n  __typename\n}\n\nfragment PictureLarge on Picture {\n  id\n  large: urls(pictureRequest: {width: 500, height: 500})\n  __typename\n}\n\nfragment Choices on Track {\n  id\n  title\n  contributors {\n    edges {\n      node {\n        ... on Artist {\n          id\n          name\n          picture {\n            ...Picture\n            __typename\n          }\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n  album {\n    id\n    cover {\n      ...Picture\n      __typename\n    }\n    __typename\n  }\n  __typename\n}',
      'variables': {
        'additionalPlayers': 0,
        'id': widget.playlist.id,
        'questionType':
            widget.blindTestType == BlindTestType.TRACKS ? 'TRACKS' : 'ARTISTS'
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

        setState(() {
          _blindTest.questions.add(Question(
              mediaToken: question?['mediaToken']['payload'],
              index: i,
              trackChoices: trackChoices,
              artistChoices: artistChoices));
        });
      }
    }

    _startQuestion(0);
  }

  void _startQuestion(int index) async {
    if (index >= _blindTest.questions.length) {
      GetIt.I<AudioPlayerHandler>().stop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => ResultsScreen(
              widget.playlist, widget.blindTestType, _blindTest)));
    }

    Question question = _blindTest.questions[index];

    await GetIt.I<AudioPlayerHandler>()
        .playBlindTrack(question.mediaToken, widget.playlist.image?.full)
        .catchError((e) => {
              setState(() {
                _error = true;
                _errorMsg = e.toString();
              })
            });

    setState(() {
      _goodAnswer = '';
      _badAnswer = '';
      _currentQuestion = question;
    });

    _startSyncTimer();
  }

  void _submitAnswer(String id) async {
    if (_goodAnswer != '') return;

    int questionScore = max(0, ((_remaining * 99) / 30)).toInt();
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
    super.initState();
    _loadBlindTest();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mediaItemSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      GetIt.I<AudioPlayerHandler>().pause();
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
                                  fontFamily: 'MontSerrat',
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
                    child: Container(
                        decoration: BoxDecoration(
                            image: DecorationImage(
                          image: AssetImage(
                            'assets/wave.png',
                          ),
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.bottomLeft,
                        )),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      GetIt.I<AudioPlayerHandler>().stop();
                                      GetIt.I<AudioPlayerHandler>()
                                          .clearQueue();
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        (1 + (_currentQuestion?.index ?? 0))
                                                .toString() +
                                            '/' +
                                            _testLegnth.toString(),
                                        style: TextStyle(
                                            fontFamily: 'MontSerrat',
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
                            widget.blindTestType == BlindTestType.TRACKS
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Text(
                                        remaining.toString(),
                                        style: TextStyle(
                                            fontFamily: 'MontSerrat',
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
                                            MediaQuery.of(context).size.width /
                                                2,
                                        height:
                                            MediaQuery.of(context).size.width /
                                                2,
                                        child: TweenAnimationBuilder<double>(
                                            tween: Tween(
                                                begin: trackProgress[0],
                                                end: trackProgress[1]),
                                            duration:
                                                Duration(milliseconds: 350),
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
                                            MediaQuery.of(context).size.width /
                                                2,
                                        height:
                                            MediaQuery.of(context).size.width /
                                                    2 +
                                                30,
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            decoration: BoxDecoration(
                                                color: Color(0xFFE07DF7),
                                                border: Border.all(
                                                    width: 2,
                                                    color: Theme.of(context)
                                                        .scaffoldBackgroundColor)),
                                            child: SizedBox(
                                              width: 75,
                                              height: 32,
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: Text(
                                                    _blindTest.points
                                                            .toString() +
                                                        ' pt',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 16,
                                                        color: Theme.of(context)
                                                            .scaffoldBackgroundColor)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width /
                                                5,
                                        child: Center(
                                          child: Text(
                                            remaining.toString() + "'",
                                            style: TextStyle(
                                                fontFamily: 'MontSerrat',
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
                                        width:
                                            MediaQuery.of(context).size.width *
                                                3 /
                                                5,
                                        height: 10,
                                        child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child:
                                                TweenAnimationBuilder<double>(
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
                                                backgroundColor: Theme.of(
                                                        context)
                                                    .scaffoldBackgroundColor,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            )),
                                      ),
                                      SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width /
                                                5,
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            decoration: BoxDecoration(
                                                color: Color(0xFFE07DF7),
                                                border: Border.all(
                                                    width: 2,
                                                    color: Theme.of(context)
                                                        .scaffoldBackgroundColor)),
                                            child: SizedBox(
                                              width: 70,
                                              height: 40,
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: Text(
                                                    _blindTest.points
                                                            .toString() +
                                                        ' pt',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 16,
                                                        color: Theme.of(context)
                                                            .scaffoldBackgroundColor)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: widget.blindTestType ==
                                      BlindTestType.TRACKS
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                        widget.blindTestType ==
                                                BlindTestType.TRACKS
                                            ? _currentQuestion
                                                    ?.trackChoices.length ??
                                                0
                                            : _currentQuestion
                                                    ?.artistChoices.length ??
                                                0,
                                        (int index) => Padding(
                                          padding: EdgeInsets.only(top: 12),
                                          child: Container(
                                            decoration:
                                                BoxDecoration(boxShadow: [
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
                                                            ? Colors
                                                                .red.shade400
                                                            : Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
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
                                                          fontFamily:
                                                              'MontSerrat',
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
                                        _currentQuestion
                                                ?.artistChoices.length ??
                                            0,
                                        (int index) => Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Container(
                                            decoration:
                                                BoxDecoration(boxShadow: [
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
                                                            ? Colors
                                                                .red.shade400
                                                            : Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10))),
                                                child: Padding(
                                                  padding: EdgeInsets.all(8),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
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
                                                        padding:
                                                            EdgeInsets.only(
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
                                                                  FontWeight
                                                                      .w900,
                                                              color:
                                                                  Colors.black,
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
                        )))));
  }
}

class ResultsScreen extends StatefulWidget {
  final Playlist playlist;
  final BlindTestType blindTestType;
  final BlindTest blindTest;
  const ResultsScreen(this.playlist, this.blindTestType, this.blindTest,
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

  Future<void> _score() async {
    //Save score
    await deezerAPI.callPipeApi(params: {
      'operationName': 'SaveScore',
      'query':
          'mutation SaveScore(\$id: String!, \$score: Int!) {\n  saveBlindTestScore(id: \$id, type: PLAYLIST, score: \$score) {\n    status\n    __typename\n  }\n}',
      'variables': {'id': widget.playlist.id, 'score': widget.blindTest.points}
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

  Future<void> _loadTracks() async {
    List<Track> trackList = [];

    for (int i = 0; i < widget.blindTest.questions.length; i++) {
      trackList.add(
          await deezerAPI.track(widget.blindTest.questions[i].track?.id ?? ''));
    }

    if (mounted) {
      setState(() {
        _tracklist.addAll(trackList);
      });
    }
  }

  Future<void> _leaderBoard() async {
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
                apiBoard['data']['blindTest']['leaderboard']['topRankedPlayers']
                    .length;
            i++) {
          _leaderboard.add(apiBoard['data']['blindTest']['leaderboard']
              ['topRankedPlayers'][i]);
        }
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
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.lightBlue,
        body: SafeArea(
            child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/wave.png',
              ),
              fit: BoxFit.fitWidth,
              alignment: Alignment.bottomLeft,
            ),
          ),
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
                        Navigator.of(context).pushReplacement(MaterialPageRoute(
                            builder: (context) => BlindTestScreen(
                                widget.blindTestType, widget.playlist)));
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
                    decoration: BoxDecoration(
                      color: Color(0xFFE07DF7),
                      border: Border.all(
                        width: 2,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    child: SizedBox(
                      width: 100,
                      height: 45,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '${widget.blindTest.points} pt',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                    ),
                  ),
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
                  child: Text('Your best score : '.i18n + bestScore.toString()),
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
                              fontFamily: 'MontSerrat',
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                            _leaderboard.length,
                            (int i) => ListTile(
                                  leading: Text(
                                    '#${i + 1}',
                                    style: TextStyle(
                                      fontSize: 46,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'MontSerrat',
                                    ),
                                  ),
                                  title: Text(_leaderboard[i]['user']['name']),
                                  trailing: Text(
                                      _leaderboard[i]['bestScore'].toString()),
                                )),
                      ),
                      Text('You are #'.i18n +
                          rank.toString() +
                          ' out of '.i18n +
                          playerCount.toString() +
                          ' players'.i18n)
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
                                fontFamily: 'MontSerrat',
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: ListView.builder(
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
        )));
  }
}
