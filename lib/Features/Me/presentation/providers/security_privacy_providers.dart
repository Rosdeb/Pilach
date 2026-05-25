import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// Providers to handle security switch states
final biometricProvider = StateProvider<bool>((ref) => true);
final twoFactorProvider = StateProvider<bool>((ref) => false);