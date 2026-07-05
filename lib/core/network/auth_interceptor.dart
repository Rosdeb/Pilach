import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class TokenRefresher {
  static Future<String?> Function()? refresh;
}

class AuthInterceptor extends Interceptor {
  final SharedPreferences prefs;
  final Dio dio;
  final void Function() onUnauthenticated;

  AuthInterceptor(this.prefs, this.dio, {required this.onUnauthenticated});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.headers['Cookie'] = 'access_token=$token';
    }
    super.onRequest(options, handler);
  }

  Future<String?>? _refreshFuture;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    if (_isUnauthorized(response)) {
      final newAccessToken = await refreshToken();
      if (newAccessToken != null) {
        try {
          final requestOptions = response.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          requestOptions.headers['Cookie'] = 'access_token=$newAccessToken';
          final retryResponse = await dio.fetch(requestOptions);
          return handler.resolve(retryResponse);
        } catch (e) {
          return handler.next(response);
        }
      }
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_isUnauthorized(err.response)) {
      final newAccessToken = await refreshToken();
      if (newAccessToken != null) {
        try {
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          err.requestOptions.headers['Cookie'] = 'access_token=$newAccessToken';
          final retryResponse = await dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (e) {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: e,
              type: DioExceptionType.unknown,
            ),
          );
        }
      } else {
        return handler.reject(err);
      }
    }
    super.onError(err, handler);
  }

  bool _isUnauthorized(Response? response) {
    if (response == null) return false;
    if (response.statusCode == 401) return true;

    final data = response.data;
    if (data is Map) {
      final success = data['success'];
      final statusCode = data['statusCode'];
      final message = data['message']?.toString();

      final isStatus401 = statusCode == 401 || statusCode == '401';
      final isUnauthorizedMsg = message != null &&
          (message.toLowerCase() == 'unauthorized' ||
              message.toLowerCase().contains('unauthorized'));

      if (isStatus401 || isUnauthorizedMsg) {
        return true;
      }

      if (success == false && (isStatus401 || isUnauthorizedMsg)) {
        return true;
      }
    }
    return false;
  }

  Future<String?> refreshToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture;
    }

    final currentRefreshToken = prefs.getString('refresh_token');
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
      onUnauthenticated();
      return null;
    }

    _refreshFuture = _performRefresh(currentRefreshToken);
    try {
      final newToken = await _refreshFuture;
      return newToken;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _performRefresh(String currentRefreshToken) async {
    try {
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await refreshDio.post(
        ApiConstants.refreshToken,
        data: {"refreshToken": currentRefreshToken},
        options: Options(
          headers: {
            'Cookie': 'refresh_token=$currentRefreshToken',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? newAccessToken;
        String? newRefreshToken;

        final data = response.data;
        if (data is Map) {
          newAccessToken = data['accessToken'] ?? data['token'] ?? data['access_token'] ?? data['data']?['accessToken'] ?? data['data']?['token'];
          newRefreshToken = data['refreshToken'] ?? data['refresh_token'] ?? data['data']?['refreshToken'];

          if (newAccessToken == null && data['tokens'] != null) {
            newAccessToken = data['tokens']?['access']?['token'] ?? data['tokens']?['accessToken'];
            newRefreshToken = data['tokens']?['refresh']?['token'] ?? data['tokens']?['refreshToken'];
          }
        }

        if (newAccessToken == null || newAccessToken.isEmpty) {
          final cookies = response.headers.map['set-cookie'] ?? [];
          for (var cookie in cookies) {
            if (cookie.contains('access_token=')) {
              final match = RegExp(r'access_token=([^;]+)').firstMatch(cookie);
              if (match != null) newAccessToken = match.group(1);
            }
            if (cookie.contains('refresh_token=')) {
              final match = RegExp(r'refresh_token=([^;]+)').firstMatch(cookie);
              if (match != null) newRefreshToken = match.group(1);
            }
          }
        }

        if (newAccessToken != null) {
          await prefs.setString('auth_token', newAccessToken);
          if (newRefreshToken != null) {
            await prefs.setString('refresh_token', newRefreshToken);
          }
          return newAccessToken;
        }
      }
    } catch (e) {
      // Caught exception during token refresh
    }

    // Refresh failed - clear tokens and trigger sign out
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    onUnauthenticated();
    return null;
  }
}