import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/providers/api_provider.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../models/story_model.dart';
import 'package:app/core/utils/app_logger.dart';
import 'package:app/Features/Me/presentation/providers/profile_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

final myStoriesProvider = StateNotifierProvider<MyStoriesNotifier, AsyncValue<List<StoryModel>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return MyStoriesNotifier(apiService, ref);
});

class MyStoriesNotifier extends StateNotifier<AsyncValue<List<StoryModel>>> {
  final dynamic _apiService;
  final Ref _ref;

  MyStoriesNotifier(this._apiService, this._ref) : super(const AsyncValue.loading()) {
    fetchMyStories();
  }

  Future<void> fetchMyStories() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');

    // Foolproof fallback: if user_id is missing from SharedPreferences, fetch it directly from the backend
    if (userId == null || userId.isEmpty) {
      Logger.log('⚠️ userId not in SharedPreferences. Fetching from /api/v1/profile/me...');
      try {
        final profileRes = await _apiService.get('/api/v1/profile/me');
        if (profileRes.data != null && profileRes.data['success'] == true) {
          final data = profileRes.data['data'];
          userId = data['userId'] ?? data['id'];
          // Save it back for next time
          if (userId != null) await prefs.setString('user_id', userId);
        }
      } catch (e) {
        Logger.log('❌ Failed to fetch profile fallback: $e');
      }
    }

    Logger.log('🚀 fetchMyStories proceeding with userId: $userId');
    if (userId == null || userId.isEmpty) {
      Logger.log('⚠️ userId is still null after fallback. Cannot fetch stories.');
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      Logger.log('🚀 Fetching my stories from API: /api/v1/stories/users/$userId');
      final response = await _apiService.get('/api/v1/stories/users/$userId');
      final resData = response.data;
      Logger.log('📥 My Stories API Response: $resData');
      
      if (resData != null && resData['success'] == true) {
        final List<dynamic> dataList = resData['data'] ?? [];
        final stories = dataList.map((e) => StoryModel.fromJson(e)).toList();
        state = AsyncValue.data(stories);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      Logger.log('Error fetching my stories: $e');
      state = AsyncValue.error(e, st);
    }
  }
}
