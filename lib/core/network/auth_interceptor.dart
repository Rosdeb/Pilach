import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

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

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
          final response = await refreshDio.post(
            ApiConstants.refreshToken,
            data: {"refreshToken": refreshToken},
            options: Options(
              headers: {
                'Cookie': 'refresh_token=$refreshToken',
              },
            ),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            String? newAccessToken;
            String? newRefreshToken;

            final data = response.data;
            if (data != null && data['tokens'] != null) {
              newAccessToken = data['tokens']['access']['token'];
              newRefreshToken = data['tokens']['refresh']['token'];
            } else {
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

              err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              err.requestOptions.headers['Cookie'] = 'access_token=$newAccessToken';
              
              final retryResponse = await dio.fetch(err.requestOptions);
              return handler.resolve(retryResponse);
            } else {
              throw Exception("Failed to extract new access token");
            }
          }
        } catch (e) {
          await prefs.remove('auth_token');
          await prefs.remove('refresh_token');
          onUnauthenticated();
          return handler.reject(err);
        }
      } else {
        await prefs.remove('auth_token');
        await prefs.remove('refresh_token');
        onUnauthenticated();
        return handler.reject(err);
      }
    }
    super.onError(err, handler);
  }
}