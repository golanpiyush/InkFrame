// lib/utils/permission_handler.dart
import 'package:flutter/material.dart';
import 'package:inkframe/app_global_context.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  // Cache flag to avoid repeated requests
  static bool? _storagePermissionCache;

  /// Checks storage permission with caching to prevent repeated requests
  /// Returns true if permission is granted
  static Future<bool> checkStoragePermission(BuildContext context) async {
    // First check our cache
    if (_storagePermissionCache == true) {
      debugPrint('✅ Using cached permission status: granted');
      return true;
    }

    // For Android 10+ (API 29+), we need to check different permissions
    Permission storagePermission;

    // Check if we're on Android and determine the right permission to request
    if (await _isAndroid13OrHigher()) {
      // For Android 13+ we need to use specific media permissions
      storagePermission = Permission.photos;
    } else if (await _isAndroid11OrHigher()) {
      // For Android 11 and 12
      storagePermission = Permission.manageExternalStorage;
    } else {
      // For Android 10 and below
      storagePermission = Permission.storage;
    }

    // Check current permission status
    final status = await storagePermission.status;

    if (status.isGranted) {
      debugPrint('✅ Storage permission already granted');
      _updatePermissionCache(true);
      return true;
    }

    // If permission is denied but can be requested
    if (status.isDenied) {
      // Don't ask again if we've asked recently (using shared preferences)
      if (await _hasAskedRecently()) {
        debugPrint('⚠️ Already asked recently, won\'t ask again now');
        return false;
      }

      debugPrint('⚠️ Storage permission denied, requesting...');
      final result = await storagePermission.request();

      if (result.isGranted) {
        debugPrint('✅ Storage permission granted');
        _updatePermissionCache(true);
        return true;
      } else {
        debugPrint('❌ Storage permission denied');
        _showPermissionDialog(context);
        _updatePermissionCache(false);
        await _markAsAsked();
        return false;
      }
    }

    // If permission is permanently denied
    if (status.isPermanentlyDenied) {
      debugPrint('❌ Storage permission permanently denied');
      _showPermissionDialog(context, permanent: true);
      _updatePermissionCache(false);
      return false;
    }

    return false;
  }

  /// Shows a dialog explaining why the permission is needed
  static void _showPermissionDialog(
    BuildContext context, {
    bool permanent = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must take action
      builder:
          (context) => AlertDialog(
            title: const Text('Storage Permission Required'),
            content: Text(
              'To download and use subtitles, the app needs permission to access storage. ${permanent
                      ? 'Please open app settings and enable storage permission.'
                      : ''}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (permanent) {
                    openAppSettings();
                  }
                },
                child: Text(permanent ? 'Open Settings' : 'OK'),
              ),
            ],
          ),
    );
  }

  /// Updates the permission cache
  static void _updatePermissionCache(bool granted) {
    _storagePermissionCache = granted;
  }

  /// Checks if we've asked for permission recently
  static Future<bool> _hasAskedRecently() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAsked = prefs.getInt('last_permission_asked') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Don't ask again for 24 hours
    return (now - lastAsked) < 24 * 60 * 60 * 1000;
  }

  /// Marks that we've asked for permission
  static Future<void> _markAsAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'last_permission_asked',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Checks if the device is running Android 11 or higher
  static Future<bool> _isAndroid11OrHigher() async {
    try {
      if (Theme.of(AppGlobalContext.navigatorKey.currentContext!).platform !=
          TargetPlatform.android) {
        return false;
      }
      // Check if device is Android 11 (API 30) or higher
      return await DeviceInfoPlugin().androidInfo.then(
        (info) => info.version.sdkInt >= 30,
      );
    } catch (e) {
      debugPrint('Error checking Android version: $e');
      return false;
    }
  }

  /// Checks if the device is running Android 13 or higher
  static Future<bool> _isAndroid13OrHigher() async {
    try {
      if (Theme.of(AppGlobalContext.navigatorKey.currentContext!).platform !=
          TargetPlatform.android) {
        return false;
      }
      // Check if device is Android 13 (API 33) or higher
      return await DeviceInfoPlugin().androidInfo.then(
        (info) => info.version.sdkInt >= 33,
      );
    } catch (e) {
      debugPrint('Error checking Android version: $e');
      return false;
    }
  }

  /// Reset permission cache (call this when you want to force a re-check)
  static void resetPermissionCache() {
    _storagePermissionCache = null;
  }
}
