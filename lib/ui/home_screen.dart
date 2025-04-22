import 'dart:async';
import 'dart:math';

import 'package:alchemy/api/cache.dart';
import 'package:alchemy/ui/blind_test.dart';
import 'package:alchemy/ui/cached_image.dart';
import 'package:alchemy/ui/card_carousel.dart';
import 'package:alchemy/ui/notification_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get_it/get_it.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/main.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../api/deezer.dart';
import '../api/definitions.dart';
import '../service/audio_service.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';
import '../ui/error.dart';
import '../ui/menu.dart';
import 'details_screens.dart';
import 'tiles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  String displayName = '';
  String imageUrl = '';

  List<DeezerNotification>? notifications;
  bool hasNewNotifications = false;

  void _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    await deezerAPI.rawAuthorize();

    if (mounted) {
      setState(() {
        displayName = cache.userName;
        imageUrl = ImageDetails.fromJson(cache.userPicture).fullUrl ??
            ImageDetails.fromJson(cache.userPicture).thumbUrl ??
            '';
        _isLoading = false;
      });
    }
  }

  void fetchNotifications() async {
    List<DeezerNotification> noti = await deezerAPI.getNotifications();
    if (mounted) {
      setState(() {
        notifications = noti;
        hasNewNotifications =
            noti.any((DeezerNotification n) => n.read == false);
      });
    }
  }

  @override
  void initState() {
    if (cache.userName == '' || cache.userPicture == {}) {
      _load();
    } else {
      if (mounted) {
        setState(() {
          displayName = cache.userName;
          imageUrl = ImageDetails.fromJson(cache.userPicture).fullUrl ?? '';
        });
      }
    }

    fetchNotifications();

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        scrollDirection: Axis.vertical,
        children: [
          Padding(padding: EdgeInsets.only(top: 4.0)),
          ListTile(
            onTap: () {
              deezerAPI.testFunction();
            },
            contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: _isLoading
                      ? CircularProgressIndicator()
                      : CachedImage(
                          url: ImageDetails.fromJson(cache.userPicture)
                                  .fullUrl ??
                              '',
                          circular: true,
                          width: 60,
                        ),
                ),
              ),
            ),
            title: Text(
              'Hi $displayName',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Welcome back !',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            trailing: SizedBox(
              height: 60,
              width: 60,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  splashRadius: 20,
                  alignment: Alignment.center,
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            NotificationScreen(notifications ?? [])));
                    fetchNotifications();
                  },
                  icon: Icon(
                    hasNewNotifications
                        ? AlchemyIcons.bell_active
                        : AlchemyIcons.bell,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                  child: ListenableBuilder(
                      listenable: playerBarState,
                      builder: (BuildContext context, Widget? child) {
                        return AnimatedPadding(
                          duration: Duration(milliseconds: 200),
                          padding: EdgeInsets.only(
                              bottom: playerBarState.state ? 80 : 0),
                          child: HomePageScreen(),
                        );
                      })),
            ],
          ),
        ],
      ),
    );
  }
}

class HomePageScreen extends StatefulWidget {
  final HomePage? homePage;
  final DeezerChannel? channel;
  const HomePageScreen({this.homePage, this.channel, super.key});

  @override
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  bool _shouldPlayAnimation = false;
  late List<Playlist> cards = [];
  double cardSize = 0.0;

  HomePage? _homePage;
  bool _cancel = false;
  bool _error = false;

  void _loadChannel() async {
    HomePage? hp;
    //Fetch channel from api
    try {
      hp = await deezerAPI.getChannel(widget.channel?.target ?? '');
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    if (hp == null) {
      //On error
      setState(() => _error = true);
      return;
    }
    setState(() => _homePage = hp);
  }

  void _loadHomePage() async {
    //Load local
    try {
      HomePage hp = await HomePage().load();
      setState(() => _homePage = hp);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    //On background load from API
    try {
      if (settings.offlineMode) await deezerAPI.authorize();
      HomePage hp = await deezerAPI.homePage();
      if (_cancel) return;
      if (hp.sections.isEmpty) return;
      setState(() => _homePage = hp);
      //Save to cache
      await _homePage?.save();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  void _load() {
    if (widget.channel != null) {
      _loadChannel();
      return;
    }
    if (widget.channel == null && widget.homePage == null) {
      _loadHomePage();
      return;
    }
    if (widget.homePage?.sections == null ||
        widget.homePage!.sections.isEmpty) {
      _loadHomePage();
      return;
    }
    //Already have data
    setState(() => _homePage = widget.homePage);
  }

  @override
  void initState() {
    super.initState();
    _load();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      setState(() {
        cardSize = MediaQuery.of(context).orientation == Orientation.portrait
            ? MediaQuery.of(context).size.width * 0.75
            : MediaQuery.of(context).size.height * 0.75;
      });
    });
  }

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    setState(() {
      cards = List.generate(_homePage?.mainSection?.items?.length ?? 0,
          (int i) => _homePage?.mainSection?.items?[i]?.value);
    });
    if (_homePage == null) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      ));
    }
    if (_error) return const ErrorScreen();
    return Column(children: [
      if (_homePage?.flowSection != null)
        HomepageRowSection(_homePage!.flowSection!),
      if (_homePage?.mainSection != null)
        ListTile(
          title: Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 32.0, 8.0, 16.0),
            child: Text(
              _homePage?.mainSection?.title ?? '',
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
            ),
          ),
          subtitle: SizedBox(
            height: cardSize * 1.1,
            width: cardSize * 1.1,
            child: CardCarouselWidget(
                onCardStackAnimationComplete: (value) {
                  setState(() {
                    _shouldPlayAnimation = value;
                  });
                },
                shouldStartCardStackAnimation: _shouldPlayAnimation,
                cardData: cards,
                animationDuration: const Duration(milliseconds: 600),
                downScrollDuration: const Duration(milliseconds: 200),
                secondCardOffsetEnd: cardSize * -0.1,
                secondCardOffsetStart: cardSize * 0.185,
                maxScrollDistance: cardSize,
                topCardOffsetStart: cardSize * -0.1,
                topCardYDrop: cardSize * 0.1,
                topCardScaleEnd: 0.6,
                onCardChange: (index) {},
                cardBuilder: (context, index, visibleIndex) {
                  if (index < 0 || index >= cards.length) {
                    return const SizedBox.shrink();
                  }
                  final card = cards[index];
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      final bool isIncoming =
                          child.key == ValueKey<int>(visibleIndex);

                      if (isIncoming) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      } else {
                        return child;
                      }
                    },
                    child: SizedBox(
                      height: cardSize,
                      width: cardSize,
                      child: Container(
                        key: ValueKey<int>(visibleIndex),
                        decoration: ShapeDecoration(
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 45,
                              cornerSmoothing: 1,
                            ),
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        alignment: Alignment.center,
                        child: InkWell(
                          customBorder: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 45,
                              cornerSmoothing: 1,
                            ),
                          ),
                          onTap: () => {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => PlaylistDetails(card)))
                          },
                          onLongPress: () {
                            MenuSheet m = MenuSheet();
                            m.defaultPlaylistMenu(card, context: context);
                          },
                          child: CachedImage(
                            url: card.image?.fullUrl ?? '',
                            height: cardSize,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
          ),
        ),
      ...List.generate(
        _homePage?.sections.length ?? 0,
        (i) {
          switch (_homePage!.sections[i].layout) {
            case HomePageSectionLayout.ROW:
              return HomepageRowSection(_homePage!.sections[i]);
            case HomePageSectionLayout.GRID:
              return HomePageGridSection(_homePage!.sections[i]);
            default:
              return HomepageRowSection(_homePage!.sections[i]);
          }
        },
      )
    ]);
  }
}

class HomepageRowSection extends StatelessWidget {
  final HomePageSection section;
  const HomepageRowSection(this.section, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 12.0, 8.0, 16.0),
            child: Text(
              section.title ?? '',
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate((section.items?.length ?? 0) + 1, (j) {
                //Has more items
                if (j == (section.items?.length ?? 0)) {
                  if (section.hasMore ?? false) {
                    return TextButton(
                      child: Text(
                        'Show more'.i18n,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20.0),
                      ),
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: FreezerAppBar(section.title ?? ''),
                          body: SingleChildScrollView(
                              child: HomePageScreen(
                                  channel:
                                      DeezerChannel(target: section.pagePath))),
                        ),
                      )),
                    );
                  }
                  return const SizedBox(height: 0, width: 0);
                }

                //Show item
                HomePageItem item = section.items![j] ?? HomePageItem();
                return HomePageItemWidget(item);
              }),
            ),
          ),
        )
      ],
    );
  }
}

class HomePageGridSection extends StatelessWidget {
  final HomePageSection section;
  const HomePageGridSection(this.section, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
        child: Text(
          section.title ?? '',
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w900),
        ),
      ),
      subtitle: Wrap(
        alignment: WrapAlignment.spaceAround,
        children: List.generate(section.items!.length, (i) {
          //Item
          return HomePageItemWidget(section.items![i] ?? HomePageItem());
        }),
      ),
    );
  }
}

class HomePageItemWidget extends StatelessWidget {
  final HomePageItem item;
  const HomePageItemWidget(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case HomePageItemType.FLOW:
        return FlowTrackListTile(
          item.value,
          onTap: () {
            DeezerFlow deezerFlow = item.value;
            GetIt.I<AudioPlayerHandler>().playFromSmartTrackList(SmartTrackList(
                id: 'flow', title: deezerFlow.title, flowType: deezerFlow.id));
          },
        );
      case HomePageItemType.SMARTTRACKLIST:
        return SmartTrackListTile(
          item.value,
          onTap: () {
            GetIt.I<AudioPlayerHandler>().playFromSmartTrackList(item.value);
          },
        );
      case HomePageItemType.ALBUM:
        return AlbumCard(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => AlbumDetails(item.value)));
          },
          onHold: () {
            MenuSheet m = MenuSheet();
            m.defaultAlbumMenu(item.value, context: context);
          },
        );
      case HomePageItemType.ARTIST:
        return ArtistTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ArtistDetails(item.value)));
          },
          onHold: () {
            MenuSheet m = MenuSheet();
            m.defaultArtistMenu(item.value, context: context);
          },
        );
      case HomePageItemType.PLAYLIST:
        return PlaylistCardTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => PlaylistDetails(item.value)));
          },
          onHold: () {
            MenuSheet m = MenuSheet();
            m.defaultPlaylistMenu(item.value, context: context);
          },
        );
      case HomePageItemType.CHANNEL:
        return ChannelTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => Scaffold(
                      appBar: FreezerAppBar(item.value.title.toString()),
                      body: SingleChildScrollView(
                          child: HomePageScreen(
                        channel: item.value,
                      )),
                    )));
          },
        );
      case HomePageItemType.SHOW:
        return ShowCard(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ShowScreen(item.value)));
          },
        );
      case HomePageItemType.GAME:
        return ChannelTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => GamePageScreen()));
          },
        );
      default:
        return const SizedBox(height: 0, width: 0);
    }
  }
}

class FreezerTitle extends StatelessWidget {
  const FreezerTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Image.asset(
            'assets/banner.png',
            width: MediaQuery.of(context).orientation == Orientation.portrait
                ? MediaQuery.of(context).size.width * 0.9
                : MediaQuery.of(context).size.height * 0.2,
          ),
        ],
      ),
    );
  }
}

class GamePageScreen extends StatefulWidget {
  final HomePage? homePage;
  const GamePageScreen({this.homePage, super.key});

  @override
  _GamePageScreenState createState() => _GamePageScreenState();
}

class _GamePageScreenState extends State<GamePageScreen> {
  List<Playlist> _games = [];
  List<Playlist> _page = [];

  Future<void> _userGames() async {
    List<Playlist> gamePage = await deezerAPI.getUserGames();
    setState(() {
      _page = gamePage;
    });
  }

  Future<void> _loadGames() async {
    List<Playlist> games = await deezerAPI.getMusicQuizzes();
    games.shuffle();
    setState(() {
      _games = games;
    });
  }

  @override
  void initState() {
    super.initState();
    _userGames();
    _loadGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Music Quizzes'.i18n),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text(
              'Quizzes for you :',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 24),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 250,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(
                  min(10, _page.length),
                  (int i) => LargePlaylistTile(
                    _page[i],
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                          builder: (context) =>
                              BlindTestChoiceScreen(_page[i])),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text(
              'Deezer quizzes :',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 24),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 250,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(
                  min(10, _games.length),
                  (int i) => LargePlaylistTile(
                    _games[i],
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                          builder: (context) =>
                              BlindTestChoiceScreen(_games[i])),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
