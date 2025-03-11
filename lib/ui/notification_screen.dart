import 'package:alchemy/api/deezer.dart';
import 'package:alchemy/api/definitions.dart';
import 'package:alchemy/main.dart';
import 'package:alchemy/ui/elements.dart';
import 'package:alchemy/ui/tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationScreen extends StatefulWidget {
  final List<DeezerNotification> notifications;
  const NotificationScreen(this.notifications, {super.key});

  @override
  _NotificationScreen createState() => _NotificationScreen();
}

class _NotificationScreen extends State<NotificationScreen> {
  List<DeezerNotification> notifications = [];
  bool _isLoading = false;

  void _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    List<DeezerNotification> noti = await deezerAPI.getNotifications();

    if (mounted) {
      setState(() {
        notifications = noti;
        _isLoading = false;
      });
    }
  }

  //void _readAll() async {}

  @override
  void initState() {
    if (widget.notifications.isNotEmpty && mounted) {
      setState(() {
        notifications = widget.notifications;
      });
    } else {
      _load();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    return Scaffold(
        appBar: FreezerAppBar('Notifications'),
        body: _isLoading
            ? SplashScreen()
            : ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, int i) =>
                    NotificationTile(notifications[i])));
  }
}
