import 'dart:async';
import 'dart:io';

import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/service/audio_service.dart';
import 'package:alchemy/settings.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:alchemy/main.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../api/download.dart';
import '../translations.i18n.dart';
import 'elements.dart';
import 'cached_image.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  _DownloadsScreenState createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Download> downloads = [];
  StreamSubscription? _stateSubscription;

  //Sublists
  List<Download> get downloading => downloads
      .where((d) =>
          d.state == DownloadState.DOWNLOADING || d.state == DownloadState.POST)
      .toList();
  List<Download> get queued =>
      downloads.where((d) => d.state == DownloadState.NONE).toList();
  List<Download> get failed => downloads
      .where((d) =>
          d.state == DownloadState.ERROR ||
          d.state == DownloadState.DEEZER_ERROR)
      .toList();
  List<Download> get finished =>
      downloads.where((d) => d.state == DownloadState.DONE).toList();

  Future _load() async {
    //Load downloads
    List<Download> d = await downloadManager.getDownloads();
    setState(() {
      downloads = d;
    });
  }

  @override
  void initState() {
    _load();

    //Subscribe to state update
    _stateSubscription = downloadManager.serviceEvents.stream.listen((e) {
      //State change = update
      if (e['action'] == 'onStateChange') {
        setState(() => downloadManager.running = downloadManager.running);
      }
      //Progress change
      if (e['action'] == 'onProgress') {
        setState(() {
          for (Map su in e['data']) {
            downloads
                .firstWhere((d) => d.id == su['id'], orElse: () => Download())
                .updateFromJson(su);
          }
        });
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar(
          'Downloads'.i18n,
          actions: [
            IconButton(
              icon: Icon(
                Icons.delete_sweep,
                semanticLabel: 'Clear all'.i18n,
              ),
              onPressed: () async {
                await downloadManager.removeDownloads(DownloadState.ERROR);
                await downloadManager
                    .removeDownloads(DownloadState.DEEZER_ERROR);
                await downloadManager.removeDownloads(DownloadState.DONE);
                await downloadManager.removeDownloads(DownloadState.NONE);
                await _load();
              },
            ),
            IconButton(
              icon: Icon(
                downloadManager.running ? Icons.stop : Icons.play_arrow,
                semanticLabel:
                    downloadManager.running ? 'Stop'.i18n : 'Start'.i18n,
              ),
              onPressed: () {
                setState(() {
                  if (downloadManager.running) {
                    downloadManager.stop();
                  } else {
                    downloadManager.start();
                  }
                });
              },
            )
          ],
        ),
        body: ListView(
          children: [
            ...List.generate(
                downloading.length,
                (int i) => DownloadTile(
                      downloading[i],
                      updateCallback: () => _load(),
                    )),
            //Queued
            if (queued.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).size.width * 0.02,
                    horizontal: MediaQuery.of(context).size.width * 0.05),
                child: Column(
                  children: [
                    Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: ShapeDecoration(
                        color: settings.theme == Themes.Light
                            ? Colors.black.withAlpha(30)
                            : Colors.white.withAlpha(30),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                            cornerRadius: 25,
                            cornerSmoothing: 0.6,
                          ),
                        ),
                      ),
                      child: ExpansionTile(
                          shape: const Border(),
                          initiallyExpanded: true,
                          title: Text('Queue'),
                          trailing: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            child: Text(
                              queued.length.toString(),
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              spacing: MediaQuery.of(context).size.width * 0.05,
                              children: [
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.6,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(25),
                                    onTap: () async {
                                      await downloadManager
                                          .removeDownloads(DownloadState.NONE);
                                      await _load();
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                          MediaQuery.of(context).size.width *
                                              0.01),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 12.0, top: 4.0),
                                              child: Icon(AlchemyIcons.trash,
                                                  size: 20),
                                            ),
                                            Text(
                                              'Clear queue',
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.width * 0.02,
                            ),
                            ...List.generate(
                              queued.length,
                              (int i) => DownloadTile(
                                queued[i],
                                updateCallback: () => _load(),
                              ),
                            ),
                          ]),
                    ),
                  ],
                ),
              ),

            if (failed.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).size.width * 0.02,
                    horizontal: MediaQuery.of(context).size.width * 0.05),
                child: Column(
                  children: [
                    Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: ShapeDecoration(
                        color: settings.theme == Themes.Light
                            ? Colors.black.withAlpha(30)
                            : Colors.white.withAlpha(30),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                            cornerRadius: 25,
                            cornerSmoothing: 0.6,
                          ),
                        ),
                      ),
                      child: ExpansionTile(
                        shape: const Border(),
                        title: Text('Failed downloads'),
                        trailing: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          child: Text(
                            failed.length.toString(),
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            spacing: MediaQuery.of(context).size.width * 0.05,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 3,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(25),
                                  onTap: () async {
                                    await downloadManager.retryDownloads();
                                    await _load();
                                    downloadManager.start();
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                        MediaQuery.of(context).size.width *
                                            0.01),
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12.0, top: 4.0),
                                            child: Icon(
                                                AlchemyIcons.repeat_small,
                                                size: 20),
                                          ),
                                          Text(
                                            'Retry',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 3,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(25),
                                  onTap: () async {
                                    await downloadManager
                                        .removeDownloads(DownloadState.ERROR);
                                    await downloadManager.removeDownloads(
                                        DownloadState.DEEZER_ERROR);
                                    await _load();
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                        MediaQuery.of(context).size.width *
                                            0.01),
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12.0, top: 4.0),
                                            child: Icon(AlchemyIcons.trash,
                                                size: 20),
                                          ),
                                          Text(
                                            'Clear',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.width * 0.02,
                          ),
                          ...List.generate(
                              failed.length,
                              (int i) => DownloadTile(
                                    failed[i],
                                    updateCallback: () => _load(),
                                  ))
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (finished.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).size.width * 0.02,
                    horizontal: MediaQuery.of(context).size.width * 0.05),
                child: Column(
                  children: [
                    Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: ShapeDecoration(
                        color: settings.theme == Themes.Light
                            ? Colors.black.withAlpha(30)
                            : Colors.white.withAlpha(30),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                            cornerRadius: 25,
                            cornerSmoothing: 0.6,
                          ),
                        ),
                      ),
                      child: ExpansionTile(
                          shape: const Border(),
                          title: Text('Downloaded tracks'),
                          trailing: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            child: Text(
                              finished.length.toString(),
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              spacing: MediaQuery.of(context).size.width * 0.05,
                              children: [
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.6,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(25),
                                    onTap: () async {
                                      await downloadManager.retryDownloads();
                                      await _load();
                                      downloadManager.start();
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                          MediaQuery.of(context).size.width *
                                              0.01),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 12.0, top: 4.0),
                                              child: Icon(AlchemyIcons.trash,
                                                  size: 20),
                                            ),
                                            Text(
                                              'Clear history',
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.width * 0.02,
                            ),
                            ...List.generate(
                              finished.length,
                              (int i) => DownloadTile(
                                finished[i],
                                updateCallback: () => _load(),
                              ),
                            ),
                          ]),
                    ),
                  ],
                ),
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
        ));
  }
}

class DownloadTile extends StatelessWidget {
  final Download download;
  final Function updateCallback;
  const DownloadTile(this.download, {super.key, required this.updateCallback});

  String subtitle() {
    String out = '';

    if (download.state != DownloadState.DOWNLOADING &&
        download.state != DownloadState.POST) {
      //Download type
      if (download.private ?? false) {
        out += 'Offline'.i18n;
      } else {
        out += 'External'.i18n;
      }
      out += ' | ';
    }

    if (download.state == DownloadState.POST) {
      return 'Post processing...'.i18n;
    }

    //Quality
    if (download.quality == 9) out += 'FLAC';
    if (download.quality == 3) out += 'MP3 320kbps';
    if (download.quality == 1) out += 'MP3 128kbps';

    //Downloading show progress
    if (download.state == DownloadState.DOWNLOADING) {
      out +=
          ' | ${filesize(download.received, 2)} / ${filesize(download.filesize, 2)}';
      double progress =
          download.received!.toDouble() / download.filesize!.toDouble();
      out += ' ${(progress * 100.0).toStringAsFixed(2)}%';
    }

    return out;
  }

  Future onClick(BuildContext context) async {
    if (download.state != DownloadState.DOWNLOADING &&
        download.state != DownloadState.POST) {
      if (!(download.isEpisode ?? false)) {
        GetIt.I<AudioPlayerHandler>().playFromMediaId(download.trackId ?? '');
      }
    }
  }

  Future onHold(BuildContext context) async {
    if (download.state != DownloadState.DOWNLOADING &&
        download.state != DownloadState.POST) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Delete'.i18n),
              content:
                  Text('Are you sure you want to delete this download?'.i18n),
              actions: [
                TextButton(
                  child: Text('Cancel'.i18n),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Delete'.i18n),
                  onPressed: () async {
                    await downloadManager.removeDownload(download.id!);
                    updateCallback();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                )
              ],
            );
          });
    }
  }

  //Trailing icon with state
  Widget trailing() {
    switch (download.state) {
      case DownloadState.NONE:
        return const Icon(
          Icons.query_builder,
        );
      case DownloadState.DOWNLOADING:
        return const Icon(Icons.download_rounded);
      case DownloadState.POST:
        return const Icon(Icons.miscellaneous_services);
      case DownloadState.DONE:
        return const Icon(
          Icons.done,
          color: Colors.green,
        );
      case DownloadState.DEEZER_ERROR:
        return const Icon(Icons.error, color: Colors.blue);
      case DownloadState.ERROR:
        return const Icon(Icons.error, color: Colors.red);
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          title: Text(
            download.title!,
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
          subtitle:
              Text(subtitle(), maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.hardEdge,
            decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: 10,
                  cornerSmoothing: 1,
                ),
              ),
            ),
            child: CachedImage(
              url: download.image!,
              width: 48,
            ),
          ),
          onTap: () => onClick(context),
          onLongPress: () => onHold(context),
          trailing: trailing(),
        ),
        if (download.state == DownloadState.DOWNLOADING)
          LinearProgressIndicator(
            value: download.progress,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),
        if (download.state == DownloadState.POST)
          const LinearProgressIndicator(),
      ],
    );
  }
}

class DownloadLogViewer extends StatefulWidget {
  const DownloadLogViewer({super.key});

  @override
  _DownloadLogViewerState createState() => _DownloadLogViewerState();
}

class _DownloadLogViewerState extends State<DownloadLogViewer> {
  List<String> data = [];

  //Load log from file
  Future _load() async {
    String path =
        p.join((await getExternalStorageDirectory())!.path, 'download.log');
    File file = File(path);
    if (await file.exists()) {
      String d = await file.readAsString();
      setState(() {
        data = d.replaceAll('\r', '').split('\n');
      });
    }
  }

  //Get color by log type
  Color? color(String line) {
    if (line.startsWith('E:')) return Colors.red;
    if (line.startsWith('W:')) return Colors.orange[600];
    return null;
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar('Download Log'.i18n),
        body: ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, i) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                data[i],
                style: TextStyle(fontSize: 14.0, color: color(data[i])),
              ),
            );
          },
        ));
  }
}
