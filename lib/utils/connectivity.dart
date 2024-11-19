import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> isConnected() async {
  List<ConnectivityResult> connectivity =
      await Connectivity().checkConnectivity();

  if (connectivity.isNotEmpty &&
      !connectivity.contains(ConnectivityResult.none)) {
    return true;
  } else {
    return false;
  }
}
