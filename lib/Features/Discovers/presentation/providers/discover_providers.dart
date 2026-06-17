import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// Simple state provider to toggle the radar scanning animation
class DiscoverState {
  final bool isScanning;
  DiscoverState({this.isScanning = true});

  DiscoverState copyWith({bool? isScanning}) {
    return DiscoverState(isScanning: isScanning ?? this.isScanning);
  }
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  DiscoverNotifier() : super(DiscoverState());

  void toggleScan() {
    state = state.copyWith(isScanning: !state.isScanning);
  }
}

final discoverProvider = StateNotifierProvider<DiscoverNotifier, DiscoverState>((ref) {
  return DiscoverNotifier();
});