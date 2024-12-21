import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:deezer/settings.dart';

Future<bool> isConnected() async {
  List<ConnectivityResult> connectivity =
      await Connectivity().checkConnectivity();

  if (connectivity.isNotEmpty &&
      !connectivity.contains(ConnectivityResult.none) &&
      !settings.offlineMode) {
    return true;
  } else {
    return false;
  }
}
