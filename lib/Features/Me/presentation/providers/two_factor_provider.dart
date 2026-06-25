import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app/Features/auth/data/repositories/auth_repository.dart';
import 'package:app/core/network/api_exceptions.dart';
import 'security_privacy_providers.dart';

class TwoFactorState {
  final List<dynamic> enrolledMethods;
  final bool isLoading;
  final String? errorMessage;
  final bool isCodeSent;
  final bool hasLoaded;

  TwoFactorState({
    required this.enrolledMethods,
    this.isLoading = false,
    this.errorMessage,
    this.isCodeSent = false,
    this.hasLoaded = false,
  });

  factory TwoFactorState.initial() => TwoFactorState(enrolledMethods: [], hasLoaded: false);

  TwoFactorState copyWith({
    List<dynamic>? enrolledMethods,
    bool? isLoading,
    String? errorMessage,
    bool? isCodeSent,
    bool? hasLoaded,
  }) {
    return TwoFactorState(
      enrolledMethods: enrolledMethods ?? this.enrolledMethods,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isCodeSent: isCodeSent ?? this.isCodeSent,
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}

class TwoFactorNotifier extends StateNotifier<TwoFactorState> {
  final AuthRepository _authRepository;
  final Ref _ref;

  TwoFactorNotifier(this._authRepository, this._ref) : super(TwoFactorState.initial()) {
    loadMethods();
  }

  Future<void> loadMethods({bool forceRefresh = false}) async {
    if (state.hasLoaded && !forceRefresh) return;
    state = state.copyWith(isLoading: true);
    try {
      final methods = await _authRepository.fetchTwoFactorMethods();
      state = state.copyWith(enrolledMethods: methods, isLoading: false, hasLoaded: true);
      // Synchronize with twoFactorProvider in security_privacy_providers
      final hasActive2Fa = methods.any((m) => m is Map && m['isEnabled'] == true);
      _ref.read(twoFactorProvider.notifier).state = hasActive2Fa;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    } catch (_) {
      state = state.copyWith(errorMessage: "Failed to load methods", isLoading: false);
    }
  }

  Future<bool> requestEmailEnrollment(String email) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.enrollEmailRequest(email);
      state = state.copyWith(isLoading: false, isCodeSent: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: "Failed to request email 2FA", isLoading: false);
      return false;
    }
  }

  Future<bool> confirmEmailEnrollment(String code) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.enrollEmailConfirm(code);
      state = state.copyWith(isLoading: false, isCodeSent: false);
      await loadMethods(forceRefresh: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: "Failed to confirm email 2FA", isLoading: false);
      return false;
    }
  }

  Future<bool> requestSmsEnrollment(String phone) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.enrollSmsRequest(phone);
      state = state.copyWith(isLoading: false, isCodeSent: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: "Failed to request SMS 2FA", isLoading: false);
      return false;
    }
  }

  Future<bool> confirmSmsEnrollment(String code) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.enrollSmsConfirm(code);
      state = state.copyWith(isLoading: false, isCodeSent: false);
      await loadMethods(forceRefresh: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: "Failed to confirm SMS 2FA", isLoading: false);
      return false;
    }
  }

  Future<bool> disableMethod(String methodId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.disableTwoFactorMethod(methodId);
      state = state.copyWith(isLoading: false);
      await loadMethods(forceRefresh: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: "Failed to disable 2FA method", isLoading: false);
      return false;
    }
  }
}

final twoFactorNotifierProvider = StateNotifierProvider<TwoFactorNotifier, TwoFactorState>((ref) {
  return TwoFactorNotifier(ref.watch(authRepositoryProvider), ref);
});
