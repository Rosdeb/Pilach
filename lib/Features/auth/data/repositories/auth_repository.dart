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
      
      return data['data']; // Returns user info
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
}
