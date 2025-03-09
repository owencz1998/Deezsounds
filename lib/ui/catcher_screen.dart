import 'package:alchemy/api/definitions.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/ui/settings_screen.dart';
import 'package:awesome_ripple_animation/awesome_ripple_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CatcherScreen extends StatefulWidget {
  const CatcherScreen({super.key});

  @override
  _CatcherScreen createState() => _CatcherScreen();
}

class _CatcherScreen extends State<CatcherScreen> {
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
            child: RippleAnimation(
              size: MediaQuery.of(context).size,
              minRadius: 64,
              repeat: true,
              color: Theme.of(context).primaryColor,
              child: SizedBox(
                height: MediaQuery.of(context).size.width * 0.2,
                width: MediaQuery.of(context).size.width * 0.2,
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: ShapeDecoration(
                      shape: CircleBorder(),
                      color: Theme.of(context).scaffoldBackgroundColor),
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
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Text('Results provided by Audd.io API.'),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
