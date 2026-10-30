import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/api_service.dart';

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository(ref.watch(apiServiceProvider));
});

class SecurityRepository {
  SecurityRepository(this._apiService);

  final ApiService _apiService;

  Future<List<Map<String, dynamic>>> getSessions({
    bool includeRevoked = false,
    int limit = 150,
  }) async {
    final response = await _apiService.get(
      ApiConstants.authSessions,
      queryParameters: {
        'includeRevoked': includeRevoked,
        'limit': limit,
      },
    );
    return _listData(response.data);
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final response = await _apiService.get('${ApiConstants.authSessions}/$sessionId');
    return _mapData(response.data);
  }

  Future<void> revokeSession(String sessionId) async {
    await _apiService.delete('${ApiConstants.authSessions}/$sessionId');
  }

  Future<void> revokeOtherSessions() async {
    await _apiService.post(ApiConstants.authSessionsRevokeOthers);
  }

  Future<Map<String, dynamic>> makePrimary(String sessionId) async {
    final response = await _apiService.patch(
      '${ApiConstants.authSessions}/$sessionId/primary',
    );
    return _mapData(response.data);
  }

  Future<List<Map<String, dynamic>>> getPrivacySettings() async {
    final response = await _apiService.get(ApiConstants.privacy);
    return _listData(response.data);
  }

  Future<Map<String, dynamic>> updatePrivacySetting({
    required String scope,
    required String level,
    List<String> allowUserIds = const [],
    List<String> denyUserIds = const [],
  }) async {
    final response = await _apiService.put(
      '${ApiConstants.privacy}/${scope.toUpperCase()}',
      data: {
        'level': level.toUpperCase(),
        if (allowUserIds.isNotEmpty) 'allowUserIds': allowUserIds,
        if (denyUserIds.isNotEmpty) 'denyUserIds': denyUserIds,
      },
    );
    return _mapData(response.data);
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers({int limit = 150}) async {
    final response = await _apiService.get(
      ApiConstants.blocks,
      queryParameters: {'limit': limit},
    );
    return _listData(response.data);
  }

  Future<void> blockUser(String userId) async {
    await _apiService.post(ApiConstants.blocks, data: {'userId': userId});
  }

  Future<void> unblockUser(String userId) async {
    await _apiService.delete('${ApiConstants.blocks}/$userId');
  }

  Future<bool> isBlockedByMe(String userId) async {
    final response = await _apiService.get('${ApiConstants.blocks}/$userId/status');
    return _mapData(response.data)['blockedByMe'] == true;
  }

  static Map<String, dynamic> _mapData(dynamic responseData) {
    if (responseData is! Map) return const {};
    final envelope = Map<String, dynamic>.from(responseData);
    final data = envelope['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return envelope;
  }

  static List<Map<String, dynamic>> _listData(dynamic responseData) {
    if (responseData is! Map) return const [];
    final data = responseData['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
