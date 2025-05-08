import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestAllStoragePermissions(BuildContext context) async {
    // Check and request storage permission
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.storage,
          Permission.manageExternalStorage,

          Permission.videos,
        ].request();

    // Check if any permission was granted
    bool anyGranted = statuses.values.any((status) => status.isGranted);

    // If no permissions were granted, show a dialog
    if (!anyGranted) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: const Text("Storage Permission Required"),
                content: const Text(
                  "This app needs storage permission to scan and find your media files. "
                  "Please grant storage permission in the app settings.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await openAppSettings();
                    },
                    child: const Text("OPEN SETTINGS"),
                  ),
                ],
              ),
        );
      }
      return false;
    }
    return true;
  }
}
