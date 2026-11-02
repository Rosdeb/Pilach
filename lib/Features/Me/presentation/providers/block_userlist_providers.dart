import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app/core/utils/app_logger.dart';

import '../../data/models/block_userlist.dart';
import '../../data/repositories/security_repository.dart';

final searchbarProvider = StateProvider<String>((ref) => '');

final blockedUsersProvider =
    StateNotifierProvider<BlockedUsersNotifier, AsyncValue<List<BlockedUser>>>((ref) {
  final repo = ref.watch(securityRepositoryProvider);
  return BlockedUsersNotifier(repo);
});

final filteredBlockedUsersProvider = Provider<List<BlockedUser>>((ref) {
  final blockedState = ref.watch(blockedUsersProvider);
  final users = blockedState.value ?? [];
  final query = ref.watch(searchbarProvider).trim().toLowerCase();

  if (query.isEmpty) return users;

  return users.where((user) {
    final name = (user.name ?? '').toLowerCase();
    final username = (user.username ?? '').toLowerCase();
    final id = user.id.toLowerCase();
    return name.contains(query) || username.contains(query) || id.contains(query);
  }).toList();
});

class BlockedUsersNotifier extends StateNotifier<AsyncValue<List<BlockedUser>>> {
  final SecurityRepository _repo;

  BlockedUsersNotifier(this._repo) : super(const AsyncValue.loading()) {
    fetchBlockedUsers();
  }

  Future<void> fetchBlockedUsers() async {
    state = const AsyncValue.loading();
    try {
      Logger.log('🚀 Fetching blocked users from /api/v1/blocks...');
      final rawList = await _repo.getBlockedUsers(limit: 150);
      final users = rawList.map((e) => BlockedUser.fromJson(e)).toList();
      Logger.log('📥 Blocked users fetched successfully: ${users.length} users');
      state = AsyncValue.data(users);
    } catch (e, st) {
      Logger.log('❌ Error fetching blocked users: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> unblockUser(String userId) async {
    final currentList = state.value ?? [];
    // Optimistic removal
    state = AsyncValue.data(currentList.where((u) => u.id != userId).toList());

    try {
      Logger.log('🚀 Unblocking user $userId via DELETE /api/v1/blocks/$userId');
      await _repo.unblockUser(userId);
      Logger.log('✅ User $userId unblocked successfully');
      return true;
    } catch (e) {
      Logger.log('❌ Failed to unblock user $userId: $e');
      // Revert state on failure
      state = AsyncValue.data(currentList);
      return false;
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      Logger.log('🚀 Blocking user $userId via POST /api/v1/blocks');
      await _repo.blockUser(userId);
      Logger.log('✅ User $userId blocked successfully');
      await fetchBlockedUsers();
      return true;
    } catch (e) {
      Logger.log('❌ Failed to block user $userId: $e');
      return false;
    }
  }
}