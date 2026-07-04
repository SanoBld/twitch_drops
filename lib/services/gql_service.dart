import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'twitch_constants.dart';
import 'auth_service.dart';
import 'log_service.dart';

class GqlService {
  final AuthService auth;
  final Dio _dio = Dio();
  final _log = LogService();

  GqlService(this.auth);

  // IMPORTANT: use the Android app's Client-Id (deviceClientId), not the
  // web Client-Id, for GQL calls. Twitch's anti-bot "integrity" system
  // blocks sensitive fields (like dropCampaigns) for the web client unless
  // a Kasada challenge token is supplied. The Android client is currently
  // NOT subject to that check, which is the same workaround DevilXD's
  // TwitchDropsMiner uses (see: "Workaround the entirety of the integrity
  // system by using an unprotected Android app Client ID").
  Map<String, String> get _headers => {
        'Client-Id': TwitchConstants.deviceClientId,
        'Authorization': 'OAuth ${auth.token}',
        'Content-Type': 'application/json',
        'User-Agent': TwitchConstants.userAgent,
      };

  // Persisted query (with sha256Hash) or plain operation (without).
  Future<Map<String, dynamic>> query(
    String operationName,
    Map<String, dynamic> variables, {
    String? sha256Hash,
  }) async {
    final body = sha256Hash == null
        ? {'operationName': operationName, 'variables': variables}
        : {
            'operationName': operationName,
            'variables': variables,
            'extensions': {
              'persistedQuery': {'version': 1, 'sha256Hash': sha256Hash}
            }
          };

    try {
      final res = await _dio.post(
        TwitchConstants.gqlUrl,
        data: body,
        options: Options(headers: _headers),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _log.log(
        'query($operationName) failed: ${e.response?.statusCode} '
        '${e.response?.data ?? e.message}',
        tag: 'GqlService',
      );
      rethrow;
    }
  }

  // Raw query string (non-persisted), used for PlaybackAccessToken.
  Future<Map<String, dynamic>> rawQuery(
    String queryStr,
    String operationName,
    Map<String, dynamic> variables,
  ) async {
    try {
      final res = await _dio.post(
        TwitchConstants.gqlUrl,
        data: {
          'operationName': operationName,
          'query': queryStr,
          'variables': variables,
        },
        options: Options(headers: _headers),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _log.log(
        'rawQuery($operationName) failed: ${e.response?.statusCode} '
        '${e.response?.data ?? e.message}',
        tag: 'GqlService',
      );
      rethrow;
    }
  }

  // Sends the Spade "minute-watched" event via sendSpadeEvents GQL mutation.
  // Payload is a JSON array encoded as GZIP then Base64.
  Future<void> sendMinuteWatched({
    required String channelId,
    required String broadcastId,
    required String channelLogin,
    required String gameId,
    required String gameName,
    required String userId,
    required String userLogin,
  }) async {
    final payload = [
      {
        'event': 'minute-watched',
        'properties': {
          'broadcast_id': broadcastId,
          'channel': channelLogin,
          'channel_id': channelId,
          'client_time': DateTime.now().millisecondsSinceEpoch / 1000.0,
          'game': gameName,
          'game_id': gameId,
          'hidden': false,
          'is_live': true,
          'live': true,
          'logged_in': true,
          'login': userLogin,
          'minutes_logged': 1,
          'muted': false,
          'platform': 'web',
          'player': 'site',
          'user_id': int.tryParse(userId) ?? 0,
        }
      }
    ];

    final jsonBytes = utf8.encode(jsonEncode(payload));
    final gzipped = GZipCodec().encode(jsonBytes);
    final b64 = base64Encode(gzipped);

    const mutation = '''
  mutation SendEvents(\$input: SendSpadeEventsInput!) {
    sendSpadeEvents(input: \$input) {
      statusCode
    }
  }
''';

    try {
      await _dio.post(
        TwitchConstants.gqlUrl,
        data: {
          'query': mutation,
          'variables': {
            'input': {
              'data': b64,
              'encoding': 'GZIP_B64',
              'repository': 'twilight',
            }
          },
        },
        options: Options(headers: _headers),
      );
      _log.log('minute-watched sent for $channelLogin', tag: 'GqlService');
    } on DioException catch (e) {
      _log.log(
        'sendMinuteWatched failed for $channelLogin: '
        '${e.response?.statusCode} ${e.response?.data ?? e.message}',
        tag: 'GqlService',
      );
    }
  }

  // Fetches full drop details (including timeBasedDrops + self progress)
  // for a single campaign. ViewerDropsDashboard only gives the summary.
  Future<Map<String, dynamic>> fetchCampaignDetails({
    required String channelLogin,
    required String dropId,
  }) async {
    final res = await query(
      'DropCampaignDetails',
      {
        'channelLogin': channelLogin,
        'dropID': dropId,
      },
      sha256Hash:
          '039277bf98f3130929262cc7c6efd9c141ca3749cb6dca442fc8ead9a53f77c1',
    );
    return res;
  }

  // Claims a completed drop's reward. Called automatically as soon as a
  // "drop-claim" event comes in over the user-drop-events websocket.
  Future<bool> claimDropReward(String dropInstanceId) async {
    try {
      final res = await query(
        'DropsPage_ClaimDropRewards',
        {
          'input': {'dropInstanceID': dropInstanceId}
        },
        sha256Hash:
            '2f884fa187b8fadb2a49db0adc033e636f7b6aaee6e76de1e2bba9a7baf0daf6',
      );
      if (res['errors'] != null) {
        _log.log('claimDropReward errors: ${res['errors']}', tag: 'GqlService');
        return false;
      }
      return true;
    } catch (e) {
      _log.log('claimDropReward failed for $dropInstanceId: $e',
          tag: 'GqlService');
      return false;
    }
  }

  // Fetches the logged-in user's ID and login from GQL.
  Future<Map<String, String>?> fetchCurrentUser() async {
    try {
      const q = '{ currentUser { id login } }';
      final res = await _dio.post(
        TwitchConstants.gqlUrl,
        data: {'query': q},
        options: Options(headers: _headers),
      );
      final user = (res.data as Map<String, dynamic>)['data']?['currentUser'];
      if (user == null) {
        _log.log('fetchCurrentUser: currentUser is null (bad/expired token)',
            tag: 'GqlService');
        return null;
      }
      return {
        'id': user['id']?.toString() ?? '',
        'login': user['login']?.toString() ?? '',
      };
    } catch (e) {
      _log.log('fetchCurrentUser failed: $e', tag: 'GqlService');
      return null;
    }
  }
}