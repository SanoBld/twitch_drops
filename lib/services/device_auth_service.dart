import 'dart:async';
import 'package:dio/dio.dart';
import 'twitch_constants.dart';

// Twitch "TV-style" login: request a code, show it to the user with a URL,
// then poll until they approve it on twitch.tv/activate.
class DeviceCodeInfo {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int interval;
  final int expiresIn;

  DeviceCodeInfo({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresIn,
  });
}

class DeviceAuthService {
  final Dio _dio = Dio();

  Future<DeviceCodeInfo> requestCode() async {
    final res = await _dio.post(
      TwitchConstants.deviceCodeUrl,
      data: {
        'client_id': TwitchConstants.deviceClientId,
        'scopes': 'channel_read user_read user_blocks_edit',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final d = res.data;
    return DeviceCodeInfo(
      deviceCode: d['device_code'],
      userCode: d['user_code'],
      verificationUri: d['verification_uri'],
      interval: d['interval'] ?? 5,
      expiresIn: d['expires_in'] ?? 1800,
    );
  }

  // Polls Twitch until the user approves the code, or it expires.
  // Returns the access token, or null if expired/cancelled.
  Future<String?> pollForToken(
    DeviceCodeInfo info, {
    bool Function()? shouldCancel,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: info.expiresIn));
    while (DateTime.now().isBefore(deadline)) {
      if (shouldCancel != null && shouldCancel()) return null;
      await Future.delayed(Duration(seconds: info.interval));
      try {
        final res = await _dio.post(
          TwitchConstants.tokenUrl,
          data: {
            'client_id': TwitchConstants.deviceClientId,
            'device_code': info.deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        final token = res.data['access_token'];
        if (token != null) return token;
      } on DioException catch (e) {
        // 400 with "authorization_pending" is expected while waiting.
        final err = e.response?.data?['message'] ?? '';
        if (err != 'authorization_pending') {
          if (err == 'expired_token' || err == 'incorrect_device_code') return null;
        }
      }
    }
    return null;
  }
}
