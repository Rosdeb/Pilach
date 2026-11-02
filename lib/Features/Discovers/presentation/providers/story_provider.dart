import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/providers/api_provider.dart';
import 'package:app/core/constants/api_constants.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../models/story_model.dart';
import 'package:app/core/utils/app_logger.dart';
import 'package:app/Features/Contact/presentation/providers/contact_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserStoryGroup {
  final String userId;
  final String name;
  final String? avatarUrl;
  final List<StoryModel> stories;

  UserStoryGroup({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.stories,
  });

  StoryModel? get latestStory {
    if (stories.isEmpty) return null;
    return stories.reduce((a, b) {
      if (a.createdAt == null) return b;
      if (b.createdAt == null) return a;
      return a.createdAt!.isAfter(b.createdAt!) ? a : b;
    });
  }
}

/// Helper to extract list from direct List responses or { success: true, data: [...] } envelopes
List<dynamic> _extractStoryList(dynamic resData) {
  if (resData == null) return [];
  if (resData is List) return resData;
  if (resData is Map) {
    if (resData['data'] is List) return resData['data'] as List<dynamic>;
    if (resData['items'] is List) return resData['items'] as List<dynamic>;
    if (resData['stories'] is List) return resData['stories'] as List<dynamic>;
    if (resData['feed'] is List) return resData['feed'] as List<dynamic>;
    if (resData['results'] is List) return resData['results'] as List<dynamic>;
  }
  return [];
}

final myStoriesProvider =
    StateNotifierProvider<MyStoriesNotifier, AsyncValue<List<StoryModel>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return MyStoriesNotifier(apiService, ref);
});

class MyStoriesNotifier extends StateNotifier<AsyncValue<List<StoryModel>>> {
  final dynamic _apiService;
  final Ref _ref;

  MyStoriesNotifier(this._apiService, this._ref)
      : super(const AsyncValue.loading()) {
    fetchMyStories();
  }

  Future<void> fetchMyStories() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');

    // Fallback: if user_id is missing from SharedPreferences, fetch it directly from /api/v1/profile/me
    if (userId == null || userId.isEmpty) {
      Logger.log('⚠️ userId not in SharedPreferences. Fetching from /api/v1/profile/me...');
      try {
        final profileRes = await _apiService.get('/api/v1/profile/me');
        if (profileRes.data != null) {
          final pData = profileRes.data;
          final Map<String, dynamic>? data = pData is Map
              ? (pData['data'] is Map
                  ? pData['data'] as Map<String, dynamic>
                  : pData as Map<String, dynamic>)
              : null;
          userId = data?['userId'] ?? data?['id'];
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

      final List<dynamic> dataList = _extractStoryList(resData);
      final stories = dataList
          .whereType<Map<String, dynamic>>()
          .map((e) => StoryModel.fromJson(e))
          .toList();

      Logger.log('✅ Parsed ${stories.length} stories for user $userId.');
      state = AsyncValue.data(stories);
    } catch (e, st) {
      Logger.log('❌ Error fetching my stories: $e');
      state = AsyncValue.error(e, st);
    }
  }
}

final storyFeedProvider =
    StateNotifierProvider<StoryFeedNotifier, AsyncValue<List<UserStoryGroup>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return StoryFeedNotifier(apiService, ref);
});

class StoryFeedNotifier extends StateNotifier<AsyncValue<List<UserStoryGroup>>> {
  final dynamic _apiService;
  final Ref _ref;

  StoryFeedNotifier(this._apiService, this._ref)
      : super(const AsyncValue.loading()) {
    fetchStoriesFeed();
  }

  Future<void> fetchStoriesFeed() async {
    state = const AsyncValue.loading();
    try {
      Logger.log('🚀 Fetching stories feed from API: ${ApiConstants.storiesFeed}');
      final response = await _apiService.get(
        ApiConstants.storiesFeed,
        queryParameters: {'limit': 150},
      );
      final resData = response.data;
      Logger.log('📥 Stories Feed API Response: $resData');

      final List<dynamic> dataList = _extractStoryList(resData);
      final List<UserStoryGroup> groups = [];

      final contacts = _ref.read(masterContactsProvider);
      final contactsMap = {for (var c in contacts) c.id: c};

      for (final item in dataList) {
        if (item is! Map<String, dynamic>) continue;

        // Format 1: Grouped stories { user: {...}, stories: [...] }
        if (item.containsKey('stories') && item['stories'] is List) {
          final authorMap = item['author'] is Map<String, dynamic>
              ? item['author'] as Map<String, dynamic>
              : (item['user'] is Map<String, dynamic>
                  ? item['user'] as Map<String, dynamic>
                  : null);
          final profileMap = authorMap?['profile'] is Map<String, dynamic>
              ? authorMap!['profile'] as Map<String, dynamic>
              : null;
          final userId =
              (item['userId'] ?? item['id'] ?? authorMap?['id'] ?? '').toString();
          final contact = contactsMap[userId];
          final name = profileMap?['name'] ??
              authorMap?['name'] ??
              authorMap?['username'] ??
              contact?.name ??
              item['name'] ??
              'User';
          final avatarUrl = profileMap?['avatarUrl'] ??
              authorMap?['avatarUrl'] ??
              authorMap?['image'] ??
              contact?.avatarUrl ??
              item['avatarUrl'];

          final storyList = (item['stories'] as List)
              .whereType<Map<String, dynamic>>()
              .map((s) => StoryModel.fromJson({
                    ...s,
                    if (!s.containsKey('author') && authorMap != null)
                      'author': authorMap,
                    if (!s.containsKey('authorName') && name != 'User')
                      'authorName': name,
                    if (!s.containsKey('authorAvatar') && avatarUrl != null)
                      'authorAvatar': avatarUrl,
                  }))
              .toList();

          if (storyList.isNotEmpty) {
            final existingIndex = groups.indexWhere((g) => g.userId == userId);
            if (existingIndex != -1) {
              groups[existingIndex].stories.addAll(storyList);
            } else {
              groups.add(UserStoryGroup(
                userId: userId,
                name: name,
                avatarUrl: avatarUrl,
                stories: storyList,
              ));
            }
          }
        }
        // Format 2: Flat list of stories (Swagger schema: [ { id, authorId, mediaUrl, author: { ... }, ... } ])
        else {
          final story = StoryModel.fromJson(item);
          final contact = contactsMap[story.authorId];
          final name = (story.authorName != null &&
                  story.authorName!.trim().isNotEmpty)
              ? story.authorName!
              : (contact?.name ?? 'User');
          final avatarUrl = (story.authorAvatar != null &&
                  story.authorAvatar!.trim().isNotEmpty)
              ? story.authorAvatar
              : contact?.avatarUrl;

          final existingIndex =
              groups.indexWhere((g) => g.userId == story.authorId);
          if (existingIndex != -1) {
            groups[existingIndex].stories.add(story);
          } else {
            groups.add(UserStoryGroup(
              userId: story.authorId,
              name: name,
              avatarUrl: avatarUrl,
              stories: [story],
            ));
          }
        }
      }

      Logger.log('✅ Parsed ${groups.length} story groups from stories feed.');
      state = AsyncValue.data(groups);
    } catch (e, st) {
      Logger.log('❌ Error fetching stories feed: $e');
      state = AsyncValue.error(e, st);
    }
  }
}
