import 'package:cached_network_image/cached_network_image.dart';
import 'package:deezer/api/cache.dart';
import 'package:deezer/api/deezer.dart';
import 'package:deezer/api/definitions.dart';
import 'package:deezer/fonts/alchemy_icons.dart';
import 'package:deezer/main.dart';
import 'package:deezer/ui/cached_image.dart';
import 'package:deezer/ui/downloads_screen.dart';
import 'package:deezer/ui/elements.dart';
import 'package:deezer/ui/library.dart';
import 'package:deezer/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  Color? gradientColor;
  String? userEmail;

  void _setColor() async {
    PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(
            ImageDetails.fromJson(cache.userPicture).fullUrl ?? ''));
    setState(() {
      gradientColor = palette.dominantColor?.color;
      SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(statusBarColor: gradientColor));
    });
  }

  void _getUser() async {
    Map<dynamic, dynamic> userData =
        await deezerAPI.callGwApi('deezer.getUserData');
    setState(() {
      userEmail = userData['results']['USER']['EMAIL'];
    });
  }

  @override
  void initState() {
    super.initState();
    _setColor();
    _getUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                gradientColor ?? Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).scaffoldBackgroundColor
              ], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            blurRadius: 10,
                            color: Theme.of(context).scaffoldBackgroundColor,
                            spreadRadius: 5,
                            offset: Offset(0, 8))
                      ],
                    ),
                    child: CircleAvatar(
                      radius: MediaQuery.of(context).size.height / 8,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                gradientColor ?? Theme.of(context).primaryColor,
                            width: 3.0,
                          ),
                        ),
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: CachedImage(
                              url: ImageDetails.fromJson(cache.userPicture)
                                      .fullUrl ??
                                  ''),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).size.height * 0.01),
                    child: Text(
                      cache.userName,
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      userEmail ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.w300,
                          color: Theme.of(context).secondaryHeaderColor),
                    ),
                  )
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.width * 0.05,
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              enabled: false,
              leading: Icon(AlchemyIcons.pen),
              title: Text('Edit profile'),
              trailing: Icon(AlchemyIcons.chevron_end),
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              leading: Icon(AlchemyIcons.settings),
              title: Text('Access settings'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => SettingsScreen()));
                SystemChrome.setSystemUIOverlayStyle(
                    SystemUiOverlayStyle(statusBarColor: Colors.transparent));
              },
            ),
            FreezerDivider(),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              leading: Icon(AlchemyIcons.double_note),
              title: Text('Your tracks'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => LibraryTracks()));
                SystemChrome.setSystemUIOverlayStyle(
                    SystemUiOverlayStyle(statusBarColor: Colors.transparent));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              leading: Icon(AlchemyIcons.arrow_time),
              title: Text('Your history'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => HistoryScreen()));
                SystemChrome.setSystemUIOverlayStyle(
                    SystemUiOverlayStyle(statusBarColor: Colors.transparent));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              leading: Icon(AlchemyIcons.download),
              title: Text('Your downloads'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => DownloadsScreen()));
                SystemChrome.setSystemUIOverlayStyle(
                    SystemUiOverlayStyle(statusBarColor: Colors.transparent));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              leading: Icon(AlchemyIcons.book),
              title: Text('Your playlists'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => LibraryPlaylists()));
                SystemChrome.setSystemUIOverlayStyle(
                    SystemUiOverlayStyle(statusBarColor: Colors.transparent));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              leading: Icon(AlchemyIcons.album),
              title: Text('Your albums'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => LibraryAlbums()));
                SystemChrome.setSystemUIOverlayStyle(
                    SystemUiOverlayStyle(statusBarColor: Colors.transparent));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              leading: Icon(AlchemyIcons.human_circle),
              title: Text('Your artists'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => LibraryArtists()));
                SystemChrome.setSystemUIOverlayStyle(
                    SystemUiOverlayStyle(statusBarColor: Colors.transparent));
              },
            ),
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
      ),
    );
  }
}
