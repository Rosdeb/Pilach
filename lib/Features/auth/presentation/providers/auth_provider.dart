import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app/core/network/api_exceptions.dart';
import 'package:app/core/utils/app_logger.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/storage_service.dart';
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
    ref.watch(authStorageProvider),
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
  final LocalAuthStorageService _storage;
  
  AuthNotifier(this._authRepository, this._notificationService, this._socketService, this._storage) : super(AuthState.initial()) {
    checkAuth();
  }

  void checkAuth() {
    final token = _storage.token;
    if (token != null) {
      String? id = _storage.userId;
      
      // Fallback: Extract ID from JWT if it was not saved correctly
      if (id == null && token.split('.').length == 3) {
        try {
          final payloadStr = token.split('.')[1];
          final normalized = base64Url.normalize(payloadStr);
          final decodedBytes = base64Url.decode(normalized);
          final payload = jsonDecode(utf8.decode(decodedBytes));
          final rawId = payload['id'] ?? payload['_id'] ?? payload['userId'] ?? (payload['sub']?.toString().contains('@') == false ? payload['sub'] : null);
          id = rawId?.toString();
          if (id != null && !id.contains('@')) {
             _storage.setUserId(id);
          } else {
             id = null;
          }
        } catch (_) {}
      }

      final email = _storage.email ?? "user";
      final name = _storage.name;
      final profileImage = _storage.profileImage;
      state = AuthState.authenticated(email, id: id, name: name, profileImage: profileImage);
      _notificationService.registerFcmToken();
      _socketService.connect(token);

      if (id == null || id.isEmpty || id.contains('@')) {
        unawaited(_fetchProfileAndSetUserId());
      }
    } else {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> _fetchProfileAndSetUserId() async {
    try {
      final res = await _authRepository.getProfileMe();
      if (res != null && res['data'] is Map) {
        final profileData = res['data'] as Map;
        final resolvedId = (profileData['userId'] ?? profileData['id'] ?? profileData['_id'])?.toString();
        if (resolvedId != null && resolvedId.isNotEmpty && !resolvedId.contains('@')) {
          await _storage.setUserId(resolvedId);
          state = state.copyWith(id: resolvedId);
          Logger.log('✅ Resolved and cached user ID from profile/me: $resolvedId', type: 'auth');
        }
      }
    } catch (e) {
      Logger.log('Failed to fetch profile in checkAuth: $e');
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

      // Compare against lastLoggedInUserId — this key survives logout()
      // so we can detect a user-switch even after _storage.clearAll().
      //
      // Decision table:
      //   same user logs back in  → keep DB cache (instant load, no re-fetch)
      //   different user logs in  → wipe DB so their data never bleeds
      //   first ever login        → nothing to wipe
      final lastUserId = _storage.lastLoggedInUserId;
      final isDifferentUser = lastUserId != null && id != null && lastUserId != id;

      if (isDifferentUser) {
        Logger.log(
          'login() — user switched ($lastUserId → $id), wiping local DB cache',
          type: 'lifecycle',
        );
        await AppDatabase.instance.clearAllUserData();
      } else if (lastUserId != null && lastUserId == id) {
        Logger.log(
          'login() — same user ($id) logging back in, local DB cache preserved ✓',
          type: 'lifecycle',
        );
      }

      await _storage.setEmail(resolvedEmail);
      if (id != null) await _storage.setUserId(id); // also updates lastLoggedInUserId
      if (name != null) await _storage.setName(name);
      if (profileImage != null) await _storage.setProfileImage(profileImage);

      final token = _storage.token ?? result['token'] ?? '';

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
    await _storage.setEmail(email);
    if (id != null) await _storage.setUserId(id);
    if (name != null) await _storage.setName(name);
    if (profileImage != null) await _storage.setProfileImage(profileImage);
    state = AuthState.authenticated(email, id: id, name: name, profileImage: profileImage);
    _notificationService.registerFcmToken();
    
    final token = _storage.token;
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

  Future<bool> forgotPassword(String email) async {
    state = AuthState.loading();
    try {
      await _authRepository.forgotPassword(email);
      state = AuthState.unauthenticated();
      return true;
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
      return false;
    } catch (e) {
      state = AuthState.error("Failed to send reset link");
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    state = AuthState.loading();
    try {
      await _authRepository.resetPassword(token, newPassword);
      state = AuthState.unauthenticated();
      return true;
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
      return false;
    } catch (e) {
      state = AuthState.error("Failed to reset password");
      return false;
    }
  }

  Future<bool> resendEmailVerification(String email) async {
    state = AuthState.loading();
    try {
      await _authRepository.resendEmailVerification(email);
      state = AuthState.unauthenticated();
      return true;
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
      return false;
    } catch (e) {
      state = AuthState.error("Failed to resend verification");
      return false;
    }
  }

  Future<bool> resetPasswordByOtp(String email, String code, String newPassword) async {
    state = AuthState.loading();
    try {
      await _authRepository.resetPasswordByOtp(email, code, newPassword);
      state = AuthState.unauthenticated();
      return true;
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
      return false;
    } catch (e) {
      state = AuthState.error("Failed to reset password");
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

    // Only clear auth credentials (token, userId, email, name, profileImage).
    // The DB cache is intentionally kept so the same user logging back in gets
    // instant offline-first load without hitting the server again.
    // If a DIFFERENT user logs in next, login() detects the mismatch via
    // lastLoggedInUserId and wipes the DB at that point.
    Logger.log('logout() — clearing auth credentials, DB cache preserved for same-user re-login', type: 'lifecycle');
    await _storage.clearAll();
    state = AuthState.unauthenticated();
  }
}
