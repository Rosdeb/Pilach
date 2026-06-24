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
          );

          if (response.statusCode == 200) {
            final newAccessToken = response.data['tokens']['access']['token'];
            final newRefreshToken = response.data['tokens']['refresh']['token'];
            
            await prefs.setString('auth_token', newAccessToken);
            await prefs.setString('refresh_token', newRefreshToken);

            err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            final retryResponse = await dio.fetch(err.requestOptions);
            return handler.resolve(retryResponse);
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