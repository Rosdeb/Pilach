import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';

final splashProvider = StateNotifierProvider<SplashNotifier, Color>(
  (ref) => SplashNotifier(),
);

class SplashNotifier extends StateNotifier<Color> {
  SplashNotifier() : super(Colors.yellow);

  final List<Color> colors = [Colors.yellow, Colors.blue, Colors.green];

  int index = 0;
  Timer? _timer;

  void startAnimation(BuildContext context) {
    if (_timer?.isActive ?? false) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      index = (index + 1) % colors.length;
      state = colors[index];

      if (timer.tick >= 2) {
        timer.cancel();

        if (context.mounted) {
          context.go(AppPaths.bottom_manu);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
