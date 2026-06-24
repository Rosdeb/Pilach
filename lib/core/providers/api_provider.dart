
import 'package:dio/dio.dart';
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
      },
    ),
  );

  // 1. Attach Auth Interceptor
  dio.interceptors.add(AuthInterceptor(prefs, dio, onUnauthenticated: () {
    // Push the state to unauthenticated explicitly if tokens are invalid
    ref.read(unauthenticatedTriggerProvider.notifier).state++;
  }));

  // 2. Attach Logger Interceptor (Only in debug mode to keep production fast!)
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
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