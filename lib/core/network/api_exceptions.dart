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
    return ApiException(
      "Received invalid status code: ${response?.statusCode}",
      statusCode: response?.statusCode,
    );
  }

  @override
  String toString() => message;
}