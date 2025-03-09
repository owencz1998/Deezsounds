import 'package:alchemy/api/cache.dart';
import 'package:alchemy/api/definitions.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/main.dart';
import 'package:alchemy/ui/cached_image.dart';
import 'package:alchemy/ui/downloads_screen.dart';
import 'package:alchemy/ui/elements.dart';
import 'package:alchemy/ui/library.dart';
import 'package:alchemy/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  Color? gradientColor =
      cache.userColor != null ? Color(cache.userColor ?? 0) : null;
  String? userEmail = cache.userEmail;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor:
            cache.userColor != null ? Color(cache.userColor ?? 0) : null));
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
              leading: Icon(AlchemyIcons.podcast),
              title: Text('Your podcasts'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => LibraryShows()));
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
