import 'dart:math';

import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/service/audio_service.dart';
import 'package:alchemy/settings.dart';
import 'package:alchemy/ui/cached_image.dart';
import 'package:alchemy/ui/elements.dart';
import 'package:alchemy/ui/menu.dart';
import 'package:alchemy/ui/player_screen.dart';
import 'package:alchemy/ui/settings_screen.dart';
import 'package:awesome_ripple_animation/awesome_ripple_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'dart:async';
import 'dart:convert';
import 'package:alchemy/api/deezer.dart';
import 'package:alchemy/api/definitions.dart';
import 'package:alchemy/utils/env.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:i18n_extension/default.i18n.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

class CatcherScreen extends StatefulWidget {
  const CatcherScreen({super.key});

  @override
  _CatcherScreen createState() => _CatcherScreen();
}

enum RecognitionType { Songs, Hums }

class _CatcherScreen extends State<CatcherScreen>
    with TickerProviderStateMixin {
  static const platform = MethodChannel('definitely.not.deezer/native');
  static const eventChannel = EventChannel('definitely.not.deezer/events');

  late AnimationController _controller;
  late AnimationController _resultsController;
  late AnimationController _buttonController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _resultsAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Color?> _backgroundColorAnimation;
  late Animation<Offset> _buttonAnimation;

  StreamSubscription? _eventSubscription;
  bool _isConfigured = false;
  bool _isProcessing = false;
  bool _isFetchingTrack = false;
  String _statusMessage = 'Initializing...';
  String _lastError = '';
  Track? _identifiedTrack;
  double screenHeight = 3.0;

  RecognitionType recognitionType = RecognitionType.Songs;

  @override
  void initState() {
    super.initState();
    _listenToEvents();
    _configureAcrCloud();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    final tween = Tween<double>(begin: 0.9, end: 1.1);
    _scaleAnimation = tween
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
      ..addListener(() {});
    _controller.repeat(reverse: true);

    _resultsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    final curvedAnimation = CurvedAnimation(
      parent: _resultsController,
      curve: Curves.easeInOut,
    );

    _resultsAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(curvedAnimation);

    _rotateAnimation =
        Tween<double>(begin: 0.0, end: 2 * pi * 2).animate(curvedAnimation);

    _backgroundColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.black.withAlpha(200),
    ).animate(curvedAnimation);

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    final CurvedAnimation buttonCurve = CurvedAnimation(
        parent: _buttonController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut);

    _buttonAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(0, (screenHeight * 0.1) / 38 + 38),
    ).animate(buttonCurve);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    _eventSubscription?.cancel();
    if (_isProcessing) platform.invokeMethod('acrCancel');
    _controller.dispose();
    _resultsController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void startAnimation() {
    _resultsController.forward(from: 0.0);
  }

  void reverseAnimation() async {
    await _resultsController.reverse(from: 1.0);
    if (mounted) {
      setState(() {
        _identifiedTrack = null;
        _statusMessage = 'Tap to recognize';
        _buttonController.reverse(from: 1.0);
      });
    }
  }

  void _listenToEvents() {
    _eventSubscription =
        eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is! Map || !mounted) return;

      final Map<dynamic, dynamic> eventData = event;
      final String? eventType = eventData['eventType'] as String?;

      setState(() {
        if (eventType != 'acrError') {
          _lastError = '';
        }

        switch (eventType) {
          case 'acrState':
            final Map<dynamic, dynamic>? stateData = eventData['data'] as Map?;
            if (stateData != null) {
              _isConfigured =
                  stateData['initialized'] as bool? ?? _isConfigured;
              final bool wasProcessing = _isProcessing;
              _isProcessing = stateData['processing'] as bool? ?? _isProcessing;
              if (!_isConfigured) {
                _statusMessage = 'ACRCloud not configured.';
              } else if (_isProcessing) {
                _statusMessage = 'Listening for music';
              } else if (wasProcessing && !_isProcessing) {
                if (!_isFetchingTrack &&
                    _identifiedTrack == null &&
                    _lastError.isEmpty) {
                  _statusMessage = 'Could not identify track.';
                }
              } else if (_identifiedTrack == null && !_isFetchingTrack) {
                _statusMessage = 'Tap to recognize';
              }
              if (!_isProcessing && !_isFetchingTrack) {
                _isFetchingTrack = false;
              }
            }
            break;

          case 'acrResult':
            _isProcessing = false;
            _isFetchingTrack = true;
            _statusMessage = 'Looks like we found something...';
            _identifiedTrack = null;
            _handleAcrResult(eventData['resultJson'] as String?);
            break;

          case 'acrError':
            _isProcessing = false;
            _isFetchingTrack = false;
            _identifiedTrack = null;
            _lastError =
                eventData['error'] as String? ?? 'Unknown ACRCloud error';
            _statusMessage = 'Error occurred.';
            break;

          case 'acrVolume':
            break;

          default:
        }
      });
    }, onError: (dynamic error) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isFetchingTrack = false;
          _identifiedTrack = null;
          _lastError = 'EventChannel communication error.';
          _statusMessage = 'Error occurred.';
        });
      }
    }, onDone: () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isFetchingTrack = false;
        });
      }
    });
  }

  Future<void> _configureAcrCloud() async {
    setState(() {
      _statusMessage = 'Configuring ACRCloud...';
      _lastError = '';
    });
    try {
      String acrHost = Env.acrcloudHost;
      String acrSongAccessKey = Env.acrcloudSongApiKey;
      String acrSongAccessSecret = Env.acrcloudSongApiSecret;
      String acrHumsAccessKey = Env.acrcloudHumsApiKey;
      String acrHumsAccessSecret = Env.acrcloudHumsApiSecret;

      final bool? result = await platform.invokeMethod('acrConfigure', {
        'host': acrHost,
        'accessKey': recognitionType == RecognitionType.Songs
            ? acrSongAccessKey
            : acrHumsAccessKey,
        'accessSecret': recognitionType == RecognitionType.Songs
            ? acrSongAccessSecret
            : acrHumsAccessSecret,
      });

      if (mounted) {
        setState(() {
          if (result == true) {
            _isConfigured = true;
            _statusMessage = 'Tap to recognize';
          } else {
            _isConfigured = false;
            _lastError = 'ACRCloud configuration failed (native).';
            _statusMessage = 'Configuration failed';
          }
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isConfigured = false;
          _lastError = 'Failed to configure ACRCloud: ${e.message}';
          _statusMessage = 'Configuration failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfigured = false;
          _lastError = 'Unexpected error during configuration.';
          _statusMessage = 'Configuration failed';
        });
      }
    }
  }

  void _toggleRecognitionType() {
    if (_isProcessing || _isFetchingTrack) {
      return;
    }

    setState(() {
      recognitionType = (recognitionType == RecognitionType.Songs)
          ? RecognitionType.Hums
          : RecognitionType.Songs;
    });
    _configureAcrCloud();
  }

  Future<void> _toggleRecognition() async {
    if (!_isConfigured) {
      _showSnackBar('ACRCloud is not configured');
      return;
    }
    if (_isProcessing || _isFetchingTrack) {
      _cancelRecognition();
      return;
    }

    var status = await Permission.microphone.status;
    if ((status.isDenied || status.isPermanentlyDenied)) {
      var micPermission = await [
        Permission.microphone,
      ].request();
      if (!micPermission.containsValue(PermissionStatus.granted)) return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Starting...';
      _lastError = '';
      _identifiedTrack = null;
      _buttonController.forward(from: 0);
    });

    try {
      await platform.invokeMethod('acrStart');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastError = 'Failed to start listening: ${e.message}';
          _statusMessage = 'Error starting';
          _buttonController.reverse(from: 1);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastError = 'Unexpected error starting listening';
          _statusMessage = 'Error starting';
          _buttonController.reverse(from: 1);
        });
      }
    }
  }

  Future<void> _cancelRecognition() async {
    if (!_isProcessing && !_isFetchingTrack) return;

    final bool wasProcessing = _isProcessing;

    setState(() {
      _isProcessing = false;
      _isFetchingTrack = false;
      _statusMessage = 'Cancelling...';
    });

    if (wasProcessing) {
      try {
        await platform.invokeMethod('acrCancel');
        _buttonController.reverse(from: 1);
      } on PlatformException catch (e) {
        if (mounted) {
          setState(() {
            _lastError = 'Failed to send cancel command: ${e.message}';
            _statusMessage = 'Error cancelling';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          if (_identifiedTrack != null) {
            _statusMessage = 'Track details loaded';
          } else {
            _statusMessage = 'Ready to listen';
          }
          _buttonController.reverse(from: 1);
        });
      }
    }
  }

  Future<void> _handleAcrResult(String? resultJson) async {
    if (resultJson == null || resultJson.isEmpty) {
      if (mounted) {
        setState(() {
          _statusMessage = 'No result data received';
          _isFetchingTrack = false;
        });
      }
      return;
    }

    try {
      final Map<String, dynamic> resultData = jsonDecode(resultJson);
      final status = resultData['status'];

      if (status != null && status['code'] == 0) {
        final metadata = resultData['metadata'];

        if (metadata['music'] != null) {
          final musicList = metadata?['music'] as List?;

          if (musicList != null && musicList.isNotEmpty) {
            final trackInfo = musicList[0];
            final externalMetadata = trackInfo['external_metadata'];
            final deezerMetadata = externalMetadata?['deezer'];
            final String? deezerTrackId =
                deezerMetadata?['track']?['id']?.toString();

            if (deezerTrackId != null && deezerTrackId.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _statusMessage = 'Track identified! Fetching details...';
                });
              }

              await _fetchTrackDetails(deezerTrackId);
              return;
            } else {
              if (mounted) {
                setState(() {
                  _statusMessage = 'Track recognized, but no Deezer link found';
                  _isFetchingTrack = false;
                });
              }
            }
          } else {
            if (mounted) {
              setState(() {
                _statusMessage = 'No track identified in the recording';
                _isFetchingTrack = false;
              });
            }
          }
        } else if (metadata['humming'] != null) {
          final musicList = metadata?['humming'] as List?;

          if (musicList != null && musicList.isNotEmpty) {
            final trackInfo = musicList[0];
            String? trackTitle = trackInfo['title'];
            List<dynamic>? trackArtists =
                ((trackInfo['artists'] as List<dynamic>?)?.where(
                    (dynamic artistInfos) =>
                        (artistInfos['roles'] as List<dynamic>?)
                            ?.contains('MainArtist') ??
                        false))?.toList();

            String? trackArtist = (trackArtists?.isNotEmpty ?? false)
                ? (trackArtists?[0])['name']
                : trackInfo['artists']?[0]?['name'];

            if (trackTitle != null) {
              if (mounted) {
                setState(() {
                  _statusMessage = 'Track identified! Fetching details...';
                });
              }

              await _fetchHumsDetails(trackTitle, trackArtist ?? '');
              return;
            } else {
              if (mounted) {
                setState(() {
                  _statusMessage = 'Track recognized, but no Deezer link found';
                  _isFetchingTrack = false;
                });
              }
            }
          } else {
            if (mounted) {
              setState(() {
                _statusMessage = 'No track identified in the recording';
                _isFetchingTrack = false;
              });
            }
          }
        }
      } else {
        final String msg = status?['msg'] ?? 'Unknown recognition issue';
        final int code = status?['code'] ?? -1;

        if (mounted) {
          setState(() {
            Fluttertoast.showToast(
                msg: (code == 1001 ||
                        code == 2004 ||
                        code == 3000 ||
                        code == 3003 ||
                        code == 3014 ||
                        code == 3015)
                    ? 'No track identified ($msg)'
                    : 'Recognition error ($msg)');
            _isFetchingTrack = false;
            _statusMessage = 'Tap to recognize';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastError = 'Error processing result';
          _statusMessage = 'Error occurred';
          _isFetchingTrack = false;
        });
      }
    } finally {
      if (mounted && _isFetchingTrack && _identifiedTrack == null) {
        setState(() {
          _isFetchingTrack = false;
          if (_statusMessage.contains('Fetching')) {
            _statusMessage = 'Failed to fetch track details';
          } else if (_lastError.isEmpty &&
              _statusMessage.contains('Processing')) {
            _statusMessage = 'Could not identify track';
          }
          _buttonController.reverse(from: 1);
        });
      }
    }
  }

  Future<void> _fetchHumsDetails(String trackTitle, String trackArtist) async {
    try {
      if (!mounted || !_isFetchingTrack) {
        return;
      }

      Map<String, dynamic> jsonResult =
          await deezerAPI.callGwApi('search_music', params: {
        'QUERY': "'$trackTitle' '$trackArtist'",
        'FILTER': 'TRACK',
        'OUTPUT': 'TRACK',
        'NB': '1',
        'START': '0',
      });

      Logger.root.info(jsonResult);

      Track track;

      if (jsonResult['results']['data'] != null &&
          jsonResult['results']['data'].isNotEmpty) {
        try {
          track = Track.fromPrivateJson(jsonResult['results']['data'][0]);
        } catch (_) {
          track =
              Track(title: trackTitle, artists: [Artist(name: trackArtist)]);
        }
      } else {
        track = Track(title: trackTitle, artists: [Artist(name: trackArtist)]);
      }

      Logger.root.info(track.toJson());

      if (mounted && _isFetchingTrack) {
        setState(() {
          _identifiedTrack = track;
          _statusMessage = 'Track details loaded';
          _isFetchingTrack = false;
          _lastError = '';
          startAnimation();
        });
      } else if (mounted) {
        setState(() {
          _isFetchingTrack = false;
          if (_identifiedTrack == null) {
            _statusMessage = 'Tap to recognize';
          }
        });
      }
    } catch (e) {
      if (mounted && _isFetchingTrack) {
        setState(() {
          _identifiedTrack = null;
          _lastError = 'Failed to fetch track details from Deezer';
          _statusMessage = 'Error loading details';
          _isFetchingTrack = false;
        });
      } else if (mounted) {
        setState(() {
          _isFetchingTrack = false;
          if (_identifiedTrack == null && _lastError.isEmpty) {
            _statusMessage = 'Ready to listen';
          }
        });
      }
      reverseAnimation();
    }
  }

  Future<void> _fetchTrackDetails(String trackId) async {
    try {
      if (!mounted || !_isFetchingTrack) {
        return;
      }

      final Track track = await deezerAPI.track(trackId);

      if (mounted && _isFetchingTrack) {
        setState(() {
          _identifiedTrack = track;
          _statusMessage = 'Track details loaded';
          _isFetchingTrack = false;
          _lastError = '';
          startAnimation();
        });
      } else if (mounted) {
        setState(() {
          _isFetchingTrack = false;
          if (_identifiedTrack == null) {
            _statusMessage = 'Tap to recognize';
          }
        });
      }
    } catch (e) {
      if (mounted && _isFetchingTrack) {
        setState(() {
          _identifiedTrack = null;
          _lastError = 'Failed to fetch track details from Deezer';
          _statusMessage = 'Error loading details';
          _isFetchingTrack = false;
        });
      } else if (mounted) {
        setState(() {
          _isFetchingTrack = false;
          if (_identifiedTrack == null && _lastError.isEmpty) {
            _statusMessage = 'Ready to listen';
          }
        });
      }
      reverseAnimation();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    final mediaQuery = MediaQuery.of(context);
    if (mounted) {
      setState(() {
        screenHeight = mediaQuery.size.height;
      });
    }

    final screenWidth = mediaQuery.size.width;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height / 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.15),
                    child: _RecognitionButton(
                      isProcessing: _isProcessing,
                      isConfigured: _isConfigured,
                      scaleAnimation: _scaleAnimation,
                      onPressed: _toggleRecognition,
                      buttonSize: screenWidth * 0.65,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  _StatusDisplay(
                    isProcessing: _isProcessing,
                    statusMessage: _statusMessage,
                    recognitionType: recognitionType,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: screenHeight * 0.1),
              child: SlideTransition(
                position: _buttonAnimation,
                child: ElevatedButton(
                  onPressed: _toggleRecognitionType,
                  style: ElevatedButton.styleFrom(
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                        cornerRadius: 10,
                        cornerSmoothing: 1,
                      ),
                    ),
                    maximumSize: Size(128, 38),
                    minimumSize: Size(128, 38),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: Text(
                    recognitionType == RecognitionType.Songs
                        ? 'Sing or Hum?'.i18n
                        : 'Identify Song?'.i18n,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _CatcherAppBar(
                screenWidth: screenWidth,
                onClose: () =>
                    Navigator.of(context, rootNavigator: true).maybePop(),
                onHistory: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const SettingsScreen())),
              ),
            ),
          ),
          if (_identifiedTrack != null)
            GestureDetector(
              onVerticalDragStart: (DragStartDetails e) {
                reverseAnimation();
              },
              child: AnimatedBuilder(
                animation: _resultsController,
                builder: (context, child) {
                  if (_controller.status == AnimationStatus.dismissed &&
                      _controller.value == 0.0) {
                    return const SizedBox.shrink();
                  }
                  final double verticalOffset = _resultsAnimation.value *
                      MediaQuery.of(context).size.height;

                  return Container(
                    color: _backgroundColorAnimation.value,
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        SafeArea(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: AnimatedOpacity(
                                duration: Duration(milliseconds: 500),
                                opacity: 1 - _resultsAnimation.value,
                                child: _AcrCloudAttribution(),
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, verticalOffset),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_identifiedTrack?.albumArt?.fullUrl !=
                                      null)
                                    Transform(
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, 0.001)
                                        ..rotateY(_rotateAnimation.value),
                                      alignment: FractionalOffset.center,
                                      child: child,
                                    ),
                                  Padding(padding: EdgeInsets.only(bottom: 12)),
                                  Text(_identifiedTrack?.title ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20)),
                                  Text(_identifiedTrack?.artists?[0].name ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w300,
                                          fontSize: 16)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: ActionControls(24.0),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      GetIt.I<AudioPlayerHandler>()
                                          .playFromTrackList(
                                        [_identifiedTrack ?? Track()],
                                        _identifiedTrack?.id ?? '',
                                        QueueSource(
                                            id: _identifiedTrack?.id,
                                            text: 'Favorites'.i18n,
                                            source: 'track'),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      shape: SmoothRectangleBorder(
                                        borderRadius: SmoothBorderRadius(
                                          cornerRadius: 10,
                                          cornerSmoothing: 1,
                                        ),
                                      ),
                                      maximumSize: Size(128, 38),
                                      minimumSize: Size(128, 38),
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          AlchemyIcons.play,
                                          size: 14,
                                        ),
                                        SizedBox(
                                          width: 8,
                                        ),
                                        Text(
                                          'Play',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
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
                  );
                },
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => {},
                  onLongPress: () {
                    MenuSheet m = MenuSheet();
                    m.defaultTrackMenu(_identifiedTrack!, context: context);
                  },
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: ShapeDecoration(
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(
                          cornerRadius: 30,
                          cornerSmoothing: 0.8,
                        ),
                      ),
                    ),
                    child: CachedImage(
                      url: _identifiedTrack?.albumArt?.fullUrl ?? '',
                      height: MediaQuery.of(context).size.width * 0.6,
                      width: MediaQuery.of(context).size.width * 0.6,
                    ),
                  ),
                ),
              ),
            ),
          if (_identifiedTrack != null)
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05, vertical: 8),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 24,
                  onPressed: reverseAnimation,
                  icon: const Icon(AlchemyIcons.cross),
                  tooltip: 'Close'.i18n,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatcherAppBar extends StatelessWidget {
  final double screenWidth;
  final VoidCallback onClose;
  final VoidCallback onHistory;

  const _CatcherAppBar({
    required this.screenWidth,
    required this.onClose,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            iconSize: 24,
            onPressed: onClose,
            icon: const Icon(AlchemyIcons.cross),
            tooltip: 'Close'.i18n,
          ),
          Text(
            'Discover'.i18n,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            iconSize: 24,
            onPressed: onHistory,
            icon: const Icon(AlchemyIcons.arrow_time),
            tooltip: 'History'.i18n,
          ),
        ],
      ),
    );
  }
}

class _RecognitionButton extends StatelessWidget {
  final bool isProcessing;
  final bool isConfigured;
  final Animation<double> scaleAnimation;
  final VoidCallback onPressed;
  final double buttonSize;

  const _RecognitionButton({
    required this.isProcessing,
    required this.isConfigured,
    required this.scaleAnimation,
    required this.onPressed,
    required this.buttonSize,
  });

  @override
  Widget build(BuildContext context) {
    final Widget buttonContent = Container(
      width: buttonSize * 0.8,
      height: buttonSize * 0.8,
      clipBehavior: Clip.hardEdge,
      decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: Theme.of(context).scaffoldBackgroundColor,
          shadows: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]),
      child: IconButton(
        iconSize: buttonSize * 0.8,
        color: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(AlchemyIcons.song_catcher),
        tooltip: 'Tap to recognize'.i18n,
        onPressed: isConfigured ? onPressed : null,
      ),
    );

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: isProcessing
          ? RippleAnimation(
              size: Size(buttonSize, buttonSize),
              minRadius: buttonSize * 0.4,
              repeat: true,
              color: Theme.of(context).primaryColor.withAlpha(180),
              child: AnimatedBuilder(
                animation: scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: scaleAnimation.value,
                    alignment: Alignment.center,
                    child: child,
                  );
                },
                child: buttonContent,
              ),
            )
          : buttonContent,
    );
  }
}

class _StatusDisplay extends StatelessWidget {
  final bool isProcessing;
  final String statusMessage;
  final RecognitionType recognitionType;

  const _StatusDisplay({
    required this.isProcessing,
    required this.statusMessage,
    required this.recognitionType,
  });

  @override
  Widget build(BuildContext context) {
    String hintText = '';
    if (isProcessing) {
      hintText = 'Make sure your device can hear clearly'.i18n;
    } else if (statusMessage == 'Tap to recognize'.i18n) {
      hintText = recognitionType == RecognitionType.Songs
          ? 'Listening for songs'.i18n
          : 'Listening for singing or humming'.i18n;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                      .animate(animation),
              child: child),
        );
      },
      child: Column(
        key: ValueKey<String>('$statusMessage::$hintText'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isProcessing)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: MinimalistSoundWave(
                width: 52,
                height: 30,
                barWidth: 4,
                gap: 3,
                color: Colors.white,
              ),
            ),
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          if (hintText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hintText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: Settings.secondaryText,
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _AcrCloudAttribution extends StatelessWidget {
  const _AcrCloudAttribution();

  @override
  Widget build(BuildContext context) {
    final Color? textColor =
        Theme.of(context).textTheme.bodySmall?.color?.withAlpha(180);

    return RichText(
        text: TextSpan(
            style: TextStyle(
                fontSize: 11, color: textColor, fontWeight: FontWeight.w300),
            children: <TextSpan>[
          const TextSpan(text: 'Powered by '),
          TextSpan(
              text: 'ACR',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: textColor?.withAlpha(230))),
          TextSpan(
              text: 'Cloud',
              style: TextStyle(
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: textColor)),
        ]));
  }
}
