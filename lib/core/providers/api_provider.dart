
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import '../services/socket_service.dart';
import '../theme/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/api_service.dart';
import '../network/auth_interceptor.dart';
import '../constants/api_constants.dart';
import '../utils/app_logger.dart';


final unauthenticatedTriggerProvider = StateProvider<int>((ref) => 0);

final dioProvider = Provider<Dio>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  String userAgent = 'Pilach/1.0';
  if (!kIsWeb) {
    if (Platform.isIOS) {
      userAgent =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Pilach/1.0';
    } else if (Platform.isAndroid) {
      userAgent =
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 Pilach/1.0';
    } else if (Platform.isMacOS) {
      userAgent =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Pilach/1.0';
    } else if (Platform.isWindows) {
      userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Pilach/1.0';
    }
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': ApiConstants.contentType,
        'Accept': ApiConstants.contentType,
        'X-Auth-Transport': 'bearer',
        'User-Agent': userAgent,
      },
    ),
  );

  // 1. Attach Auth Interceptor
  final authInterceptor = AuthInterceptor(prefs, dio, onUnauthenticated: () {
    // Push the state to unauthenticated explicitly if tokens are invalid
    ref.read(unauthenticatedTriggerProvider.notifier).state++;
  });
  TokenRefresher.refresh = authInterceptor.refreshToken;
  dio.interceptors.add(authInterceptor);

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
          Logger.log('✅ [API SUCCESS] ${response.requestOptions.path} - Time: ${duration}ms');
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        final startTime = e.requestOptions.extra['start_time'];
        if (startTime != null) {
          final duration = DateTime.now().millisecondsSinceEpoch - startTime;
          Logger.log('❌ [API ERROR] ${e.requestOptions.path} - Time: ${duration}ms');
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
  final service = SocketService(baseUrl: ApiConstants.baseUrl);
  service.onTokenRefreshRequested = () async {
    if (TokenRefresher.refresh != null) {
      return await TokenRefresher.refresh!();
    }
    return null;
  };
  service.onSessionRevokedRequested = () {
    ref.read(unauthenticatedTriggerProvider.notifier).state++;
  };
  ref.onDispose(service.dispose);
  return service;
});

final socketConnectionStateProvider = StreamProvider<SocketConnectionState>((ref) {
  return ref.watch(socketServiceProvider).connectionStates;
});
