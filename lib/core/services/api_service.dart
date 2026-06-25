import 'package:dio/dio.dart';
import 'package:app/core/network/api_exceptions.dart';

import '../constants/api_constants.dart';

class ApiService {
  final Dio _dio;

  ApiService(this._dio);

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
      throw ApiException.fromDioError(e);
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
      throw ApiException.fromDioError(e);
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
      throw ApiException.fromDioError(e);
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
      throw ApiException.fromDioError(e);
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
      throw ApiException.fromDioError(e);
    }
  }


}