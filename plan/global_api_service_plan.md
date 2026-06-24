# Global API Service Architecture Plan (Dio + Riverpod)

This plan outlines a scalable, production-ready Global API Service using `dio` and `flutter_riverpod`. It improves upon the existing `ApiService` by separating concerns into dedicated interceptors, proper custom exception handling, and dependency injection.

## Proposed Folder Structure
```text
lib/
 └── core/
      ├── network/
      │    ├── api_constants.dart      # (Existing) Base URLs, timeouts
      │    ├── api_exceptions.dart     # Custom error handling
      │    ├── auth_interceptor.dart   # Injects Bearer tokens securely
      │    └── api_service.dart        # Main Dio wrapper (Refactored)
      └── providers/
           └── api_provider.dart       # Riverpod providers for the ApiService
```

## 1. Custom Exceptions (`lib/core/network/api_exceptions.dart`)
Wraps Dio errors into safe, human-readable strings.

```dart
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  factory ApiException.fromDioError(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.cancel:
        return ApiException("Request to API server was cancelled");
      case DioExceptionType.connectionTimeout:
        return ApiException("Connection timeout with API server");
      case DioExceptionType.receiveTimeout:
        return ApiException("Receive timeout in connection with API server");
      case DioExceptionType.badResponse:
        return ApiException.fromResponse(dioError.response);
      case DioExceptionType.connectionError:
        return ApiException("No Internet Connection");
      default:
        return ApiException("Something went wrong");
    }
  }

  factory ApiException.fromResponse(Response? response) {
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('message')) {
        return ApiException(data['message'], statusCode: response.statusCode);
      }
    }
    return ApiException("Received invalid status code: ${response?.statusCode}", statusCode: response?.statusCode);
  }

  @override
  String toString() => message;
}
```

## 2. Auth Interceptor (`lib/core/network/auth_interceptor.dart`)
Injects tokens automatically to every request. Connect this to your Shared Preferences.

```dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
  final SharedPreferences prefs;

  AuthInterceptor(this.prefs);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = prefs.getString('auth_token'); // Fetch your saved token
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }
}
```

## 3. Global API Service (`lib/core/network/api_service.dart`)
Refactored from your original code to be cleaner and strictly throw the new exceptions.

```dart
import 'package:dio/dio.dart';
import 'api_exceptions.dart';

class ApiService {
  final Dio _dio;

  ApiService(this._dio);

  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(endpoint, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await _dio.put(endpoint, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Response> delete(String endpoint, {dynamic data}) async {
    try {
      return await _dio.delete(endpoint, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Response> uploadFile(String endpoint, {required String filePath, required String fieldName, Map<String, dynamic>? extraData}) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        if (extraData != null) ...extraData,
      });
      return await _dio.post(endpoint, data: formData);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
```

## 4. Riverpod Provider Setup (`lib/core/providers/api_provider.dart`)
This connects everything together. Use this provider globally to inject the API service anywhere in your app.

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_service.dart';
import '../network/auth_interceptor.dart';
import '../constants/api_constants.dart';

// Assuming you have a SharedPreferences provider (like in theme_provider.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Override in ProviderScope in main.dart
});

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

  // Add Auth Interceptor
  dio.interceptors.add(AuthInterceptor(prefs));

  // Add Logging Interceptor (Only runs in debug mode to keep production fast!)
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

final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});
```

### How to use in your Repositories:
```dart
try {
  // Usage is extremely clean now!
  final response = await ref.read(apiServiceProvider).get('/endpoint');
  print(response.data);
} on ApiException catch (e) {
  // Gracefully show error message in UI
  print(e.message);
}
```
