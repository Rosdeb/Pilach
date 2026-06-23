import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial()) {
    checkAuth();
  }

  static const _tokenKey = 'access_token';

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      state = AuthState.authenticated("user@example.com");
    } else {
      state = AuthState.unauthenticated();
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();
    await Future.delayed(const Duration(milliseconds: 1500)); // Mock network delay

    if (email.trim().isEmpty || password.isEmpty) {
      state = AuthState.error("Email and password cannot be empty");
      return false;
    }

    if (!email.contains('@')) {
      state = AuthState.error("Please enter a valid email address");
      return false;
    }

    // Save mock token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, "mock_token_123");

    state = AuthState.authenticated(email);
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    state = AuthState.loading();
    await Future.delayed(const Duration(milliseconds: 1500)); // Mock network delay

    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      state = AuthState.error("All fields are required");
      return false;
    }

    if (!email.contains('@')) {
      state = AuthState.error("Please enter a valid email address");
      return false;
    }

    if (password.length < 6) {
      state = AuthState.error("Password must be at least 6 characters long");
      return false;
    }

    // Save mock token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, "mock_token_123");

    state = AuthState.authenticated(email);
    return true;
  }

  Future<void> logout() async {
    state = AuthState.loading();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await Future.delayed(const Duration(milliseconds: 800));
    state = AuthState.unauthenticated();
  }
}
