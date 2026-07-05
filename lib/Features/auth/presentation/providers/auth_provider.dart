import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/network/api_exceptions.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? id;
  final String? email;
  final String? name;
  final String? profileImage;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.id,
    this.email,
    this.name,
    this.profileImage,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(String email, {String? id, String? name, String? profileImage}) => 
      AuthState(status: AuthStatus.authenticated, id: id, email: email, name: name, profileImage: profileImage);
  factory AuthState.unauthenticated() => AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.error(String message) => AuthState(status: AuthStatus.error, errorMessage: message);

  AuthState copyWith({
    AuthStatus? status,
    String? id,
    String? email,
    String? name,
    String? profileImage,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImage: profileImage ?? this.profileImage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(notificationServiceProvider),
    ref.watch(socketServiceProvider),
  );
  
  ref.listen<int>(unauthenticatedTriggerProvider, (previous, next) {
    if (next > 0) {
      notifier.logout();
    }
  });

  return notifier;
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final NotificationService _notificationService;
  final SocketService _socketService;
  
  AuthNotifier(this._authRepository, this._notificationService, this._socketService) : super(AuthState.initial()) {
    checkAuth();
  }

  static const _tokenKey = 'auth_token';

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      String? id = prefs.getString('user_id');
      
      // Fallback: Extract ID from JWT if it was not saved correctly
      if (id == null && token.split('.').length == 3) {
        try {
          final payloadStr = token.split('.')[1];
          final normalized = base64Url.normalize(payloadStr);
          final decodedBytes = base64Url.decode(normalized);
          final payload = jsonDecode(utf8.decode(decodedBytes));
          final rawId = payload['id'] ?? payload['_id'] ?? payload['userId'] ?? payload['sub'];
          id = rawId?.toString();
          if (id != null) {
             await prefs.setString('user_id', id);
          }
        } catch (_) {}
      }

      final email = prefs.getString('auth_email') ?? "user";
      final name = prefs.getString('auth_name');
      final profileImage = prefs.getString('auth_profile_image');
      state = AuthState.authenticated(email, id: id, name: name, profileImage: profileImage);
      _notificationService.registerFcmToken();
      _socketService.connect(token);
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
      final resolvedEmail = userData?['email'] ?? email;
      final rawId = userData?['id'] ?? userData?['_id'];
      final id = rawId?.toString();
      final name = userData?['name'];
      final profileImage = userData?['profilePicture'] ?? userData?['avatar'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_email', resolvedEmail);
      if (id != null) await prefs.setString('user_id', id);
      if (name != null) await prefs.setString('auth_name', name);
      if (profileImage != null) await prefs.setString('auth_profile_image', profileImage);
      
      // We assume the token was saved by AuthRepository. Let's get it to connect socket.
      final token = prefs.getString(_tokenKey) ?? result['token'] ?? '';
      
      state = AuthState.authenticated(resolvedEmail, id: id, name: name, profileImage: profileImage);
      _notificationService.registerFcmToken();
      if (token.isNotEmpty) _socketService.connect(token);
      return result;
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
      return null;
    } catch (e) {
      state = AuthState.error("Something went wrong");
      return null;
    }
  }

  Future<void> setAuthenticated(String email, {String? id, String? name, String? profileImage}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_email', email);
    if (id != null) await prefs.setString('user_id', id);
    if (name != null) await prefs.setString('auth_name', name);
    if (profileImage != null) await prefs.setString('auth_profile_image', profileImage);
    state = AuthState.authenticated(email, id: id, name: name, profileImage: profileImage);
    _notificationService.registerFcmToken();
    
    final token = prefs.getString(_tokenKey);
    if (token != null) _socketService.connect(token);
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
    _socketService.disconnect();
    await _notificationService.deleteFcmToken();
    try {
      await _authRepository.logout();
    } catch (_) {
      // Ignore API errors, we still want to log out locally
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('auth_email');
    await prefs.remove('auth_name');
    await prefs.remove('auth_profile_image');
    state = AuthState.unauthenticated();
  }
}
