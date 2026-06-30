import 'package:dio/dio.dart';
import 'twitch_constants.dart';
import 'auth_service.dart';

// Sends GQL requests to Twitch internal API.
class GqlService {
  final AuthService auth;
  final Dio _dio = Dio();

  GqlService(this.auth);

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

    final res = await _dio.post(
      TwitchConstants.gqlUrl,
      data: body,
      options: Options(headers: {
        'Client-Id': TwitchConstants.clientId,
        'Authorization': 'OAuth ${auth.token}',
        'Content-Type': 'application/json',
        'User-Agent': TwitchConstants.userAgent,
      }),
    );
    return res.data as Map<String, dynamic>;
  }

  // For requests Twitch sends as a raw query string instead of a persisted
  // hash (e.g. PlaybackAccessToken). Pass the exact `query` field captured
  // from devtools.
  Future<Map<String, dynamic>> rawQuery(
    String operationName,
    String rawQueryString,
    Map<String, dynamic> variables,
  ) async {
    final res = await _dio.post(
      TwitchConstants.gqlUrl,
      data: {
        'operationName': operationName,
        'query': rawQueryString,
        'variables': variables,
      },
      options: Options(headers: {
        'Client-Id': TwitchConstants.clientId,
        'Authorization': 'OAuth ${auth.token}',
        'Content-Type': 'application/json',
        'User-Agent': TwitchConstants.userAgent,
      }),
    );
    return res.data as Map<String, dynamic>;
  }
}
