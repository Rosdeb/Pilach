import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/core/network/api_exceptions.dart';
import 'package:messageapp/core/providers/api_provider.dart';
import 'package:messageapp/core/services/api_service.dart';
import 'package:messageapp/core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiServiceProvider));
});

class AuthRepository {
  final ApiService _apiService;

  AuthRepository(this._apiService);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiService.post(
      ApiConstants.login,
      data: {
        "email": email,
        "password": password,
      },
    );
    
    final data = response.data;
    if (data['success'] == true) {
      if (data['challengeId'] != null) {
        return {
          "is2faRequired": true,
          "challengeId": data['challengeId'],
          "methods": data['methods'] ?? [],
        };
      }

      final prefs = await SharedPreferences.getInstance();
      
      if (data['tokens'] != null) {
        await prefs.setString('auth_token', data['tokens']['access']['token']);
        await prefs.setString('refresh_token', data['tokens']['refresh']['token']);
      } else {
        final cookies = response.headers.map['set-cookie'] ?? [];
        String? accessToken;
        String? refreshToken;
        
        for (var cookie in cookies) {
          if (cookie.contains('access_token=')) {
            final match = RegExp(r'access_token=([^;]+)').firstMatch(cookie);
            if (match != null) accessToken = match.group(1);
          }
          if (cookie.contains('refresh_token=')) {
            final match = RegExp(r'refresh_token=([^;]+)').firstMatch(cookie);
            if (match != null) refreshToken = match.group(1);
          }
        }
        
        if (accessToken != null) {
          await prefs.setString('auth_token', accessToken);
        }
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
        }
      }
      
      final userId = data['data']?['id'];
      if (userId != null) {
        await prefs.setString('user_id', userId);
      }

      return {
        "is2faRequired": false,
        "user": data['data'],
      };
    }
    throw ApiException(data['message'] ?? 'Login failed');
  }

  Future<void> register(String name, String email, String password) async {
    final response = await _apiService.post(
      ApiConstants.register,
      data: {
        "name": name,
        "email": email,
        "password": password,
      },
    );

    if (response.data['success'] != true) {
      throw ApiException(response.data['message'] ?? 'Registration failed');
    }
  }

  Future<void> verifyEmailOtp(String email, String code) async {
    final response = await _apiService.post(
      ApiConstants.verifyOtp,
      data: {
        "email": email,
        "code": code,
      },
    );

    if (response.data['success'] != true) {
      throw ApiException(response.data['message'] ?? 'Verification failed');
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.post(ApiConstants.logout);
    } catch (e) {
      // Ignore errors on logout
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
    }
  }

  // ==========================================
  // 🔐 Two-Factor Authentication (2FA) Methods
  // ==========================================

  Future<void> enrollEmailRequest(String email) async {
    final response = await _apiService.post(
      ApiConstants.twoFactorEnrollEmailRequest,
      data: {"email": email},
    );
    if (response.data['success'] != true) {
      throw ApiException(response.data['message'] ?? 'Failed to request email 2FA enrollment');
    }
  }

  Future<void> enrollEmailConfirm(String code) async {
    final response = await _apiService.post(
      ApiConstants.twoFactorEnrollEmailConfirm,
      data: {"code": code},
    );
    if (response.data['success'] != true) {
      throw ApiException(response.data['message'] ?? 'Email 2FA confirmation failed');
    }
  }

  Future<void> enrollSmsRequest(String phone) async {
    final response = await _apiService.post(
      ApiConstants.twoFactorEnrollSmsRequest,
      data: {"phone": phone},
    );
    if (response.data['success'] != true) {
      throw ApiException(response.data['message'] ?? 'Failed to request SMS 2FA enrollment');
    }
  }

  Future<void> enrollSmsConfirm(String code) async {
    final response = await _apiService.post(
      ApiConstants.twoFactorEnrollSmsConfirm,
      data: {"code": code},
    );
    if (response.data['success'] != true) {
      throw ApiException(response.data['message'] ?? 'SMS 2FA confirmation failed');
    }
  }

  Future<List<dynamic>> fetchTwoFactorMethods() async {
    final response = await _apiService.get(ApiConstants.twoFactorMethods);
    final data = response.data;
    if (data['success'] == true) {
      return data['data'] ?? [];
    }
    throw ApiException(data['message'] ?? 'Failed to fetch 2FA methods');
  }

  Future<void> disableTwoFactorMethod(String methodId) async {
    final response = await _apiService.delete("${ApiConstants.twoFactorMethods}/$methodId");
    if (response.data['success'] != true) {
      throw ApiException(response.data['message'] ?? 'Failed to disable 2FA method');
    }
  }

  Future<void> sendTwoFactorChallenge({
    required String challengeId,
    required String type,
  }) async {
    final response = await _apiService.post(
      ApiConstants.twoFactorChallengeSend,
      data: {
        "challengeId": challengeId,
        "type": type,
      },
    );
    if (response.data['success'] != true) {
      throw ApiException(response.data['message'] ?? 'Failed to send 2FA challenge');
    }
  }

  Future<Map<String, dynamic>> verifyTwoFactorChallenge({
    required String challengeId,
    required String type,
    required String code,
  }) async {
    final response = await _apiService.post(
      ApiConstants.twoFactorChallengeVerify,
      data: {
        "challengeId": challengeId,
        "type": type,
        "code": code,
      },
    );
    final data = response.data;
    if (data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      if (data['tokens'] != null) {
        await prefs.setString('auth_token', data['tokens']['access']['token']);
        await prefs.setString('refresh_token', data['tokens']['refresh']['token']);
      }
      final userId = data['data']?['id'];
      if (userId != null) {
        await prefs.setString('user_id', userId);
      }
      return data;
    }
    throw ApiException(data['message'] ?? '2FA Verification failed');
  }
}
