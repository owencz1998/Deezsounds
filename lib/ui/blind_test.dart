import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:deezer/api/deezer.dart';
import 'package:deezer/api/definitions.dart';
import 'package:deezer/fonts/deezer_icons.dart';
import 'package:deezer/service/audio_service.dart';
import 'package:deezer/translations.i18n.dart';
import 'package:deezer/ui/home_screen.dart';
import 'package:deezer/ui/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

class BlindTestScreen extends StatefulWidget {
  final Playlist playlist;
  const BlindTestScreen(this.playlist, {super.key});

  @override
  _BlindTestScreenState createState() => _BlindTestScreenState();
}

class _BlindTestScreenState extends State<BlindTestScreen> {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  StreamSubscription? _mediaItemSub;
  List<double> trackProgress = [0, 0];
  Timer? _timer;
  int remaining = 30;
  BlindTest _blindTest = BlindTest();
  int _testLegnth = 0;
  Question? _currentQuestion;
  bool _error = false;
  String _goodAnswer = '';
  String _badAnswer = '';

  void _startSyncTimer() {
    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      _timer = timer;

      setState(() {
        trackProgress = [trackProgress[1], _progress];
        remaining = _remaining;
        if (trackProgress == [1, 1]) timer.cancel();
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
        'questionType': 'TRACKS'
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
        List<Track> choices = [];
        for (int j = 0; j < question?['choices'].length; j++) {
          if (question?['choices'][j]['id'] != null) {
            choices.add(Track(
                id: question?['choices'][j]['id'],
                title: question?['choices'][j]['title']));
          }
        }

        setState(() {
          _blindTest.questions.add(Question(
              mediaToken: question?['mediaToken']['payload'],
              index: i,
              choices: choices));
        });
      }
    }

    _startQuestion(0);
  }

  void _startQuestion(int index) async {
    if (index >= _blindTest.questions.length) {
      GetIt.I<AudioPlayerHandler>().stop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => ResultsScreen(widget.playlist, _blindTest)));
    }

    Question question = _blindTest.questions[index];

    await GetIt.I<AudioPlayerHandler>()
        .playBlindTrack(question.mediaToken, widget.playlist.image?.full);

    setState(() {
      _goodAnswer = '';
      _badAnswer = '';
      _currentQuestion = question;
    });
  }

  void _submitAnswer(String id) async {
    if (_goodAnswer != '') return;

    int questionScore = ((_remaining * 99) / 30).toInt();
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
    _startSyncTimer();
    super.initState();
    _loadBlindTest();
  }

  @override
  void dispose() {
    _mediaItemSub?.cancel();
    _timer?.cancel();
    super.dispose();
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
                            Navigator.of(context, rootNavigator: true)
                                .maybePop();
                          },
                          icon: Icon(DeezerIcons.cross),
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
                              'Blind test',
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
                                  fontFamily: 'Deezer',
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
                      child: Align(
                    alignment: Alignment.center,
                    child: Text('Oops, something went wrong...'),
                  ))
                ],
              ),
            ))
        : Scaffold(
            backgroundColor: Color(0xFF6849FF),
            body: SafeArea(
                child: Column(
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
                          Navigator.of(context, rootNavigator: true).maybePop();
                        },
                        icon: Icon(DeezerIcons.cross),
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
                            'Blind test',
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
                                fontFamily: 'Deezer',
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
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      remaining.toString(),
                      style: TextStyle(
                          fontFamily: 'Deezer',
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
                      width: MediaQuery.of(context).size.width / 2,
                      height: MediaQuery.of(context).size.width / 2,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: trackProgress[0], end: trackProgress[1]),
                        duration: Duration(milliseconds: 350),
                        builder: (context, value, _) =>
                            CircularProgressIndicator(
                          value: value,
                          strokeWidth: 10,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 2,
                      height: MediaQuery.of(context).size.width / 2 + 30,
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
                              child: Text(_blindTest.points.toString() + ' pt',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _currentQuestion?.choices.length ?? 0,
                      (int index) => Padding(
                        padding: EdgeInsets.only(top: 12),
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
                                _submitAnswer(
                                    _currentQuestion?.choices[index].id ?? '');
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentQuestion
                                              ?.choices[index].id ==
                                          _goodAnswer
                                      ? Colors.green.shade400
                                      : _currentQuestion?.choices[index].id ==
                                              _badAnswer
                                          ? Colors.red.shade400
                                          : Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width - 48,
                                height: 50,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    _currentQuestion?.choices[index].title ??
                                        '',
                                    style: TextStyle(
                                        fontFamily: 'Deezer',
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                        fontSize: 20),
                                  ),
                                ),
                              )),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            )));
  }
}

class ResultsScreen extends StatefulWidget {
  final Playlist playlist;
  final BlindTest blindTest;
  const ResultsScreen(this.playlist, this.blindTest, {super.key});

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int bestScore = 0;
  int rank = 1;
  int playerCount = 1;
  List<Track> _tracklist = [];
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

  Future<Map<String, dynamic>> _me() async {
    Map<String, dynamic> me = await deezerAPI.callPipeApi(params: {
      'operationName': 'Me',
      'query':
          'query Me {\n  me {\n    mediaServiceLicenseToken {\n      token\n      expirationDate\n      __typename\n    }\n    recToken {\n      token\n      expirationDate\n      __typename\n    }\n    user {\n      id\n      name\n      picture {\n        ...Picture\n        __typename\n      }\n      __typename\n    }\n    onboarding(context: WELCOME) {\n      shouldBeOnboarded\n      __typename\n    }\n    __typename\n  }\n  permissions {\n    games {\n      blindTest {\n        canInitiateMultiplayerSession\n        hasRestrictedAccessToBlindTest\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment Picture on Picture {\n  ...PictureSmall\n  ...PictureMedium\n  ...PictureLarge\n  __typename\n}\n\nfragment PictureSmall on Picture {\n  id\n  small: urls(pictureRequest: {height: 100, width: 100})\n  __typename\n}\n\nfragment PictureMedium on Picture {\n  id\n  medium: urls(pictureRequest: {width: 264, height: 264})\n  __typename\n}\n\nfragment PictureLarge on Picture {\n  id\n  large: urls(pictureRequest: {width: 500, height: 500})\n  __typename\n}',
      'variables': {}
    });

    return me;
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
        backgroundColor: Color(0xFF6849FF),
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
                        Navigator.of(context, rootNavigator: true).maybePop();
                      },
                      icon: Icon(DeezerIcons.cross),
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
                          'Blind test',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        _load();
                      },
                      icon: Icon(DeezerIcons.question),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
              Center(
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
                  child: Text('Your best score : $bestScore'),
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
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              DeezerIcons.crown,
                              size: 30,
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Center(
                                child: Text(
                                  'Leaderboard',
                                  textHeightBehavior: TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: true,
                                  ),
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Deezer',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _leaderboard.length,
                            itemBuilder: (context, i) {
                              return ListTile(
                                leading: Text(
                                  '#${i + 1}',
                                  style: TextStyle(
                                    fontSize: 46,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Deezer',
                                  ),
                                ),
                                title: Text(_leaderboard[i]['user']['name']),
                                trailing: Text(
                                    _leaderboard[i]['bestScore'].toString()),
                              );
                            },
                          ),
                        ),
                        Text('You are #' +
                            rank.toString() +
                            ' out of ' +
                            playerCount.toString() +
                            ' players')
                      ],
                    ),
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
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              DeezerIcons.note_list,
                              size: 30,
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Center(
                                child: Text(
                                  'Played tracks',
                                  textHeightBehavior: TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: true,
                                  ),
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Deezer',
                                  ),
                                ),
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
        ));
  }
}
