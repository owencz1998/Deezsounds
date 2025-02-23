import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:custom_navigator/custom_navigator.dart';
import 'package:lottie/lottie.dart';
import 'package:deezer/fonts/alchemy_icons.dart';
import 'package:deezer/ui/favorite_screen.dart';
import 'package:deezer/ui/restartable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:logging/logging.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_actions/quick_actions.dart';
//import 'package:restart_app/restart_app.dart';

import 'api/cache.dart';
import 'api/deezer.dart';
import 'api/definitions.dart';
import 'api/download.dart';
import 'service/audio_service.dart';
import 'service/service_locator.dart';
import 'settings.dart';
import 'translations.i18n.dart';
import 'ui/home_screen.dart';
import 'ui/library.dart';
import 'ui/login_screen.dart';
import 'ui/player_bar.dart';
import 'ui/updater.dart';
import 'ui/search.dart';
import 'utils/logging.dart';
import 'utils/navigator_keys.dart';

late Function updateTheme;
late Function logOut;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
          child: Lottie.asset('assets/animations/logo_closing.json',
              repeat: true,
              frameRate: FrameRate(60),
              fit: MediaQuery.of(context).orientation == Orientation.portrait
                  ? BoxFit.fitWidth
                  : BoxFit.fitHeight,
              width: MediaQuery.of(context).orientation == Orientation.portrait
                  ? MediaQuery.of(context).size.width * 0.2
                  : MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).orientation == Orientation.portrait
                  ? MediaQuery.of(context).size.height
                  : MediaQuery.of(context).size.height * 0.3)),
    );
  }
}

class PlayerBarState with ChangeNotifier {
  bool _playerBarState = false;
  get state => _playerBarState;
  void setPlayerBarState(bool state) {
    _playerBarState = state;
    notifyListeners();
  }
}

PlayerBarState playerBarState = PlayerBarState();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  await prepareRun();

  runApp(const Restartable(child: ReFreezerApp()));
}

Future<void> prepareRun() async {
  await initializeLogging();
  Logger.root.info('Starting Alchemy...');
  settings = await Settings().loadSettings();
  cache = await Cache.load();
}

class ReFreezerApp extends StatefulWidget {
  const ReFreezerApp({super.key});

  @override
  _ReFreezerAppState createState() => _ReFreezerAppState();
}

class _ReFreezerAppState extends State<ReFreezerApp> {
  @override
  void initState() {
    //Make update theme global
    updateTheme = _updateTheme;
    _updateTheme();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _updateTheme() {
    setState(() {
      settings.themeData;
    });
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: settings.themeData.bottomAppBarTheme.color,
      systemNavigationBarIconBrightness:
          settings.isDark ? Brightness.light : Brightness.dark,
      statusBarColor: settings.themeData.scaffoldBackgroundColor,
    ));
    settings.save();
  }

  Locale? _locale() {
    if ((settings.language?.split('_').length ?? 0) < 2) return null;
    return Locale(
        settings.language!.split('_')[0], settings.language!.split('_')[1]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alchemy',
      shortcuts: <ShortcutActivator, Intent>{
        ...WidgetsApp.defaultShortcuts,
        LogicalKeySet(LogicalKeyboardKey.select):
            const ActivateIntent(), // DPAD center key, for remote controls
      },
      theme: settings.themeData,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      home: PopScope(
        canPop: false, // Prevent full app exit
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          // When at least 1 layer inside a custom navigator screen,
          // let the back button move back down the custom navigator stack
          if (customNavigatorKey.currentState!.canPop()) {
            await customNavigatorKey.currentState!.maybePop();
            return;
          }

          // When on a root screen of the custom navigator, move app to background with back button
          await MoveToBackground.moveTaskToBack();
          return;
        },
        child: I18n(
          initialLocale: _locale(),
          child: const LoginMainWrapper(),
        ),
      ),
      navigatorKey: mainNavigatorKey,
    );
  }
}

//Wrapper for login and main screen.
class LoginMainWrapper extends StatefulWidget {
  const LoginMainWrapper({super.key});

  @override
  _LoginMainWrapperState createState() => _LoginMainWrapperState();
}

class _LoginMainWrapperState extends State<LoginMainWrapper> {
  @override
  void initState() {
    super.initState();
    //GetIt.I<AudioPlayerHandler>().start();
    //Load token on background
    deezerAPI.arl = settings.arl;
    settings.offlineMode = true;
    deezerAPI.authorize().then((b) async {
      if (b) setState(() => settings.offlineMode = false);
    });
    //Global logOut function
    logOut = _logOut;
  }

  Future _logOut() async {
    try {
      GetIt.I<AudioPlayerHandler>().stop();
      GetIt.I<AudioPlayerHandler>().updateQueue([]);
      GetIt.I<AudioPlayerHandler>().removeSavedQueueFile();
    } catch (e, st) {
      Logger.root.severe(
          'Error stopping and clearing audio service before logout', e, st);
    }
    await downloadManager.stop();
    await DownloadManager.platform.invokeMethod('kill');
    setState(() {
      settings.arl = null;
      settings.offlineMode = false;
      deezerAPI = DeezerAPI();
    });
    await settings.save();
    await Cache.wipe();
    Restartable.restart();
    //Restart.restartApp();
  }

  @override
  Widget build(BuildContext context) {
    if (settings.arl == null) {
      return LoginWidget(
        callback: () => setState(() => {}),
      );
    }
    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late final AppLifecycleListener _lifeCycleListener;
  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const FavoriteScreen(),
    const LibraryScreen(),
  ];
  Future<void>? _initialization;
  int _selected = 0;
  StreamSubscription? _urlLinkStream;
  int _keyPressed = 0;

  @override
  void initState() {
    _lifeCycleListener =
        AppLifecycleListener(onStateChange: _onLifeCycleChanged);
    _initialization = _init();
    super.initState();
  }

  Future<void> _init() async {
    //Set display mode
    if ((settings.displayMode ?? -1) >= 0) {
      FlutterDisplayMode.supported.then((modes) async {
        if (modes.length - 1 >= settings.displayMode!.toInt()) {
          FlutterDisplayMode.setPreferredMode(
              modes[settings.displayMode!.toInt()]);
        }
      });
    }

    _preloadFavoriteTracksToCache();
    _initDownloadManager();
    _startStreamingServer();
    await _setupServiceLocator();

    //Do on BG
    GetIt.I<AudioPlayerHandler>().authorizeLastFM();

    //Start with parameters
    _setupDeepLinks();
    _loadPreloadInfo();
    _prepareQuickActions();

    //Check for updates on background
    Future.delayed(const Duration(seconds: 5), () {
      DeezerLatest.checkUpdate();
    });

    //Restore saved queue
    _loadSavedQueue();

    GetIt.I<AudioPlayerHandler>().playbackState.listen((event) {
      playerBarState.setPlayerBarState(
          GetIt.I<AudioPlayerHandler>().playbackState.value.processingState !=
                  AudioProcessingState.idle &&
              GetIt.I<AudioPlayerHandler>().mediaItem.value != null);
    });
  }

  void _preloadFavoriteTracksToCache() async {
    try {
      cache.libraryTracks = await deezerAPI.getFavoriteTrackIds();
      Logger.root
          .info('Cached favorite trackIds: ${cache.libraryTracks?.length}');
    } catch (e, st) {
      Logger.root.severe('Error loading favorite trackIds!', e, st);
    }
  }

  void _initDownloadManager() async {
    await downloadManager.init();
  }

  void _startStreamingServer() async {
    await DownloadManager.platform
        .invokeMethod('startServer', {'arl': settings.arl});
  }

  Future<void> _setupServiceLocator() async {
    await setupServiceLocator();
    // Wait for the player to be initialized
    await GetIt.I<AudioPlayerHandler>().waitForPlayerInitialization();
  }

  void _prepareQuickActions() {
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((type) {
      _startPreload(type);
    });

    //Actions
    quickActions.setShortcutItems([
      ShortcutItem(
          type: 'favorites',
          localizedTitle: 'Favorites'.i18n,
          icon: 'ic_favorites'),
      ShortcutItem(type: 'flow', localizedTitle: 'Flow'.i18n, icon: 'ic_flow'),
    ]);
  }

  void _startPreload(String type) async {
    await deezerAPI.authorize();
    if (type == 'flow') {
      await GetIt.I<AudioPlayerHandler>()
          .playFromSmartTrackList(SmartTrackList(id: 'flow'));
      return;
    }
    if (type == 'favorites') {
      Playlist p = await deezerAPI
          .fullPlaylist(deezerAPI.favoritesPlaylistId.toString());
      GetIt.I<AudioPlayerHandler>().playFromPlaylist(p, p.tracks?[0].id ?? '');
    }
  }

  void _loadPreloadInfo() async {
    String info =
        await DownloadManager.platform.invokeMethod('getPreloadInfo') ?? '';
    if (info.isEmpty) return;
    _startPreload(info);
  }

  Future<void> _loadSavedQueue() async {
    GetIt.I<AudioPlayerHandler>().loadQueueFromFile();
  }

  @override
  void dispose() {
    _urlLinkStream?.cancel();
    _lifeCycleListener.dispose();
    super.dispose();
  }

  void _onLifeCycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        Logger.root.info('App detached.');
        GetIt.I<AudioPlayerHandler>().dispose();
        downloadManager.stop();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
    }
  }

  void _setupDeepLinks() async {
    AppLinks deepLinks = AppLinks();

    // Check initial link if app was in cold state (terminated)
    final deepLink = await deepLinks.getInitialLinkString();
    if (deepLink != null && deepLink.length > 4) {
      Logger.root.info('Opening app from deeplink: $deepLink');
      openScreenByURL(deepLink);
    }

    //Listen to URLs when app is in warm state (front or background)
    _urlLinkStream = deepLinks.stringLinkStream.listen((deeplink) {
      Logger.root.info('Opening deeplink: $deeplink');
      openScreenByURL(deeplink);
    }, onError: (e) {
      Logger.root.severe('Error handling app link: $e');
    });
  }

  void _handleKey(KeyEvent event, FocusScopeNode navigationBarFocusNode,
      FocusNode screenFocusNode) {
    FocusNode? primaryFocus = FocusManager.instance.primaryFocus;

    // Movement to navigation bar and back
    if (event is KeyDownEvent) {
      final logicalKey = event.logicalKey;
      final keyCode = logicalKey.keyId;

      if (logicalKey == LogicalKeyboardKey.tvContentsMenu) {
        // Menu key on Android TV
        focusToNavbar(navigationBarFocusNode);
      } else if (keyCode == 0x100070000127) {
        // EPG key on Hisense TV (example, you need to find correct LogicalKeyboardKey or define it)
        focusToNavbar(navigationBarFocusNode);
      } else if (logicalKey == LogicalKeyboardKey.arrowLeft ||
          logicalKey == LogicalKeyboardKey.arrowRight) {
        if ((_keyPressed == LogicalKeyboardKey.arrowLeft.keyId &&
                logicalKey == LogicalKeyboardKey.arrowRight) ||
            (_keyPressed == LogicalKeyboardKey.arrowRight.keyId &&
                logicalKey == LogicalKeyboardKey.arrowLeft)) {
          // LEFT + RIGHT
          focusToNavbar(navigationBarFocusNode);
        }
        _keyPressed = logicalKey.keyId;
        Future.delayed(const Duration(milliseconds: 100), () {
          _keyPressed = 0;
        });
      } else if (logicalKey == LogicalKeyboardKey.arrowDown) {
        // If it's bottom row, go to navigation bar
        var row = primaryFocus?.parent;
        if (row != null) {
          var column = row.parent;
          if (column?.children.last == row) {
            focusToNavbar(navigationBarFocusNode);
          }
        }
      } else if (logicalKey == LogicalKeyboardKey.arrowUp) {
        if (navigationBarFocusNode.hasFocus) {
          screenFocusNode.parent!.parent?.children
              .last // children.last is used for handling "playlists" screen in library. Under CustomNavigator 2 screens appears.
              .nextFocus(); // nextFocus is used instead of requestFocus because it focuses on last, bottom, non-visible tile of main page
        }
      }
    }
  }

  void focusToNavbar(FocusScopeNode navigatorFocusNode) {
    navigatorFocusNode.requestFocus();
    navigatorFocusNode.focusInDirection(TraversalDirection
        .down); // If player bar is hidden, focus won't be visible, so go down once more
  }

  @override
  Widget build(BuildContext context) {
    FocusScopeNode navigationBarFocusNode =
        FocusScopeNode(); // for bottom navigation bar
    FocusNode screenFocusNode = FocusNode(); // for CustomNavigator
    screenFocusNode.requestFocus();

    Color scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Theme.of(context).scaffoldBackgroundColor,
      systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
    ));

    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        // Check _initialization status
        if (snapshot.connectionState == ConnectionState.done) {
          // When _initialization is done, render app

          return OrientationBuilder(
            builder: (context, orientation) {
              return KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) => _handleKey(
                      event, navigationBarFocusNode, screenFocusNode),
                  child: Scaffold(
                      backgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      bottomNavigationBar: orientation == Orientation.portrait
                          ? FocusScope(
                              node: navigationBarFocusNode,
                              child: Theme(
                                  data: Theme.of(context).copyWith(
                                      canvasColor: Theme.of(context)
                                          .scaffoldBackgroundColor,
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent),
                                  child: BottomNavigationBar(
                                    type: BottomNavigationBarType.fixed,
                                    unselectedItemColor:
                                        Theme.of(context).unselectedWidgetColor,
                                    currentIndex: _selected,
                                    onTap: (int index) async {
                                      //Pop all routes until home screen
                                      while (customNavigatorKey.currentState!
                                          .canPop()) {
                                        await customNavigatorKey.currentState!
                                            .maybePop();
                                      }

                                      await customNavigatorKey.currentState!
                                          .maybePop();

                                      setState(() {
                                        _selected = index;
                                      });

                                      SystemChrome.setSystemUIOverlayStyle(
                                          SystemUiOverlayStyle(
                                        statusBarColor: scaffoldBackgroundColor,
                                      ));
                                    },
                                    selectedItemColor:
                                        settings.primaryColor.withAlpha(200),
                                    showUnselectedLabels: true,
                                    selectedLabelStyle:
                                        TextStyle(color: settings.primaryColor),
                                    unselectedLabelStyle: TextStyle(
                                        color: Settings.secondaryText),
                                    items: <BottomNavigationBarItem>[
                                      BottomNavigationBarItem(
                                          activeIcon: const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child:
                                                Icon(AlchemyIcons.house_fill),
                                          ),
                                          icon: const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Icon(AlchemyIcons.house),
                                          ),
                                          label: 'Home'.i18n),
                                      BottomNavigationBarItem(
                                        activeIcon: const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Icon(AlchemyIcons.search_fill),
                                        ),
                                        icon: const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Icon(AlchemyIcons.search),
                                        ),
                                        label: 'Search'.i18n,
                                      ),
                                      BottomNavigationBarItem(
                                          activeIcon: const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child:
                                                Icon(AlchemyIcons.heart_fill),
                                          ),
                                          icon: const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Icon(AlchemyIcons.heart),
                                          ),
                                          label: 'Library'.i18n),
                                      BottomNavigationBarItem(
                                          activeIcon: const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child:
                                                Icon(AlchemyIcons.human_fill),
                                          ),
                                          icon: const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Icon(AlchemyIcons.human),
                                          ),
                                          label: 'Profile'.i18n),
                                    ],
                                  )))
                          : null,
                      body: Row(
                        children: [
                          if (orientation == Orientation.landscape)
                            LayoutBuilder(builder: (context, constraints) {
                              return SingleChildScrollView(
                                  physics: NeverScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight),
                                      child: IntrinsicHeight(
                                          child: NavigationRail(
                                        destinations: [
                                          NavigationRailDestination(
                                              selectedIcon: const Icon(
                                                  AlchemyIcons.house_fill),
                                              icon: const Icon(
                                                  AlchemyIcons.house),
                                              label: Text('Home'.i18n)),
                                          NavigationRailDestination(
                                            selectedIcon: const Icon(
                                                AlchemyIcons.search_fill),
                                            icon:
                                                const Icon(AlchemyIcons.search),
                                            label: Text('Search'.i18n),
                                          ),
                                          NavigationRailDestination(
                                              selectedIcon: const Icon(
                                                  AlchemyIcons.heart_fill),
                                              icon: const Icon(
                                                  AlchemyIcons.heart),
                                              label: Text('Library'.i18n)),
                                          NavigationRailDestination(
                                              selectedIcon: const Icon(
                                                  AlchemyIcons.human_fill),
                                              icon: const Icon(
                                                  AlchemyIcons.human),
                                              label: Text('Profile'.i18n)),
                                        ],
                                        selectedIndex: _selected,
                                        onDestinationSelected:
                                            (int index) async {
                                          //Pop all routes until home screen
                                          while (customNavigatorKey
                                              .currentState!
                                              .canPop()) {
                                            await customNavigatorKey
                                                .currentState!
                                                .maybePop();
                                          }

                                          await customNavigatorKey.currentState!
                                              .maybePop();

                                          setState(() {
                                            _selected = index;
                                          });

                                          SystemChrome.setSystemUIOverlayStyle(
                                              SystemUiOverlayStyle(
                                            statusBarColor:
                                                scaffoldBackgroundColor,
                                          ));
                                        },
                                        selectedIconTheme: IconThemeData(
                                            color: settings.primaryColor),
                                        groupAlignment: 0,
                                        selectedLabelTextStyle: TextStyle(
                                            color: settings.primaryColor),
                                        unselectedIconTheme: IconThemeData(
                                            color: Settings.secondaryText),
                                        unselectedLabelTextStyle: TextStyle(
                                            color: Settings.secondaryText),
                                        labelType: NavigationRailLabelType.all,
                                        backgroundColor:
                                            Colors.white.withAlpha(30),
                                      ))));
                            }),
                          Expanded(
                            child: Stack(
                              children: [
                                CustomNavigator(
                                    navigatorKey: customNavigatorKey,
                                    home: Focus(
                                      focusNode: screenFocusNode,
                                      skipTraversal: true,
                                      canRequestFocus: false,
                                      child: _screens[_selected],
                                    ),
                                    pageRoute: PageRoutes.materialPageRoute),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    color: Colors.transparent,
                                    margin: MediaQuery.of(context)
                                                .orientation ==
                                            Orientation.portrait
                                        ? EdgeInsets.all(8)
                                        : EdgeInsets.fromLTRB(
                                            MediaQuery.of(context).size.width *
                                                    0.4 +
                                                8,
                                            8,
                                            8,
                                            8),
                                    child: const PlayerBar(),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      )));
            },
          );
        } else {
          // While audio_service is initializing
          return SplashScreen();
        }
      },
    );
  }
}
