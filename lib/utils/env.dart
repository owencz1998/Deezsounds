// lib/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: 'lib/.env')
abstract class Env {
  // Deezer
  @EnviedField(varName: 'deezerClientId', obfuscate: true)
  static final String deezerClientId = _Env.deezerClientId;
  @EnviedField(varName: 'deezerClientSecret', obfuscate: true)
  static final String deezerClientSecret = _Env.deezerClientSecret;
  @EnviedField(varName: 'deezerGatewayAPI', obfuscate: true)
  static final String deezerGatewayAPI = _Env.deezerGatewayAPI;
  @EnviedField(varName: 'deezerMobileKey', obfuscate: true)
  static final String deezerMobileKey = _Env.deezerMobileKey;

  // LastFM
  @EnviedField(varName: 'lastFmApiKey', obfuscate: true)
  static final String lastFmApiKey = _Env.lastFmApiKey;
  @EnviedField(varName: 'lastFmApiSecret', obfuscate: true)
  static final String lastFmApiSecret = _Env.lastFmApiSecret;

  // ACR Cloud
  @EnviedField(varName: 'acrcloudHost', obfuscate: true)
  static final String acrcloudHost = _Env.acrcloudHost;
  @EnviedField(varName: 'acrcloudSongApiKey', obfuscate: true)
  static final String acrcloudSongApiKey = _Env.acrcloudSongApiKey;
  @EnviedField(varName: 'acrcloudSongApiSecret', obfuscate: true)
  static final String acrcloudSongApiSecret = _Env.acrcloudSongApiSecret;
  @EnviedField(varName: 'acrcloudHumsApiKey', obfuscate: true)
  static final String acrcloudHumsApiKey = _Env.acrcloudHumsApiKey;
  @EnviedField(varName: 'acrcloudHumsApiSecret', obfuscate: true)
  static final String acrcloudHumsApiSecret = _Env.acrcloudHumsApiSecret;
}
