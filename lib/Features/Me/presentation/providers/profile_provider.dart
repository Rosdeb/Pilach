import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileModel?>> {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.fetchProfile();
      state = AsyncValue.data(profile);
      
      // Update AuthProvider
      final auth = _ref.read(authProvider);
      await _ref.read(authProvider.notifier).setAuthenticated(
        auth.email ?? "user",
        id: profile.userId,
        name: profile.name,
        profileImage: profile.avatarUrl,
      );
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String? bio,
    required String? avatarUrl,
  }) async {
    final updatedProfile = await _repository.updateProfile(
      name: name,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    state = AsyncValue.data(updatedProfile);

    // Update AuthProvider
    final auth = _ref.read(authProvider);
    await _ref.read(authProvider.notifier).setAuthenticated(
      auth.email ?? "user",
      id: updatedProfile.userId,
      name: updatedProfile.name,
      profileImage: updatedProfile.avatarUrl,
    );
    return true;
  }

  Future<String?> uploadAvatar(String filePath) async {
    final avatarUrl = await _repository.uploadAvatar(filePath);
    // If we already have profile data, update it with new avatarUrl
    final currentProfile = state.value;
    if (currentProfile != null) {
      final updatedProfile = currentProfile.copyWith(avatarUrl: avatarUrl);
      state = AsyncValue.data(updatedProfile);

      // Also update backend profile with new avatarUrl to persist it
      await _repository.updateProfile(
        name: updatedProfile.name,
        bio: updatedProfile.bio,
        avatarUrl: avatarUrl,
      );

      // Update AuthProvider
      final auth = _ref.read(authProvider);
      await _ref.read(authProvider.notifier).setAuthenticated(
        auth.email ?? "user",
        id: updatedProfile.userId,
        name: updatedProfile.name,
        profileImage: avatarUrl,
      );
    }
    return avatarUrl;
  }
}

final profileNotifierProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileModel?>>((ref) {
  return ProfileNotifier(
    ref.watch(profileRepositoryProvider),
    ref,
  );
});
