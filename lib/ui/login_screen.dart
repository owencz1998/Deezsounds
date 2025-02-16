import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:logging/logging.dart';
import 'package:lottie/lottie.dart';

import '../api/deezer.dart';
import '../api/deezer_login.dart';
import '../api/definitions.dart';
import '../utils/navigator_keys.dart';
import '../settings.dart';
import '../translations.i18n.dart';

class LoginWidget extends StatefulWidget {
  final Function? callback;
  const LoginWidget({required this.callback, super.key});

  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  String? _arl;
  String? _error;

  //Initialize deezer etc
  Future _init() async {
    deezerAPI.arl = settings.arl;
    //await GetIt.I<AudioPlayerHandler>().start();

    //Pre-cache homepage
    if (!await HomePage().exists()) {
      await deezerAPI.authorize();
      settings.offlineMode = false;
      HomePage hp = await deezerAPI.homePage();
      if (hp.sections.isNotEmpty) await hp.save();
    }
  }

  //Call _init()
  void _start() async {
    if (settings.arl != null) {
      _init().then((_) {
        if (widget.callback != null) widget.callback!();
      });
    }
  }

  //Check if deezer available in current country
  void _checkAvailability() async {
    bool? available = await DeezerAPI.checkAvailability();
    if (!(available ?? false)) {
      showDialog(
          context: mainNavigatorKey.currentContext!,
          builder: (context) => AlertDialog(
                title: Text('Deezer is unavailable'.i18n),
                content: Text(
                    'Deezer is unavailable in your country, ReFreezer might not work properly. Please use a VPN'
                        .i18n),
                actions: [
                  TextButton(
                    child: Text('Continue'.i18n),
                    onPressed: () {
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  )
                ],
              ));
    }
  }

  /* No idea why this is needed, seems to trigger superfluous _start() execution...
  @override
  void didUpdateWidget(LoginWidget oldWidget) {
    _start();
    super.didUpdateWidget(oldWidget);
  }*/

  @override
  void initState() {
    _start();
    _checkAvailability();
    super.initState();
  }

  void errorDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Error'.i18n),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Error logging in! Please check your token and internet connection and try again.'
                        .i18n),
                if (_error != null) Text('\n\n$_error')
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Dismiss'.i18n),
                onPressed: () {
                  _error = null;
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  void _update() async {
    setState(() => {});

    //Try logging in
    try {
      deezerAPI.arl = settings.arl;
      bool resp = await deezerAPI.rawAuthorize(
          onError: (e) => setState(() => _error = e.toString()));
      if (resp == false) {
        //false, not null
        int arlLength = (settings.arl ?? '').length;
        if (arlLength != 175 && arlLength != 192) {
          _error = '${(_error ?? '')}Invalid ARL length!';
        }
        setState(() => settings.arl = null);
        errorDialog();
      }
      //On error show dialog and reset to null
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Login error: $e');
      }
      setState(() => settings.arl = null);
      errorDialog();
    }

    await settings.save();
    _start();
  }

  // ARL auth: called on "Save" click, Enter and DPAD_Center press
  void goARL(FocusNode? node, TextEditingController controller) {
    node?.unfocus();
    controller.clear();
    settings.arl = _arl?.trim();
    Navigator.of(context).pop();
    _update();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    //If arl is null, show loading
    if (settings.arl != null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    TextEditingController controller = TextEditingController();
    // For "DPAD center" key handling on remote controls
    FocusNode focusNode = FocusNode(
        skipTraversal: true,
        descendantsAreFocusable: false,
        onKeyEvent: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.select) {
            goARL(node, controller);
          }
          return KeyEventResult.handled;
        });
    if (settings.arl == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(color: settings.primaryColor),
              height: MediaQuery.of(context).size.height / 3,
              width: MediaQuery.of(context).size.width,
              alignment: Alignment.bottomCenter,
              child: LiquidLinearProgressIndicator(
                value: 0.1,
                valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).scaffoldBackgroundColor),
                backgroundColor: Colors.lightBlue,
                direction: Axis.vertical,
                waveHeight: MediaQuery.of(context).size.height / 8,
                waveLength: 4.6,
                speed: 1,
              ),
            ),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                child: Text(
                  'WELCOME TO ALCHEMY'.i18n,
                  style: TextStyle(
                      fontFamily: 'MontSerrat',
                      fontWeight: FontWeight.w900,
                      fontSize: 50),
                  textAlign: TextAlign.start,
                )),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Text(
                'Sign up for free or log in'.i18n,
                textAlign: TextAlign.start,
                style: const TextStyle(
                    fontSize: 16.0, color: Settings.secondaryText),
              ),
            ),
            //Email login dialog
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: settings.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) => EmailLogin(_update));
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'Continue with email'.i18n,
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 18.0),
                      ),
                    ))),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                'Or'.i18n,
                style: TextStyle(color: Settings.secondaryText),
                textAlign: TextAlign.center,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                    padding: EdgeInsets.all(2),
                    margin:
                        EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Settings.secondaryText.withAlpha(230),
                          width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: Image.asset('assets/chrome.png'),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => LoginBrowser(_update)));
                      },
                    )),
                Container(
                    padding: EdgeInsets.all(2),
                    margin:
                        EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Settings.secondaryText.withAlpha(230),
                          width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: IconButton(
                        icon: Image.asset('assets/token.png'),
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                Future.delayed(
                                    const Duration(seconds: 1),
                                    () => {
                                          focusNode.requestFocus()
                                        }); // autofocus doesn't work - it's replacement
                                return AlertDialog(
                                  title: Text('Enter ARL'.i18n),
                                  content: TextField(
                                    onChanged: (String s) => _arl = s,
                                    decoration: InputDecoration(
                                        labelText: 'Token (ARL)'.i18n),
                                    focusNode: focusNode,
                                    controller: controller,
                                    onSubmitted: (String s) {
                                      goARL(focusNode, controller);
                                    },
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text('Save'.i18n),
                                      onPressed: () => goARL(null, controller),
                                    )
                                  ],
                                );
                              });
                        }))
              ],
            ),
            Expanded(
                child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
                child: Text(
                  "By using this app, you don't abide by Deezer's ToS.".i18n,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16.0),
                ),
              ),
            ))
          ],
        ),
      );
    }
    return Container();
  }
}

class LoginBrowser extends StatelessWidget {
  final Function updateParent;
  const LoginBrowser(this.updateParent, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: InAppWebView(
            initialUrlRequest:
                URLRequest(url: WebUri('https://deezer.com/login')),
            onLoadStart:
                (InAppWebViewController controller, WebUri? loadedUri) async {
              //Offers URL
              if (!loadedUri!.path.contains('/login') &&
                  !loadedUri.path.contains('/register')) {
                controller.evaluateJavascript(
                    source: 'window.location.href = "/open_app"');
              }

              //Parse arl from url
              if (loadedUri
                  .toString()
                  .startsWith('intent://deezer.page.link')) {
                try {
                  //Actual url is in `link` query parameter
                  Uri linkUri = Uri.parse(loadedUri.queryParameters['link']!);
                  String? arl = linkUri.queryParameters['arl'];
                  settings.arl = arl;
                  // Clear cookies for next login after logout
                  CookieManager.instance().deleteAllCookies();
                  Navigator.of(context).pop();
                  updateParent();
                } catch (e) {
                  Logger.root
                      .severe('Error loading ARL from browser login: $e');
                }
              }
            },
          ),
        ),
      ],
    );
  }
}

class EmailLogin extends StatefulWidget {
  final Function callback;
  const EmailLogin(this.callback, {super.key});

  @override
  _EmailLoginState createState() => _EmailLoginState();
}

class _EmailLoginState extends State<EmailLogin> {
  String? _email;
  String? _password;
  bool _loading = false;

  Future _login() async {
    setState(() => _loading = true);
    //Try logging in
    String? arl;
    String? exception;
    try {
      arl = await DeezerLogin.getArlByEmailAndPassword(_email!, _password!);
    } on DeezerLoginException catch (dle) {
      exception = dle.toString();
    } catch (e, st) {
      exception = e.toString();
      if (kDebugMode) {
        print(e);
        print(st);
      }
    }
    setState(() => _loading = false);
    settings.arl = arl;
    if (mounted) Navigator.of(context).pop();

    if (exception == null) {
      //Success
      widget.callback();
      return;
    } else if (mounted) {
      //Error
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Error logging in!'.i18n),
                content: Text(
                    'Error logging in using email, please check your credentials.\n\nError: ${exception!}'),
                actions: [
                  TextButton(
                    child: Text('Dismiss'.i18n),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  )
                ],
              ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 52.0, bottom: 24.0),
            child: Text(
              'Email',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'MontSerrat',
                  fontSize: 56.0,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: TextField(
              cursorColor: Theme.of(context).primaryColor,
              decoration: InputDecoration(
                labelText: 'Email'.i18n,
                floatingLabelStyle:
                    TextStyle(color: Theme.of(context).primaryColor),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 2.0),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: _email == null
                          ? Settings.secondaryText
                          : Theme.of(context).primaryColor,
                      width: 2.0),
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: (s) => _email = s,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: TextField(
              obscureText: true,
              cursorColor: Theme.of(context).primaryColor,
              decoration: InputDecoration(
                labelText: 'Password'.i18n,
                floatingLabelStyle:
                    TextStyle(color: Theme.of(context).primaryColor),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 2.0),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: _password == null
                          ? Settings.secondaryText
                          : Theme.of(context).primaryColor,
                      width: 2.0),
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: (s) => _password = s,
            ),
          ),
          Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: settings.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    if (_email != null && _password != null) {
                      await _login();
                    } else {
                      Fluttertoast.showToast(
                          msg: 'Missing email or password!'.i18n,
                          gravity: ToastGravity.BOTTOM,
                          toastLength: Toast.LENGTH_SHORT);
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: _loading
                        ? Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              height: 12.0,
                              width: 12.0,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : Text(
                            'Continue'.i18n,
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 18.0),
                          ),
                  ))),
        ],
      ),
    );
  }
}
