import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:deezer/fonts/alchemy_icons.dart';
import 'package:deezer/main.dart';
import 'package:deezer/settings.dart';

import '../api/cache.dart';
import '../api/download.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';
import '../ui/error.dart';
import '../utils/version.dart';

class UpdaterScreen extends StatefulWidget {
  const UpdaterScreen({super.key});

  @override
  _UpdaterScreenState createState() => _UpdaterScreenState();
}

class _UpdaterScreenState extends State<UpdaterScreen> {
  bool _loading = true;
  bool _error = false;
  DeezerLatest? _latestRelease;
  Version _currentVersion = Version.parse('0.0.0');
  String? _arch;
  double _progress = 0.0;
  bool _buttonEnabled = true;

  Future<bool> _hasInstallPackagesPermission() async {
    if (await Permission.requestInstallPackages.isDenied) {
      final status = await Permission.requestInstallPackages.request();
      if (status.isGranted) {
        return true;
      } else {
        return false;
      }
    }
    return true;
  }

  Future _load() async {
    // Load current version
    PackageInfo info = await PackageInfo.fromPlatform();
    String versionString = info.version;

    // Parse the version string
    setState(() {
      _currentVersion =
          Version.tryParse(versionString) ?? Version.parse('0.0.0');
    });

    //Get architecture
    _arch = await DownloadManager.platform.invokeMethod('arch');

    //Load from website
    try {
      DeezerLatest latestRelease = await DeezerLatest.fetch();
      setState(() {
        _latestRelease = latestRelease;
        _loading = false;
      });
    } catch (e, st) {
      Logger.root.severe('Failed to load latest release', e, st);
      _error = true;
      _loading = false;
    }
  }

  DeezerDownload? get _versionDownload {
    return _latestRelease?.downloads.firstWhereOrNull(
      (d) => d.architectures
          .any((arch) => arch.toLowerCase() == _arch?.toLowerCase()),
    );
  }

  Future _download() async {
    if (!await _hasInstallPackagesPermission()) {
      Fluttertoast.showToast(
          msg: 'Permission denied, download canceled!'.i18n,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM);
      setState(() {
        _progress = 0.0;
        _buttonEnabled = true;
      });
      return;
    }

    try {
      String? url = _versionDownload?.directUrl;
      if (url == null) {
        throw Exception('No compatible download available');
      }
      //Start request
      http.Client client = http.Client();
      http.StreamedResponse res =
          await client.send(http.Request('GET', Uri.parse(url)));
      int? size = res.contentLength;
      //Open file
      String path =
          p.join((await getExternalStorageDirectory())!.path, 'update.apk');
      File file = File(path);
      IOSink fileSink = file.openWrite();
      //Update progress
      Future.doWhile(() async {
        int received = await file.length();
        setState(() => _progress = received / size!.toInt());
        return received != size;
      });
      //Pipe
      await res.stream.pipe(fileSink);
      fileSink.close();

      setState(() {
        _buttonEnabled = true;
        _progress = 0.0;
      });
    } catch (e) {
      Logger.root.severe('Failed to download latest release file', e);
      Fluttertoast.showToast(
          msg: 'Download failed!'.i18n,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM);
      setState(() {
        _progress = 0.0;
        _buttonEnabled = true;
      });
    }
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ScrollController scrollController = ScrollController();
    return Scaffold(
      appBar: FreezerAppBar('Updates'.i18n),
      body: ListView(
        controller: scrollController,
        children: [
          if (_error) const ErrorScreen(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [CircularProgressIndicator()],
              ),
            ),
          if (!_error &&
              !_loading &&
              (_latestRelease?.version ?? Version(0, 0, 0)) <= _currentVersion)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('You are running the latest version!'.i18n,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26.0, fontWeight: FontWeight.bold)),
            ),
          if (!_error &&
              !_loading &&
              (_latestRelease?.version ?? Version(0, 0, 0)) <= _currentVersion)
            ExpansionTile(
              textColor: Theme.of(context).textTheme.bodyMedium?.color,
              iconColor: Theme.of(context).textTheme.bodyMedium?.color,
              collapsedTextColor: Settings.secondaryText,
              collapsedIconColor: Settings.secondaryText,
              leading: Icon(AlchemyIcons.release_notes),
              title: Text('See changelog'),
              children: [
                Markdown(
                  controller: scrollController,
                  data: _latestRelease?.changelog ?? '',
                  shrinkWrap: true,
                ),
              ],
            ),
          if (!_error &&
              !_loading &&
              (_latestRelease?.version ?? Version(0, 0, 0)) > _currentVersion)
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'New update available!'.i18n +
                        ' ' +
                        _latestRelease!.version.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Current version: ' + _currentVersion.toString(),
                  style: const TextStyle(
                      fontSize: 14.0, fontStyle: FontStyle.italic),
                ),
                Container(height: 8.0),
                const FreezerDivider(),
                Container(height: 8.0),
                const Text(
                  'Changelog',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
                Container(height: 8.0),
                const FreezerDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Markdown(
                        controller: scrollController,
                        data: _latestRelease?.changelog ?? '',
                        shrinkWrap: true,
                      )
                    ],
                  ),
                ),
                const FreezerDivider(),
                Container(height: 8.0),
                //Available download
                if (_versionDownload != null)
                  Column(children: [
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                        onPressed: _buttonEnabled
                            ? () {
                                setState(() => _buttonEnabled = false);
                                _download();
                              }
                            : null,
                        child: Text(
                            'Download'.i18n + ' (${_versionDownload?.abi})')),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: LinearProgressIndicator(
                        value: _progress,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  ]),
                //Unsupported arch
                if (_versionDownload == null)
                  Text(
                    'Unsupported platform!'.i18n + ' $_arch',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16.0),
                  )
              ],
            ),
          ListenableBuilder(
              listenable: playerBarState,
              builder: (BuildContext context, Widget? child) {
                return AnimatedPadding(
                  duration: Duration(milliseconds: 200),
                  padding:
                      EdgeInsets.only(bottom: playerBarState.state ? 80 : 0),
                );
              })
        ],
      ),
    );
  }
}

class DeezerLatest {
  final String versionString;
  final Version version;
  final String changelog;
  final List<DeezerDownload> downloads;

  static const Map<String, List<String>> abiMap = {
    'arm64-v8a': ['arm64', 'aarch64'],
    'armeabi-v7a': ['arm32', 'armhf', 'armv8l'],
    'x86_64': ['x86_64'],
  };

  DeezerLatest({
    required this.versionString,
    required this.changelog,
    required this.downloads,
  }) : version = Version.tryParse(versionString) ?? Version.parse('0.0.0');

  static Future<DeezerLatest> fetch() async {
    http.Response res = await http.get(
      Uri.parse(
          'https://api.github.com/repos/PetitPrinc3/DefinitelyNotDeezer/releases/latest'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );

    if (res.statusCode != 200) {
      throw Exception(
          'Failed to load latest version from Github API: $res.statusCode $res.statusMessage');
    }

    Map<String, dynamic> data = jsonDecode(res.body);

    List<DeezerDownload> downloads = (data['assets'] as List)
        .map((asset) {
          String abi = abiMap.keys.firstWhere(
            (key) => asset['name'].contains(key),
            orElse: () => 'unknown',
          );
          return DeezerDownload(
            abi: abi,
            directUrl: asset['browser_download_url'],
          );
        })
        .where((download) => download.abi != 'unknown')
        .toList();

    return DeezerLatest(
      versionString: data['tag_name'],
      changelog: data['body'],
      downloads: downloads,
    );
  }

  static Future<void> checkUpdate() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check every 24 hours
    if (now - (cache.lastUpdateCheck ?? 0) <=
        const Duration(hours: 24).inMilliseconds) {
      return;
    }
    cache.lastUpdateCheck = now;
    await cache.save();

    try {
      final latestVersion = await fetch();

      //Load current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion =
          Version.tryParse(packageInfo.version) ?? Version.parse('0.0.0');

      if (latestVersion.version <= currentVersion) return;

      //Get architecture
      String arch = await DownloadManager.platform.invokeMethod('arch');
      Logger.root
          .info('Checking for updates to version $currentVersion on $arch');

      if (!latestVersion.downloads.any((download) => download.architectures.any(
          (architecture) =>
              architecture.toLowerCase() == arch.toLowerCase()))) {
        Logger.root.warning('No assets found for architecture $arch');
        return;
      }

      //Show notification
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('drawable/ic_logo');
      const InitializationSettings initializationSettings =
          InitializationSettings(
              android: androidInitializationSettings, iOS: null);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'definitelynotdeezerupdates',
        'Definitely Not Deezer Updates'.i18n,
        channelDescription: 'Definitely Not Deezer Updates'.i18n,
        importance: Importance.high,
        priority: Priority.high,
      );

      NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails, iOS: null);

      await flutterLocalNotificationsPlugin.show(
          0,
          'New update available!'.i18n,
          'Update to latest version in the settings.'.i18n,
          notificationDetails);
    } catch (e) {
      Logger.root.severe('Error checking for updates', e);
    }
  }
}

class DeezerDownload {
  final String abi;
  final String directUrl;
  final List<String> architectures;

  DeezerDownload({required this.abi, required this.directUrl})
      : architectures = DeezerLatest.abiMap[abi] ?? [abi];
}
