import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:messageapp/core/network/api_exceptions.dart';
import '../../../../core/providers/api_provider.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.email,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(String email) => AuthState(status: AuthStatus.authenticated, email: email);
  factory AuthState.unauthenticated() => AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.error(String message) => AuthState(status: AuthStatus.error, errorMessage: message);

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.watch(authRepositoryProvider));
  
  ref.listen<int>(unauthenticatedTriggerProvider, (previous, next) {
    if (next > 0) {
      notifier.logout();
    }
  });

  return notifier;
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  
  AuthNotifier(this._authRepository) : super(AuthState.initial()) {
    checkAuth();
  }

  static const _tokenKey = 'auth_token';

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      state = AuthState.authenticated("user");
    } else {
      state = AuthState.unauthenticated();
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    state = AuthState.loading();

    try {
      final result = await _authRepository.login(email, password);
      if (result['is2faRequired'] == true) {
        state = AuthState.unauthenticated();
        return result;
      }
      final userData = result['user'];
      state = AuthState.authenticated(userData?['email'] ?? email);
      return result;
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
      return null;
    } catch (e) {
      state = AuthState.error("Something went wrong");
      return null;
    }
  }

  void setAuthenticated(String email) {
    state = AuthState.authenticated(email);
  }

  Future<bool> register(String name, String email, String password) async {
    state = AuthState.loading();

    try {
      await _authRepository.register(name, email, password);
      state = AuthState.unauthenticated();
      return true;
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
      return false;
    } catch (e) {
      state = AuthState.error("Something went wrong");
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String code) async {
    state = AuthState.loading();
    try {
      await _authRepository.verifyEmailOtp(email, code);
      state = AuthState.unauthenticated(); // Ready to login
      return true;
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
      return false;
    } catch (e) {
      state = AuthState.error("Something went wrong");
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    try {
      await _authRepository.logout();
    } catch (_) {
      // Ignore API errors, we still want to log out locally
    }
    state = AuthState.unauthenticated();
  }
}
