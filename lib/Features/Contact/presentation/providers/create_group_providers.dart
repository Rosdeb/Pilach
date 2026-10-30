import 'package:flutter_riverpod/legacy.dart';

class SelectedMembersNotifier extends StateNotifier<Set<String>> {
  SelectedMembersNotifier() : super({});

  void toggleMember(String id) {
    if (state.contains(id)) {
      state = state.where((element) => element != id).toSet();
    } else {
      state = {...state, id};
    }
  }

  void addMember(String id) {
    state = {...state, id};
  }

  void removeMember(String id) {
    state = state.where((element) => element != id).toSet();
  }

  void clear() {
    state = {};
  }
}

final selectedMembersProvider = StateNotifierProvider.autoDispose<SelectedMembersNotifier, Set<String>>((ref) {
  return SelectedMembersNotifier();
});
