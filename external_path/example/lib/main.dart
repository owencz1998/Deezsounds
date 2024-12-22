import 'package:flutter/material.dart';
import 'dart:async';
import 'package:external_path/external_path.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<String> _exPaths = [];
  List<String> _exUSBPaths = [];

  @override
  void initState() {
    super.initState();

    getPaths();

    getPublicDirectoryPath();

    getSDCardDirectoryPath();
  }

  // Get storage directory paths
  // Like internal and external (SD card) storage path
  Future<void> getPaths() async {
    List<String> paths;
    // getExternalStorageDirectories() will return list containing internal storage directory path
    // And external storage (SD card) directory path (if exists)
    paths = await ExternalPath.getExternalStorageDirectories();

    setState(() {
      _exPaths = paths; // [/storage/emulated/0, /storage/B3AE-4D28]
    });
  }

  // To get public storage directory path like Downloads, Picture, Movie etc.
  // Use below code
  Future<void> getPublicDirectoryPath() async {
    String path;

    path = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOADS);

    setState(() {
      print("DIRECTORY_DOWNLOADS: " + path); // /storage/emulated/0/Download
    });
  }

  // To get external SDCard storage directory (if present).
  // Use below code
  Future<void> getSDCardDirectoryPath() async {
    String? SdCardPath;

    SdCardPath = await ExternalPath.getSDCardStorageDirectory();

    setState(() {
      print("SDCard path: " + SdCardPath.toString());
    });
  }

  // To get external USB storage directory (if present).
  // Use below code
  Future<void> getUSBPaths() async {
    List<String> UsbPaths;
    ;

    UsbPaths = await ExternalPath.getUSBStorageDirectories();

    setState(() {
      print("USB paths: " + UsbPaths.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: const Text('external_path example app'),
      ),
      body: ListView.builder(
          itemCount: _exPaths.length,
          itemBuilder: (context, index) {
            return Center(child: Text('External Path: ${_exPaths[index]}'));
          }),
    ));
  }
}
