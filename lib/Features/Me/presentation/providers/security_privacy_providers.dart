import 'package:flutter_riverpod/legacy.dart';
import 'package:app/Features/Me/data/repositories/security_repository.dart';
import 'package:app/core/utils/app_logger.dart';

// Providers to handle security switch states
final biometricProvider = StateProvider<bool>((ref) => true);
final twoFactorProvider = StateProvider<bool>((ref) => false);

class PrivacySettingModel {
  final String scope;
  final String level; // EVERYONE, CONTACTS, NOBODY
  final List<String> allowUserIds;
  final List<String> denyUserIds;

  const PrivacySettingModel({
    required this.scope,
    required this.level,
    this.allowUserIds = const [],
    this.denyUserIds = const [],
  });

  factory PrivacySettingModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingModel(
      scope: (json['scope'] ?? '').toString().toUpperCase(),
      level: (json['level'] ?? 'EVERYONE').toString().toUpperCase(),
      allowUserIds: (json['allowUserIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      denyUserIds: (json['denyUserIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  PrivacySettingModel copyWith({
    String? scope,
    String? level,
    List<String>? allowUserIds,
    List<String>? denyUserIds,
  }) {
    return PrivacySettingModel(
      scope: scope ?? this.scope,
      level: level ?? this.level,
      allowUserIds: allowUserIds ?? this.allowUserIds,
      denyUserIds: denyUserIds ?? this.denyUserIds,
    );
  }
}

class PrivacyState {
  final Map<String, PrivacySettingModel> settings;
  final bool isLoading;
  final String? error;

  const PrivacyState({
    this.settings = const {},
    this.isLoading = false,
    this.error,
  });

  PrivacyState copyWith({
    Map<String, PrivacySettingModel>? settings,
    bool? isLoading,
    String? error,
  }) {
    return PrivacyState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  String getLevel(String scope, {String defaultLevel = 'EVERYONE'}) {
    return settings[scope.toUpperCase()]?.level ?? defaultLevel;
  }
}

class PrivacyNotifier extends StateNotifier<PrivacyState> {
  final SecurityRepository _securityRepository;

  PrivacyNotifier(this._securityRepository) : super(const PrivacyState()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _securityRepository.getPrivacySettings();
      final map = <String, PrivacySettingModel>{};
      for (final item in list) {
        final model = PrivacySettingModel.fromJson(item);
        if (model.scope.isNotEmpty) {
          map[model.scope] = model;
        }
      }
      state = state.copyWith(settings: map, isLoading: false);
    } catch (e) {
      Logger.log('Failed to load privacy settings: $e', type: 'error');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateScope(
    String scope,
    String level, {
    List<String> allowUserIds = const [],
    List<String> denyUserIds = const [],
  }) async {
    final normalizedScope = scope.toUpperCase();
    final normalizedLevel = level.toUpperCase();

    // Optimistic local update
    final previousModel = state.settings[normalizedScope];
    final updatedModel = PrivacySettingModel(
      scope: normalizedScope,
      level: normalizedLevel,
      allowUserIds: allowUserIds,
      denyUserIds: denyUserIds,
    );

    state = state.copyWith(
      settings: {...state.settings, normalizedScope: updatedModel},
    );

    try {
      await _securityRepository.updatePrivacySetting(
        scope: normalizedScope,
        level: normalizedLevel,
        allowUserIds: allowUserIds,
        denyUserIds: denyUserIds,
      );
      return true;
    } catch (e) {
      Logger.log('Failed to update privacy scope $scope: $e', type: 'error');
      // Rollback on error
      if (previousModel != null) {
        state = state.copyWith(
          settings: {...state.settings, normalizedScope: previousModel},
        );
      }
      return false;
    }
  }
}

final privacyNotifierProvider =
    StateNotifierProvider<PrivacyNotifier, PrivacyState>((ref) {
  final repo = ref.watch(securityRepositoryProvider);
  return PrivacyNotifier(repo);
});
