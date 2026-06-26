import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/network/api_exceptions.dart';
import 'package:app/core/providers/api_provider.dart';
import 'package:app/core/services/api_service.dart';
import 'package:app/core/constants/api_constants.dart';
import '../models/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiServiceProvider));
});

class ProfileRepository {
  final ApiService _apiService;

  ProfileRepository(this._apiService);

  Future<ProfileModel> fetchProfile() async {
    final response = await _apiService.get(ApiConstants.getProfile);
    final data = response.data;
    if (data['success'] == true) {
      return ProfileModel.fromJson(data['data']);
    }
    throw ApiException(data['message'] ?? 'Failed to fetch profile');
  }

  Future<ProfileModel> updateProfile({
    required String name,
    required String? bio,
    required String? avatarUrl,
  }) async {
    final response = await _apiService.patch(
      ApiConstants.updateProfile,
      data: {
        'name': name,
        'bio': bio,
        'avatarUrl': avatarUrl,
      },
    );
    final data = response.data;
    if (data['success'] == true) {
      return ProfileModel.fromJson(data['data']);
    }
    throw ApiException(data['message'] ?? 'Failed to update profile');
  }

  Future<String> uploadAvatar(String filePath) async {
    final response = await _apiService.uploadFile(
      ApiConstants.uploadAvatar,
      filePath: filePath,
      fieldName: 'file',
    );
    final data = response.data;
    if (data['success'] == true) {
      // In the response example, data['data']['avatarUrl'] is returned
      final avatarUrl = data['data']['avatarUrl'] ?? data['data']['avatar'];
      if (avatarUrl != null) {
        return avatarUrl as String;
      }
    }
    throw ApiException(data['message'] ?? 'Failed to upload avatar');
  }
}
