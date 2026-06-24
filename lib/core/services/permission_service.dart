import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// A FutureProvider family to get the current status of a specific permission.
/// Use `ref.invalidate(permissionStatusProvider(Permission.location))` to refresh
/// after requesting a permission.
final permissionStatusProvider = FutureProvider.family<PermissionStatus, Permission>((ref, permission) async {
  final service = ref.watch(permissionServiceProvider);
  return service.checkPermission(permission);
});

class PermissionService {
  Future<PermissionStatus> requestPermission(Permission permission) async {
    return await permission.request();
  }

  Future<PermissionStatus> checkPermission(Permission permission) async {
    return await permission.status;
  }

  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
