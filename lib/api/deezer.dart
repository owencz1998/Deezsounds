import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:deezer/api/cache.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:deezer/api/download.dart';
import 'package:palette_generator/palette_generator.dart';

import '../api/definitions.dart';
import '../api/spotify.dart';
import '../settings.dart';

DeezerAPI deezerAPI = DeezerAPI();

class DeezerAPI {
  DeezerAPI({this.arl});

  static const String userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36';

  String? arl;
  String? token;
  String? licenseToken;
  String? userId;
  String? favoritesPlaylistId;
  String? sid;

  Future? _authorizing;

  //Get headers
  Map<String, String> get headers => {
        'User-Agent': DeezerAPI.userAgent,
        'Content-Language':
            '${settings.deezerLanguage}-${settings.deezerCountry}',
        'Content-Type': 'text/plain;charset=UTF-8',
        //'origin': 'https://www.deezer.com',
        //'Cache-Control': 'max-age=0',
        'Accept': '*/*',
        'Accept-Charset': 'utf-8,ISO-8859-1;q=0.7,*;q=0.3',
        'Accept-Language':
            '${settings.deezerLanguage}-${settings.deezerCountry},${settings.deezerLanguage};q=0.9,en-US;q=0.8,en;q=0.7',
        'Connection': 'keep-alive',
        //'sec-fetch-site': 'same-origin',
        //'sec-fetch-mode': 'same-origin',
        //'sec-fetch-dest': 'empty',
        //'referer': 'https://www.deezer.com/',
        'Cookie': 'arl=$arl' + ((sid == null) ? '' : '; sid=$sid')
      };

  Future<String> getMediaPreview(String trackToken) async {
    //Generate URL
    Uri uri = Uri.https('media.deezer.com', 'v1/get_url');
    //Post
    http.Response res = await http
        .post(uri,
            headers: headers,
            body: jsonEncode({
              'license_token': licenseToken,
              'media': [
                {
                  'formats': [
                    {'cipher': 'NONE', 'format': 'MP3_128'}
                  ],
                  'type': 'PREVIEW',
                }
              ],
              'track_tokens': [trackToken]
            }))
        .catchError((e) {
      return http.Response('', 200);
    });
    if (res.body == '') return '';
    try {
      return jsonDecode(res.body)['data'][0]['media'][0]['sources'][0]['url'];
    } catch (e) {
      Logger.root.info('API preview fetch failed : $e');
      return '';
    }
  }

  Future<String> getTrackPreview(String trackId) async {
    //Generate URL
    Uri uri = Uri.https('api.deezer.com', 'track/$trackId');
    //Post
    http.Response res = await http.get(uri).catchError((e) {
      return http.Response('', 200);
    });

    if (res.body == '') return '';

    try {
      if (jsonDecode(res.body)['preview'] != '') {
        return jsonDecode(res.body)['preview'];
      }

      String isrc = jsonDecode(res.body)['isrc'];
      dynamic data = await deezerAPI.callPublicApi('track/isrc:$isrc');
      return data['preview'];
    } catch (e) {
      Logger.root.info('API preview fetch failed : $e');
      return '';
    }
  }

  //Call private GW-light API
  Future<Map<String, dynamic>> callGwApi(String method,
      {Map<String, dynamic>? params, String? gatewayInput}) async {
    //Generate URL
    Uri uri = Uri.https('www.deezer.com', '/ajax/gw-light.php', {
      'api_version': '1.0',
      'api_token': token,
      'input': '3',
      'method': method,
      'cid': Random().nextInt(1000000000).toString(),
      //Used for homepage
      if (gatewayInput != null) 'gateway_input': gatewayInput
    });
    //Post
    http.Response res = await http
        .post(uri, headers: headers, body: jsonEncode(params))
        .catchError((e) {
      return http.Response('', 200);
    });
    if (res.body == '') return {};
    dynamic body = jsonDecode(res.body);
    //Grab SID
    if (method == 'deezer.getUserData' && res.headers['set-cookie'] != null) {
      for (String cookieHeader in res.headers['set-cookie']!.split(';')) {
        if (cookieHeader.startsWith('sid=')) {
          sid = cookieHeader.split('=')[1];
        }
      }
    }
    // In case of error "Invalid CSRF token" retrieve new one and retry the same call
    // Except for "deezer.getUserData" method, which would cause infinite loop
    if (body['error'].isNotEmpty &&
        body['error'].containsKey('VALID_TOKEN_REQUIRED') &&
        (method != 'deezer.getUserData' && await rawAuthorize())) {
      return callGwApi(method, params: params, gatewayInput: gatewayInput);
    }
    return body;
  }

  Future<Map<dynamic, dynamic>> callPublicApi(String path) async {
    http.Response res =
        await http.get(Uri.parse('https://api.deezer.com/' + path));
    return jsonDecode(res.body);
  }

  Future<String> getJsonWebToken() async {
    //Generate URL
    //Uri uri = Uri.parse('https://auth.deezer.com/login/arl?jo=p&rto=c&i=c');
    Uri uri = Uri.https(
        'auth.deezer.com', '/login/arl', {'jo': 'p', 'rto': 'c', 'i': 'c'});
    //Post
    http.Response res = await http.post(uri, headers: headers);
    dynamic body = jsonDecode(res.body);
    //Grab jwt token
    if (body['jwt']?.isNotEmpty) {
      return body['jwt'];
    }
    return '';
  }

  //Call private pipe API
  Future<Map<String, dynamic>> callPipeApi(
      {Map<String, dynamic>? params}) async {
    //Get jwt auth token
    String jwtToken = await getJsonWebToken();
    Map<String, String> pipeApiHeaders = headers;
    // Add jwt token to headers
    pipeApiHeaders['Authorization'] = 'Bearer $jwtToken';
    // Change Content-Type to application/json
    pipeApiHeaders['Content-Type'] = 'application/json';
    //Generate URL
    //Uri uri = Uri.parse('https://pipe.deezer.com/api');
    Uri uri = Uri.https('pipe.deezer.com', '/api/');
    //Post
    http.Response res =
        await http.post(uri, headers: pipeApiHeaders, body: jsonEncode(params));
    dynamic body = jsonDecode(res.body);

    return body;
  }

  //Wrapper so it can be globally awaited
  Future<bool> authorize() async {
    return await (_authorizing ??= rawAuthorize().then((success) {
      _authorizing = null;
      return success;
    }));
  }

  //Authorize, bool = success
  Future<bool> rawAuthorize({Function? onError}) async {
    try {
      Map<dynamic, dynamic> data = await callGwApi('deezer.getUserData');
      if (data['results']['USER']['USER_ID'] == 0) {
        return false;
      } else {
        token = data['results']['checkForm'];
        userId = data['results']['USER']['USER_ID']?.toString() ?? '';
        favoritesPlaylistId = data['results']['USER']['LOVEDTRACKS_ID'];
        licenseToken = data['results']['USER']['OPTIONS']['license_token'];

        //Store favoritesPlaylistId
        cache.favoritesPlaylistId =
            favoritesPlaylistId ?? cache.favoritesPlaylistId;
        cache.userName = data['results']['USER']['BLOG_NAME'] ?? '';
        cache.userPicture = ImageDetails.fromPrivateString(
                data['results']['USER']['USER_PICTURE'],
                type: 'user')
            .toJson();
        cache.userEmail = data['results']['USER']['EMAIL'];
        cache.userColor = (await PaletteGenerator.fromImageProvider(
                CachedNetworkImageProvider(
                    ImageDetails.fromJson(cache.userPicture).fullUrl ?? '')))
            .dominantColor
            ?.color
            .toARGB32();
        cache.save();

        return true;
      }
    } catch (e) {
      if (onError != null) {
        onError(e);
      }
      Logger.root.severe('Login Error (D): ' + e.toString());
      return false;
    }
  }

  //URL/Link parser
  Future<DeezerLinkResponse?> parseLink(String url) async {
    Uri uri = Uri.parse(url);
    //https://www.deezer.com/NOTHING_OR_COUNTRY/TYPE/ID
    if (uri.host == 'www.deezer.com' || uri.host == 'deezer.com') {
      if (uri.pathSegments.length < 2) return null;
      DeezerLinkType type = DeezerLinkResponse.typeFromString(
          uri.pathSegments[uri.pathSegments.length - 2]);
      return DeezerLinkResponse(
          type: type, id: uri.pathSegments[uri.pathSegments.length - 1]);
    }
    //Share URL
    if (uri.host == 'deezer.page.link' || uri.host == 'www.deezer.page.link') {
      http.BaseRequest request = http.Request('HEAD', Uri.parse(url));
      request.followRedirects = false;
      http.StreamedResponse response = await request.send();
      String newUrl = response.headers['location'] ?? '';
      return parseLink(newUrl);
    }
    //Spotify
    if (uri.host == 'open.spotify.com') {
      if (uri.pathSegments.length < 2) return null;
      String spotifyUri = 'spotify:' + uri.pathSegments.sublist(0, 2).join(':');
      try {
        //Tracks
        if (uri.pathSegments[0] == 'track') {
          String id = await SpotifyScrapper.convertTrack(spotifyUri);
          return DeezerLinkResponse(type: DeezerLinkType.TRACK, id: id);
        }
        //Albums
        if (uri.pathSegments[0] == 'album') {
          String id = await SpotifyScrapper.convertAlbum(spotifyUri);
          return DeezerLinkResponse(type: DeezerLinkType.ALBUM, id: id);
        }
      } catch (e) {
        Logger.root.severe('Error converting Spotify results: ' + e.toString());
      }
    }
    return null;
  }

  //Check if Deezer available in country
  static Future<bool?> checkAvailability() async {
    try {
      http.Response res =
          await http.get(Uri.parse('https://api.deezer.com/infos'));
      return jsonDecode(res.body)['open'];
    } catch (e) {
      return null;
    }
  }

  //Search
  Future<SearchResults> search(String query) async {
    Map<dynamic, dynamic> data = await callGwApi('deezer.pageSearch',
        params: {'nb': 128, 'query': query, 'start': 0});
    return SearchResults.fromPrivateJson(data['results']);
  }

  Future<Track> track(String id) async {
    Map<dynamic, dynamic> data = await callGwApi('song.getListData', params: {
      'sng_ids': [id]
    });
    return Track.fromPrivateJson(data['results']['data'][0]);
  }

  //Get album details, tracks
  Future<Album> album(String id) async {
    Map<dynamic, dynamic> data = await callGwApi('deezer.pageAlbum', params: {
      'alb_id': id,
      'header': true,
      'lang': settings.deezerLanguage
    });
    while (data['results']?['DATA'] == null &&
        data['payload']?['FALLBACK']?['ALB_ID'] != null) {
      data = await callGwApi('deezer.pageAlbum', params: {
        'alb_id': data['payload']?['FALLBACK']?['ALB_ID'],
        'header': true,
        'lang': settings.deezerLanguage
      });
    }
    if (data['results']?['DATA'] == null) return Album();
    return Album.fromPrivateJson(data['results']['DATA'],
        songsJson: data['results']['SONGS']);
  }

  //Get artist details
  Future<Artist> artist(String id) async {
    Map<dynamic, dynamic> data = await callGwApi('deezer.pageArtist', params: {
      'art_id': id,
      'lang': settings.deezerLanguage,
    });
    return Artist.fromPrivateJson(data['results']['DATA'],
        topJson: data['results']['TOP'],
        albumsJson: data['results']['ALBUMS'],
        highlight: data['results']['HIGHLIGHT']);
  }

  //Get playlist tracks at offset
  Future<List<Track>> playlistTracksPage(String id, int start,
      {int nb = 50}) async {
    Map data = await callGwApi('deezer.pagePlaylist', params: {
      'playlist_id': id,
      'lang': settings.deezerLanguage,
      'nb': nb,
      'tags': true,
      'start': start
    });
    return data['results']['SONGS']['data']
        .map<Track>((json) => Track.fromPrivateJson(json))
        .toList();
  }

  //Get playlist details
  Future<Playlist> playlist(String id, {int nb = 100}) async {
    Map<dynamic, dynamic> data =
        await callGwApi('deezer.pagePlaylist', params: {
      'playlist_id': id,
      'lang': settings.deezerLanguage,
      'nb': nb,
      'tags': true,
      'start': 0
    });
    if (data['results'] == null) return Playlist();
    return Playlist.fromPrivateJson(data['results']['DATA'],
        songsJson: data['results']['SONGS']);
  }

  //Get playlist with all tracks
  Future<Playlist> fullPlaylist(String id) async {
    return await playlist(id, nb: 100000);
  }

  //Add track to favorites
  Future addFavoriteTrack(String id) async {
    await callGwApi('favorite_song.add', params: {'SNG_ID': id});
    if (await downloadManager.checkOffline(
        playlist: Playlist(id: favoritesPlaylistId))) {
      downloadManager.updateOfflinePlaylist(Playlist(id: favoritesPlaylistId));
    }
  }

  //Add album to favorites/library
  Future addFavoriteAlbum(String id) async {
    await callGwApi('album.addFavorite', params: {'ALB_ID': id});
  }

  //Add artist to favorites/library
  Future addFavoriteArtist(String id) async {
    await callGwApi('artist.addFavorite', params: {'ART_ID': id});
  }

  //Remove artist from favorites/library
  Future removeArtist(String id) async {
    await callGwApi('artist.deleteFavorite', params: {'ART_ID': id});
  }

  // Mark track as disliked
  Future dislikeTrack(String id) async {
    await callGwApi('favorite_dislike.add', params: {'ID': id, 'TYPE': 'song'});
  }

  //Add tracks to playlist
  Future addToPlaylist(String trackId, String playlistId,
      {int offset = -1}) async {
    await callGwApi('playlist.addSongs', params: {
      'offset': offset,
      'playlist_id': playlistId,
      'songs': [
        [trackId, 0]
      ]
    });
    if (await downloadManager.checkOffline(
        playlist: Playlist(id: playlistId))) {
      downloadManager.updateOfflinePlaylist(Playlist(id: favoritesPlaylistId));
    }
  }

  //Remove track from playlist
  Future removeFromPlaylist(String trackId, String playlistId) async {
    await callGwApi('playlist.deleteSongs', params: {
      'playlist_id': playlistId,
      'songs': [
        [trackId, 0]
      ]
    });
  }

  //Get homepage/music library from deezer
  Future<List<Playlist>> getUserGames() async {
    List grid = [
      'album',
      'artist',
      'artistLineUp',
      'channel',
      'livestream',
      'flow',
      'playlist',
      'radio',
      'show',
      'smarttracklist',
      'track',
      'user',
      'video-link',
      'external-link'
    ];
    Map data = await callGwApi('page.get',
        gatewayInput: jsonEncode({
          'PAGE': 'channels/games',
          'VERSION': '2.5',
          'SUPPORT': {
            /*
        "deeplink-list": ["deeplink"],
        "list": ["episode"],
        "grid-preview-one": grid,
        "grid-preview-two": grid,
        "slideshow": grid,
        "message": ["call_onboarding"],
        */
            'filterable-grid': ['flow'],
            'grid': grid,
            'horizontal-grid': grid,
            'item-highlight': ['radio'],
            'large-card': ['album', 'playlist', 'show', 'video-link'],
            'ads': [] //Nope
          },
          'LANG': settings.deezerLanguage,
          'OPTIONS': []
        }));

    List<dynamic> sections = data['results']['sections'];
    List<Playlist> userQuizzes = [];

    for (int i = 0; i < sections.length; i++) {
      List<dynamic> items = sections[i]['items'];

      for (int j = 0; j < items.length; j++) {
        final regex = RegExp(r'^/game/blindtest/playlist/(\d+)');
        final match = regex.firstMatch(items[j]['target']);

        if (match != null) {
          Playlist target = await playlist(match.group(1) ?? '', nb: 0);
          userQuizzes.add(target);
        }
      }
    }
    return userQuizzes;
  }

  Future<List<Playlist>> getMusicQuizzes() async {
    Map data = await callGwApi('deezer.pageProfile',
        params: {'nb': 100, 'tab': 'playlists', 'user_id': '5207298602'});
    return data['results']['TAB']['playlists']['data']
        .map<Playlist>((json) => Playlist.fromPrivateJson(json, library: true))
        .toList();
  }

  //Get users playlists
  Future<List<Playlist>> getPlaylists() async {
    Map data = await callGwApi('deezer.pageProfile',
        params: {'nb': 100, 'tab': 'playlists', 'user_id': userId});
    return data['results']['TAB']['playlists']['data']
        .map<Playlist>((json) => Playlist.fromPrivateJson(json, library: true))
        .toList();
  }

  //Get favorite trackIds
  Future<List<String>?> getFavoriteTrackIds() async {
    Map data =
        await callGwApi('user.getAllFeedbacks', params: {'checksums': null});
    final songsData = data['results']?['FAVORITES']?['SONGS']?['data'];

    if (songsData is List) {
      return songsData.map<String>((song) => song['SNG_ID'] as String).toList();
    }
    return null;
  }

  //Get favorite albums
  Future<List<Album>> getAlbums() async {
    Map data = await callGwApi('deezer.pageProfile',
        params: {'nb': 50, 'tab': 'albums', 'user_id': userId});
    List albumList = data['results']['TAB']['albums']['data'];
    List<Album> albums = albumList
        .map<Album>((json) => Album.fromPrivateJson(json, library: true))
        .toList();
    return albums;
  }

  //Remove album from library
  Future removeAlbum(String id) async {
    await callGwApi('album.deleteFavorite', params: {'ALB_ID': id});
  }

  //Remove track from favorites
  Future removeFavorite(String id) async {
    await callGwApi('favorite_song.remove', params: {'SNG_ID': id});
  }

  //Get favorite artists
  Future<List<Artist>> getArtists() async {
    Map data = await callGwApi('deezer.pageProfile',
        params: {'nb': 40, 'tab': 'artists', 'user_id': userId});
    return data['results']['TAB']['artists']['data']
        .map<Artist>((json) => Artist.fromPrivateJson(json, library: true))
        .toList();
  }

  //Get lyrics by track id
  Future<LyricsFull> lyrics(Track track) async {
    for (String provider in settings.lyricsProviders) {
      if (provider == 'DEEZER') {
        // First try to get lyrics from pipe API
        Lyrics lyricsFromPipeApi = await lyricsFull(track.id ?? '');

        if (lyricsFromPipeApi.errorMessage == null &&
            lyricsFromPipeApi.isLoaded()) {
          return lyricsFromPipeApi as LyricsFull;
        }

        // Fallback to get lyrics from legacy GW api
        Lyrics lyricsFromLegacy = await lyricsLegacy(track.id ?? '');

        if (lyricsFromLegacy.errorMessage == null &&
            lyricsFromLegacy.isLoaded()) {
          return lyricsFromLegacy as LyricsFull;
        }
      } else if (provider == 'LRCLIB') {
        http.Response res = await http.get(Uri.parse(
            'https://lrclib.net/api/get?artist_name=' +
                (track.artists?[0].name ?? '') +
                '&track_name=' +
                (track.title ?? '')));
        Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));

        if (data['statusCode'] != 404) {
          List<SynchronizedLyric> synchronizedLyrics = [];
          List<String> synchronizedLines =
              (data['syncedLyrics'] ?? '').split('\n');

          for (int i = 0; i < synchronizedLines.length; i++) {
            List<String> line = synchronizedLines[i].split(' ');
            List<String> offset = line
                .removeAt(0)
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(':');
            String lyric = line.join(' ');
            synchronizedLyrics.add(
              SynchronizedLyric(
                  offset: Duration(
                      minutes: int.parse(offset.first),
                      milliseconds: (double.parse(offset.last) * 1000).round()),
                  text: lyric),
            );
          }

          LyricsFull lrclyrics = LyricsFull(
            id: data['id'].toString(),
            syncedLyrics: synchronizedLyrics,
            unsyncedLyrics: data['plainLyrics'],
            provider: LyricsProvider.LRCLIB,
          );
          return lrclyrics;
        }
      } else if (provider == 'LYRICFIND') {
/*
        if (settings.lyricfindKey != null) {
          http.Response res = await http.get(Uri.parse(
              'https://api.lyricfind.com/lyric.do?apikey=${settings.lyricfindKey}&territory=${settings.deezerCountry}&lrckey=&reqtype=default&trackid=isrc:&format=lrconly,clean&output=json' +
                  (track.artists?[0].name ?? '') +
                  '&track_name=' +
                  (track.title ?? '')));
          Map<String, dynamic> data = jsonDecode(res.body);

          return LyricsFull(
            id: data['id'],
            syncedLyrics: data['syncedLyrics'],
            unsyncedLyrics: data['plainLyrics'],
            provider: LyricsProvider.LYRICFIND,
          );
        }
*/
      }
    }

    // No lyrics found, prefer to use pipe api error message
    //return lyricsFromPipeApi;
    return LyricsFull();
  }

  //Get lyrics by track id from legacy GW api
  Future<Lyrics> lyricsLegacy(String trackId) async {
    Map data = await callGwApi('song.getLyrics', params: {'sng_id': trackId});
    if (data['error'] != null && data['error'].length > 0) {
      return Lyrics.error(data['error']['DATA_ERROR']);
    }
    return LyricsClassic.fromPrivateJson(data['results']);
  }

  //Get lyrics by track id from pipe API
  Future<Lyrics> lyricsFull(String trackId) async {
    // Create lyrics request body with GraphQL query
    String queryStringGraphQL = '''
      query SynchronizedTrackLyrics(\$trackId: String!) {
        track(trackId: \$trackId) {
          id
          isExplicit
          lyrics {
            id
            copyright
            text
            writers
            synchronizedLines {
              lrcTimestamp
              line
              milliseconds
              duration
            }
          }
        }
      }''';

    /* Alternative query using fragments, used by Deezer web app
    String queryStringGraphQL = '''
      query SynchronizedTrackLyrics(\$trackId: String!) {
        track(trackId: \$trackId) {
          ...SynchronizedTrackLyrics
        }
      }
      fragment SynchronizedTrackLyrics on Track {
        id
        isExplicit
        lyrics {
          ...Lyrics
        }
      }
      fragment Lyrics on Lyrics {
        id
        copyright
        text
        writers
        synchronizedLines {
          ...LyricsSynchronizedLines
        }
      }
      fragment LyricsSynchronizedLines on LyricsSynchronizedLine {
        lrcTimestamp
        line
        milliseconds
        duration
      }
      ''';
    */

    Map<String, dynamic> requestParams = {
      'operationName': 'SynchronizedTrackLyrics',
      'variables': {'trackId': trackId},
      'query': queryStringGraphQL
    };
    Map data = await callPipeApi(params: requestParams);

    if (data['errors'] != null && data['errors'].length > 0) {
      return Lyrics.error('err');
    }
    return LyricsFull.fromPrivateJson(data['data']);
  }

  Future<SmartTrackList?> smartTrackList(String id) async {
    Map data = await callGwApi('deezer.pageSmartTracklist',
        params: {'smarttracklist_id': id});
    if (data['results']['DATA'] == null) {
      return null;
    }
    return SmartTrackList.fromPrivateJson(data['results']['DATA'],
        songsJson: data['results']['SONGS']);
  }

  Future<List<Track>> flow({String? type}) async {
    Map data = await callGwApi('radio.getUserRadio',
        params: {'user_id': userId, 'config_id': type});
    return data['results']['data']
        .map<Track>((json) => Track.fromPrivateJson(json))
        .toList();
  }

  //Get homepage/music library from deezer
  Future<HomePage> homePage() async {
    List grid = [
      'album',
      'artist',
      'channel',
      'flow',
      'playlist',
      'radio',
      'show',
      'smarttracklist',
      'track',
      'user'
    ];
    Map data = await callGwApi('page.get',
        gatewayInput: jsonEncode({
          'PAGE': 'home',
          'VERSION': '2.5',
          'SUPPORT': {
            /*
        "deeplink-list": ["deeplink"],
        "list": ["episode"],
        "grid-preview-one": grid,
        "grid-preview-two": grid,
        "slideshow": grid,
        "message": ["call_onboarding"],
        */
            'filterable-grid': ['flow'],
            'grid': grid,
            'horizontal-grid': grid,
            'item-highlight': ['radio'],
            'large-card': ['album', 'playlist', 'show', 'video-link'],
            'ads': [] //Nope
          },
          'LANG': settings.deezerLanguage,
          'OPTIONS': []
        }));
    return HomePage.fromPrivateJson(data['results']);
  }

  //Log song listen to deezer
  Future logListen(String trackId) async {
    await callGwApi('log.listen', params: {
      'params': {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ts_listen': DateTime.now().millisecondsSinceEpoch,
        'type': 1,
        'stat': {'seek': 0, 'pause': 0, 'sync': 1},
        'media': {'id': trackId, 'type': 'song', 'format': 'MP3_128'}
      }
    });
  }

  Future<HomePage> getChannel(String target) async {
    List grid = [
      'album',
      'artist',
      'channel',
      'flow',
      'playlist',
      'radio',
      'show',
      'smarttracklist',
      'track',
      'user'
    ];
    Map data = await callGwApi('page.get',
        gatewayInput: jsonEncode({
          'PAGE': target,
          'VERSION': '2.5',
          'SUPPORT': {
            /*
        "deeplink-list": ["deeplink"],
        "list": ["episode"],
        "grid-preview-one": grid,
        "grid-preview-two": grid,
        "slideshow": grid,
        "message": ["call_onboarding"],
        */
            'filterable-grid': ['flow'],
            'grid': grid,
            'horizontal-grid': grid,
            'item-highlight': ['radio'],
            'large-card': ['album', 'playlist', 'show', 'video-link'],
            'ads': [] //Nope
          },
          'LANG': settings.deezerLanguage,
          'OPTIONS': []
        }));
    return HomePage.fromPrivateJson(data['results']);
  }

  //Add playlist to library
  Future addPlaylist(String id) async {
    await callGwApi('playlist.addFavorite',
        params: {'parent_playlist_id': int.parse(id)});
  }

  //Remove playlist from library
  Future removePlaylist(String id) async {
    await callGwApi('playlist.deleteFavorite',
        params: {'playlist_id': int.parse(id)});
  }

  //Delete playlist
  Future deletePlaylist(String id) async {
    await callGwApi('playlist.delete', params: {'playlist_id': id});
  }

  //Create playlist
  //Status 1 - private, 2 - collaborative
  Future<String> createPlaylist(String title,
      {String description = '',
      int status = 1,
      List<String> trackIds = const []}) async {
    Map data = await callGwApi('playlist.create', params: {
      'title': title,
      'description': description,
      'songs': trackIds
          .map<List>((id) => [int.parse(id), trackIds.indexOf(id)])
          .toList(),
      'status': status
    });
    //Return playlistId
    return data['results'].toString();
  }

  //Get part of discography
  Future<List<Album>> discographyPage(String artistId,
      {int start = 0, int nb = 50}) async {
    Map data = await callGwApi('album.getDiscography', params: {
      'art_id': int.parse(artistId),
      'discography_mode': 'all',
      'nb': nb,
      'start': start,
      'nb_songs': 30
    });

    return data['results']['data']
        .map<Album>((a) => Album.fromPrivateJson(a))
        .toList();
  }

  Future<List> searchSuggestions(String query) async {
    Map data =
        await callGwApi('search_getSuggestedQueries', params: {'QUERY': query});
    return data['results']['SUGGESTION'].map((s) => s['QUERY']).toList();
  }

  //Get smart radio for artist id
  Future<List<Track>> smartRadio(String artistId) async {
    Map data = await callGwApi('smart.getSmartRadio',
        params: {'art_id': int.parse(artistId)});
    return data['results']['data']
        .map<Track>((t) => Track.fromPrivateJson(t))
        .toList();
  }

  //Update playlist metadata, status = see createPlaylist
  Future updatePlaylist(String id, String title, String description,
      {int status = 1}) async {
    await callGwApi('playlist.update', params: {
      'description': description,
      'title': title,
      'playlist_id': int.parse(id),
      'status': status,
      'songs': []
    });
  }

  //Get shuffled library
  Future<List<Track>> libraryShuffle({int start = 0}) async {
    Map data = await callGwApi('tracklist.getShuffledCollection',
        params: {'nb': 50, 'start': start});
    return data['results']['data']
        .map<Track>((t) => Track.fromPrivateJson(t))
        .toList();
  }

  //Get similar tracks for track with id [trackId]
  Future<List<Track>> playMix(String trackId) async {
    Map data = await callGwApi('song.getSearchTrackMix',
        params: {'sng_id': trackId, 'start_with_input_track': 'true'});
    return data['results']['data']
        .map<Track>((t) => Track.fromPrivateJson(t))
        .toList();
  }

  Future<List<ShowEpisode>> allShowEpisodes(String showId) async {
    Map data = await callGwApi('deezer.pageShow', params: {
      'country': settings.deezerCountry,
      'lang': settings.deezerLanguage,
      'nb': 1000,
      'show_id': showId,
      'start': 0,
      'user_id': int.parse(deezerAPI.userId ?? ''),
    });
    return data['results']['EPISODES']['data']
        .map<ShowEpisode>((e) => ShowEpisode.fromPrivateJson(e))
        .toList();
  }
}
