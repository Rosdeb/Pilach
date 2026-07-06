import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';

final uploadServiceProvider = Provider<UploadService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return UploadService(apiService);
});

class UploadService {
  final ApiService _apiService;

  UploadService(this._apiService);

  /// Performs a presigned URL request and uploads the raw file binary directly to S3 storage.
  /// 
  /// 1. POST /api/v1/uploads/presign -> { "purpose": "MESSAGE_ATTACHMENT", "contentType": "image/jpeg" }
  /// 2. PUT to returned presigned `url` with raw file bytes and Content-Type header.
  /// 3. Returns a Map containing the `key` (Object Key), `contentType`, and `fileName`.
  Future<Map<String, String>> uploadMediaFile({
    required String filePath,
    String purpose = 'message',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist at path: $filePath');
    }

    // Backend validation requires purpose to be one of: 'story', 'sticker', 'message'
    String formattedPurpose = purpose.toLowerCase();
    if (formattedPurpose == 'message_attachment' || formattedPurpose == 'message') {
      formattedPurpose = 'message';
    } else if (formattedPurpose == 'story') {
      formattedPurpose = 'story';
    } else if (formattedPurpose == 'sticker') {
      formattedPurpose = 'sticker';
    } else {
      formattedPurpose = 'message';
    }

    final extension = filePath.split('.').last.toLowerCase();
    String contentType = 'image/jpeg';
    if (extension == 'png') {
      contentType = 'image/png';
    } else if (extension == 'gif') {
      contentType = 'image/gif';
    } else if (extension == 'webp') {
      contentType = 'image/webp';

    } else if (extension == 'mp4') {
      contentType = 'video/mp4';
    } else if (extension == 'pdf') {
      contentType = 'application/pdf';
    }

    final fileName = filePath.split('/').last.split('\\').last;

    Logger.log('📤 [Presign Request] Purpose: $formattedPurpose, ContentType: $contentType');

    // 1. Request Presigned Upload URL from server
    final response = await _apiService.post('/api/v1/uploads/presign', data: {
      'purpose': formattedPurpose,
      'contentType': contentType,
    });

    final resData = response.data;
    Logger.log('📥 [Presign Response Raw]: $resData');

    Map<String, dynamic> dataMap = {};
    if (resData is Map) {
      if (resData['data'] is Map) {
        dataMap = Map<String, dynamic>.from(resData['data'] as Map);
      } else {
        dataMap = Map<String, dynamic>.from(resData as Map);
      }
    }

    final String? uploadUrl = (dataMap['url'] ?? dataMap['uploadUrl'] ?? dataMap['presignedUrl'] ?? dataMap['signedUrl'] ?? (resData is Map ? resData['url'] : null))?.toString();
    final String? objectKey = (dataMap['key'] ?? dataMap['objectKey'] ?? dataMap['fileKey'] ?? dataMap['path'] ?? (resData is Map ? resData['key'] : null))?.toString();
    final String? publicUrl = (dataMap['publicUrl'] ?? (resData is Map ? resData['publicUrl'] : null))?.toString();

    if (uploadUrl == null || objectKey == null) {
      throw Exception('Presign response missing URL or Key. Raw response: $resData');
    }

    Logger.log('✅ Presigned URL received. Key: $objectKey. Uploading binary to S3...');

    // 2. Direct PUT request to S3 with raw binary file data
    final fileBytes = await file.readAsBytes();
    final s3Dio = Dio(); // Clean Dio instance without auth headers
    await s3Dio.put(
      uploadUrl,
      data: Stream.fromIterable([fileBytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': fileBytes.length,
        },
      ),
    );

    Logger.log('🚀 Direct S3 PUT Upload Succeeded! Key: $objectKey');

    return {
      'key': objectKey,
      'contentType': contentType,
      'fileName': fileName,
      'url': uploadUrl,
      'publicUrl': publicUrl ?? objectKey,
    };
  }

  /// Request temporary presigned download link for viewing private attachments
  Future<String?> getPresignedDownloadUrl(String objectKey) async {
    try {
      final response = await _apiService.get(
        '/api/v1/uploads/presign-download',
        queryParameters: {'key': objectKey},
      );
      final resData = response.data;
      if (resData is Map && resData['url'] != null) {
        return resData['url'] as String;
      } else if (resData is Map && resData['data'] is Map && resData['data']['url'] != null) {
        return resData['data']['url'] as String;
      }
    } catch (e) {
      Logger.log('Failed to fetch presigned download URL for key $objectKey: $e');
    }
    return null;
  }
}
