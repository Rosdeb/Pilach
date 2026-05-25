import 'package:flutter_riverpod/legacy.dart';

final bottomNavProvider = StateNotifierProvider<BottomNavNotifier, int>(
  (ref) => BottomNavNotifier(),
);

class BottomNavNotifier extends StateNotifier<int> {
  BottomNavNotifier() : super(0);

  void changeIndex(int index) {
    state = index;
  }
}
