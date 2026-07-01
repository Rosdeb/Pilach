
import 'package:dio/dio.dart';
import '../services/socket_service.dart';
import '../theme/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../network/auth_interceptor.dart';
import '../constants/api_constants.dart';


final unauthenticatedTriggerProvider = StateProvider<int>((ref) => 0);

final dioProvider = Provider<Dio>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': ApiConstants.contentType,
        'Accept': ApiConstants.contentType,
        'X-Auth-Transport': 'bearer',
      },
    ),
  );

  // 1. Attach Auth Interceptor
  dio.interceptors.add(AuthInterceptor(prefs, dio, onUnauthenticated: () {
    // Push the state to unauthenticated explicitly if tokens are invalid
    ref.read(unauthenticatedTriggerProvider.notifier).state++;
  }));

  // 2. Attach Timer Interceptor to log API response times
  if (kDebugMode) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.extra['start_time'] = DateTime.now().millisecondsSinceEpoch;
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final startTime = response.requestOptions.extra['start_time'];
        if (startTime != null) {
          final duration = DateTime.now().millisecondsSinceEpoch - startTime;
          print('✅ [API SUCCESS] ${response.requestOptions.path} - Time: ${duration}ms');
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        final startTime = e.requestOptions.extra['start_time'];
        if (startTime != null) {
          final duration = DateTime.now().millisecondsSinceEpoch - startTime;
          print('❌ [API ERROR] ${e.requestOptions.path} - Time: ${duration}ms');
        }
        return handler.next(e);
      },
    ));

    // Attach Logger Interceptor
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: false,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      error: true,
    ));
  }

  return dio;
});

// The final global provider you will use everywhere!
final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(baseUrl: ApiConstants.baseUrl);
});