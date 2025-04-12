import 'dart:math';

import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/settings.dart';
import 'package:alchemy/ui/elements.dart';
import 'package:alchemy/ui/settings_screen.dart';
import 'package:alchemy/ui/tiles.dart';
import 'package:awesome_ripple_animation/awesome_ripple_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:alchemy/api/deezer.dart';
import 'package:alchemy/api/definitions.dart';
import 'package:alchemy/utils/env.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:i18n_extension/default.i18n.dart';
import 'package:permission_handler/permission_handler.dart';

class CatcherScreen extends StatefulWidget {
  const CatcherScreen({super.key});

  @override
  _CatcherScreen createState() => _CatcherScreen();
}

class _CatcherScreen extends State<CatcherScreen>
    with TickerProviderStateMixin {
  static const platform = MethodChannel('definitely.not.deezer/native');
  static const eventChannel = EventChannel('definitely.not.deezer/events');

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late AnimationController _resultsController;
  late Animation<double> _translateAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Color?> _backgroundColorAnimation;

  StreamSubscription? _eventSubscription;
  bool _isConfigured = false;
  bool _isProcessing = false;
  bool _isFetchingTrack = false;
  String _statusMessage = 'Initializing...';
  String _lastError = '';
  Track? _identifiedTrack;

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
    _scaleAnimation = tween.animate(_controller);
    _controller.repeat(reverse: true);

    _resultsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    final curvedAnimation = CurvedAnimation(
      parent: _resultsController,
      curve: Curves.easeInOut,
    );

    _translateAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(curvedAnimation);

    _rotateAnimation =
        Tween<double>(begin: 0.0, end: 2 * pi * 2).animate(curvedAnimation);

    _backgroundColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.black.withAlpha(200),
    ).animate(curvedAnimation);
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    if (_isProcessing) platform.invokeMethod('acrCancel');
    _controller.dispose();
    _resultsController.dispose();
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
      String acrAccessKey = Env.acrcloudSongApiKey;
      String acrAccessSecret = Env.acrcloudSongApiSecret;

      final bool? result = await platform.invokeMethod('acrConfigure', {
        'host': acrHost,
        'accessKey': acrAccessKey,
        'accessSecret': acrAccessSecret,
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
    });

    try {
      await platform.invokeMethod('acrStart');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastError = 'Failed to start listening: ${e.message}';
          _statusMessage = 'Error starting';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastError = 'Unexpected error starting listening';
          _statusMessage = 'Error starting';
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
    } catch (e, stackTrace) {
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
        });
      }
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
    } catch (e, stackTrace) {
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
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height / 4),
              child: RippleAnimation(
                size: Size(MediaQuery.of(context).size.width * 0.7,
                    MediaQuery.of(context).size.width * 0.7),
                minRadius: 64,
                repeat: true,
                color: Theme.of(context).primaryColor,
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isProcessing ? _scaleAnimation.value : 1,
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: SizedBox(
                      height: MediaQuery.of(context).size.width / 0.2,
                      width: MediaQuery.of(context).size.width / 0.2,
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: ShapeDecoration(
                            shape: CircleBorder(),
                            color: Theme.of(context).scaffoldBackgroundColor),
                        child: IconButton(
                          icon: Icon(
                            AlchemyIcons.song_catcher,
                            size: MediaQuery.of(context).size.width / 2,
                          ),
                          onPressed: _isConfigured ? _toggleRecognition : null,
                        ),
                      )),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.05,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true)
                                  .maybePop();
                            },
                            icon: Icon(AlchemyIcons.cross)),
                      ),
                    ),
                  ),
                  title: const Center(
                    child: Text(
                      'Discover',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => SettingsScreen()));
                        },
                        icon: const Icon(AlchemyIcons.arrow_time),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).size.height / 6),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_isProcessing)
                          Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: MinimalistSoundWave(
                              width: 52,
                              height: 30,
                              barWidth: 4,
                              gap: 3,
                              color: Colors.white,
                            ),
                          ),
                        Text(
                          _statusMessage.i18n,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 20),
                        ),
                        if (_isProcessing)
                          Text(
                            'Make sure your device can hear the song clearly'
                                .i18n,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: Settings.secondaryText),
                          )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          if (_identifiedTrack != null)
            GestureDetector(
              onVerticalDragDown: (DragDownDetails e) {
                reverseAnimation();
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: _resultsController,
                builder: (context, child) {
                  if (_controller.status == AnimationStatus.dismissed &&
                      _controller.value == 0.0) {
                    return const SizedBox.shrink();
                  }
                  final double verticalOffset = _translateAnimation.value *
                      MediaQuery.of(context).size.height;

                  return Container(
                    color: _backgroundColorAnimation.value,
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(0, verticalOffset),
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(_rotateAnimation.value),
                        alignment: FractionalOffset.center,
                        child: child,
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  height: 350,
                  child: LargeTrackTile(
                    _identifiedTrack ?? Track(),
                    size: MediaQuery.of(context).size.width * 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
