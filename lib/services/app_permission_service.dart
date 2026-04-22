import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPermissionService {
  AppPermissionService._();

  static const String _startupPermissionsKey =
      'startup_permissions_requested_v1';
  static bool _isRequesting = false;

  static Future<void> requestStartupPermissionsOnce() async {
    if (_isRequesting) return;
    _isRequesting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRequested = prefs.getBool(_startupPermissionsKey) ?? false;
      if (hasRequested) return;

      await _requestIfNeeded(Permission.camera);
      await _requestIfNeeded(Permission.microphone);
      await _requestIfNeeded(Permission.notification);

      await prefs.setBool(_startupPermissionsKey, true);
    } finally {
      _isRequesting = false;
    }
  }

  static Future<void> _requestIfNeeded(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted ||
        status.isLimited ||
        status.isPermanentlyDenied ||
        status.isRestricted) {
      return;
    }
    await permission.request();
  }
}
