import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/block_userlist.dart';

class BlockedUsersNotifier extends StateNotifier<List<BlockedUser>> {
  BlockedUsersNotifier() : super([
    BlockedUser(id: '1', name: 'John Doe', email: 'john.doe@pilach.com', avatarUrl: 'https://i.pravatar.cc/150?img=33'),
    BlockedUser(id: '2', name: 'Sarah Jenkins', email: 'sarah.j@brand.com', avatarUrl: 'https://i.pravatar.cc/150?img=49'),
    BlockedUser(id: '3', name: 'Michael Scott', email: 'michael.s@paper.com', avatarUrl: 'https://i.pravatar.cc/150?img=12'),
  ]);

  void unblockUser(String id) {
    state = state.where((user) => user.id != id).toList();
  }
}

final searchbarProvider = StateProvider<String>((ref) => '');

final blockedUsersProvider = StateNotifierProvider<BlockedUsersNotifier, List<BlockedUser>>((ref) {
  return BlockedUsersNotifier();
});