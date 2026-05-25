import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void clear() {
    state = {};
  }
}

final selectedMembersProvider = StateNotifierProvider<SelectedMembersNotifier, Set<String>>((ref) {
  return SelectedMembersNotifier();
});