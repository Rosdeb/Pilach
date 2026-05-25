import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

class ApiService {
  final Dio _dio;

  ApiService() : _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(
        milliseconds: ApiConstants.connectTimeout,
      ),
      receiveTimeout: const Duration(
        milliseconds: ApiConstants.receiveTimeout,
      ),
      headers: {
        'Content-Type': ApiConstants.contentType,
        'Accept': ApiConstants.contentType,
      },
    ),
  ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Token later add korba
          // options.headers['Authorization'] = 'Bearer $token';
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
      String endpoint, {
        Map<String, dynamic>? queryParameters,
      }) async {
    try {
      return await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
      String endpoint, {
        dynamic data,
      }) async {
    try {
      return await _dio.post(
        endpoint,
        data: data,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(
      String endpoint, {
        dynamic data,
      }) async {
    try {
      return await _dio.put(
        endpoint,
        data: data,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(
      String endpoint, {
        dynamic data,
      }) async {
    try {
      return await _dio.delete(
        endpoint,
        data: data,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> uploadFile(
      String endpoint, {
        required String filePath,
        required String fieldName,
        Map<String, dynamic>? extraData,
      }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        if (extraData != null) ...extraData,
      });

      return await _dio.post(
        endpoint,
        data: formData,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      return error.response?.data['message'] ?? 'Something went wrong';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.badResponse:
        return 'Bad response from server';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      default:
        return 'No internet connection';
    }
  }
}