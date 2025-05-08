import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaService {
  static const String EXCLUDED_FOLDERS_KEY = 'excluded_folders';
  static const String QUALITY_KEYWORDS = 'quality_keywords';

  // Default quality keywords to look for in folder names
  static final List<String> defaultQualityKeywords = [
    'webrip',
    'bdrip',
    'x264',
    'x265',
    'yify',
    'bluray',
    'brrip',
    'hdtv',
    'dvdrip',
    '1080p',
    '720p',
    '4k',
    'uhd',
    'hdrip',
  ];

  // Default folders to exclude (Paths that are generally restricted or unwanted)
  static final List<String> defaultExcludedPaths = [
    '/Android/data',
    '/Android/obb',
    '/WhatsApp/Media',
    '/DCIM/ScreenRecorder',
    '/DCIM/Camera',
    '/DCIM/Screenshots',
    '/Recordings',
    '/Ringtones',
    '/Alarms',
  ];

  static Future<bool> requestStoragePermission() async {
    try {
      // Request basic storage permission first
      PermissionStatus status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      // Request additional permissions for all Android versions
      // This approach is simpler and more robust
      if (Platform.isAndroid) {
        // Request manage external storage for broader access
        final manageExternalStatus =
            await Permission.manageExternalStorage.request();

        // For Android 13+, request only video permission (more focused approach)
        try {
          // Only request videos permission - we're focusing on video files only
          final videosStatus = await Permission.videos.request();

          // Return true if we have either basic storage access, manage external,
          // or videos permission
          return status.isGranted ||
              manageExternalStatus.isGranted ||
              videosStatus.isGranted;
        } catch (e) {
          debugPrint('Error requesting video permissions: $e');
          // If video permission fails, fall back to the storage permission
          return status.isGranted || manageExternalStatus.isGranted;
        }
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  static Future<int> _getAndroidSDKVersion() async {
    // Hardcoded approach - assume all modern Android devices need the new permissions
    // This is safer than trying to parse version strings that vary by device
    try {
      // For debugging purposes only
      if (Platform.isAndroid) {
        debugPrint('Android version string: ${Platform.version}');
      }
    } catch (e) {
      debugPrint('Error accessing Platform.version: $e');
    }

    // Return a value that will trigger the extra permissions for Android 13+
    return 33; // Always request all permissions for Android 13+ (API 33+)
  }

  static Future<List<Directory>> getAllMediaDirectories() async {
    List<Directory> directories = [];
    bool hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      debugPrint('Storage permission not granted');
      return directories;
    }

    try {
      // Prioritize certain directories (like Movies and Downloads)
      if (Platform.isAndroid) {
        // Add important paths first in order of priority
        final priorityPaths = [
          '/storage/emulated/0/Movies',
          '/storage/emulated/0/Download',
          '/storage/emulated/0',
        ];

        for (final path in priorityPaths) {
          final dir = Directory(path);
          if (await dir.exists() && !_directoryAlreadyAdded(directories, dir)) {
            directories.add(dir);
          }
        }

        // Other potential media directories
        final secondaryPaths = [
          '/storage/emulated/0/DCIM',
          '/storage/emulated/0/Videos',
          '/storage/emulated/0/Video',
        ];

        for (final path in secondaryPaths) {
          final dir = Directory(path);
          if (await dir.exists() && !_directoryAlreadyAdded(directories, dir)) {
            directories.add(dir);
          }
        }
      }

      // Add app-specific directories
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null &&
          await externalDir.exists() &&
          !_directoryAlreadyAdded(directories, externalDir)) {
        directories.add(externalDir);
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      if (await appDocDir.exists() &&
          !_directoryAlreadyAdded(directories, appDocDir)) {
        directories.add(appDocDir);
      }

      // Add external storage directories last
      if (Platform.isAndroid) {
        final externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null) {
          for (final dir in externalDirs) {
            if (await dir.exists() &&
                !_directoryAlreadyAdded(directories, dir)) {
              directories.add(dir);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error retrieving directories: $e');
    }
    return directories;
  }

  // Helper to prevent duplicate directories
  static bool _directoryAlreadyAdded(
    List<Directory> directories,
    Directory dir,
  ) {
    return directories.any(
      (existingDir) =>
          existingDir.path == dir.path ||
          dir.path.startsWith(existingDir.path + '/'),
    );
  }

  static Future<List<Map<String, dynamic>>> getAllFolders() async {
    final List<Map<String, dynamic>> folders = [];
    bool hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      debugPrint('Storage permission not granted');
      return folders;
    }

    final List<String> excludedFolders = await getExcludedFolders();
    final List<Directory> baseDirectories = await getAllMediaDirectories();

    if (baseDirectories.isEmpty) {
      folders.add({
        'path': '/storage/emulated/0',
        'name': 'Internal Storage',
        'isQualityFolder': false,
        'hasVideoFiles': false,
      });
      return folders;
    }

    for (final baseDir in baseDirectories) {
      try {
        await _scanDirectory(baseDir.path, folders, excludedFolders);
      } catch (e) {
        debugPrint('Error scanning ${baseDir.path}: $e');
        folders.add({
          'path': baseDir.path,
          'name': baseDir.path.split('/').last,
          'isQualityFolder': false,
          'hasVideoFiles': false,
        });
      }
    }

    if (folders.isEmpty) {
      folders.add({
        'path': '/storage/emulated/0/Download',
        'name': 'Download',
        'isQualityFolder': false,
        'hasVideoFiles': false,
      });
      folders.add({
        'path': '/storage/emulated/0/Movies',
        'name': 'Movies',
        'isQualityFolder': false,
        'hasVideoFiles': false,
      });
    }

    // Custom sorting function based on priority order:
    // 1. Movies folders
    // 2. Download folders
    // 3. Quality folders
    // 4. Other video folders
    // 5. Alphabetical
    folders.sort((a, b) {
      final aPath = a['path'] as String;
      final bPath = b['path'] as String;
      final aName = a['name'] as String;
      final bName = b['name'] as String;

      // Priority 1: Movies folders (either by path or name)
      final aIsMovieFolder =
          aPath.contains('/Movies') ||
          aName.toLowerCase() == 'movies' ||
          aName.toLowerCase() == 'movie';
      final bIsMovieFolder =
          bPath.contains('/Movies') ||
          bName.toLowerCase() == 'movies' ||
          bName.toLowerCase() == 'movie';

      if (aIsMovieFolder && !bIsMovieFolder) return -1;
      if (!aIsMovieFolder && bIsMovieFolder) return 1;

      // Priority 2: Download folders
      final aIsDownloadFolder =
          aPath.contains('/Download') ||
          aName.toLowerCase() == 'download' ||
          aName.toLowerCase() == 'downloads';
      final bIsDownloadFolder =
          bPath.contains('/Download') ||
          bName.toLowerCase() == 'download' ||
          bName.toLowerCase() == 'downloads';

      if (aIsDownloadFolder && !bIsDownloadFolder) return -1;
      if (!aIsDownloadFolder && bIsDownloadFolder) return 1;

      // Priority 3: Quality folders
      final aIsQuality = a['isQualityFolder'] as bool;
      final bIsQuality = b['isQualityFolder'] as bool;

      if (aIsQuality && !bIsQuality) return -1;
      if (!aIsQuality && bIsQuality) return 1;

      // Priority 4: Other video folders
      final aHasVideos = a['hasVideoFiles'] as bool;
      final bHasVideos = b['hasVideoFiles'] as bool;

      if (aHasVideos && !bHasVideos) return -1;
      if (!aHasVideos && bHasVideos) return 1;

      // Finally, sort alphabetically
      return aName.compareTo(bName);
    });

    return folders;
  }

  static Future<void> _scanDirectory(
    String path,
    List<Map<String, dynamic>> folders,
    List<String> userExcludedFolders,
  ) async {
    // Skip hidden folders (starting with '.')
    if (path.split('/').last.startsWith('.')) {
      return;
    }

    // Check user-specified exclusions first
    if (userExcludedFolders.any((excluded) => path.contains(excluded))) {
      return;
    }

    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;

      final name = path.split('/').last.isEmpty ? path : path.split('/').last;

      // First, check if folder name contains quality keywords
      final isQualityFolder = await _isQualityFolder(path);

      // Then check if folder has video files (more expensive operation)
      final hasVideoFiles = await _isVideoFolder(path);

      // If it's a quality folder or has video files, definitely add it
      final isMovieFolder =
          name.toLowerCase().contains('movie') || path.contains('/Movies');
      final isVideoFolder = name.toLowerCase().contains('video');
      final isDownloadFolder =
          name.toLowerCase().contains('download') || path.contains('/Download');

      // Add to list if it matches our criteria
      if (hasVideoFiles ||
          isQualityFolder ||
          isMovieFolder ||
          isVideoFolder ||
          isDownloadFolder) {
        // Check if this path is already in our folders list to avoid duplicates
        final alreadyAdded = folders.any((folder) => folder['path'] == path);

        if (!alreadyAdded) {
          folders.add({
            'path': path,
            'name': name,
            'isQualityFolder': isQualityFolder,
            'hasVideoFiles': hasVideoFiles,
          });
        }
      }

      // Auto-excluded patterns - only apply AFTER checking for quality folders and video files
      // This ensures quality folders aren't excluded even if they're in typically excluded paths
      final autoExcludedPatterns = [
        // System folders
        '/Android/data',
        '/Android/obb',
        '/LOST.DIR',
        '/.trashed',
        '/.trash',
        '/.thumbnails',
        '/Movies/.thumbnails',
        '/DCIM/.thumbnails',

        // Camera and screenshots folders (various manufacturers)
        '/DCIM/Camera',
        '/DCIM/Screenshots',
        '/Pictures/Screenshots',
        '/Pictures/Screen captures',
        '/DCIM/ScreenRecorder',
        '/Screenrecord',
        '/Screen recordings',
        '/ScreenCapture',
        '/ScreenRecords',

        // Samsung specific folders
        '/DCIM/Camera (Samsung)',
        '/Samsung/Camera',
        '/Pictures/Samsung',

        // Xiaomi/Redmi specific folders
        '/MIUI/Gallery',
        '/MIUI/Camera',
        '/DCIM/Camera (Xiaomi)',

        // Oppo/Realme/OnePlus specific folders
        '/DCIM/Camera (OPPO)',
        '/ColorOS/Camera',
        '/Pictures/OPPO',
        '/OnePlus/Camera',

        // Motorola specific folders
        '/DCIM/Camera (Motorola)',
        '/Motorola/Camera',

        // Huawei specific folders
        '/DCIM/Camera (HUAWEI)',
        '/Pictures/HUAWEI',
        '/EMUI/Camera',

        // Social media app folders
        '/WhatsApp',
        '/WhatsApp Images',
        '/WhatsApp Video',
        '/Telegram',
        '/Telegram Images',
        '/Telegram Video',
        '/Instagram',
        '/Snapchat',
        '/TikTok',
        '/Facebook',
        '/Messenger',
        '/Signal',

        // Video editor app folders
        '/Filmora',
        '/VITA',
        '/KineMaster',
        '/CapCut',
        '/InShot',
        '/PowerDirector',

        // System sounds and recordings
        '/Recordings',
        '/Recorder',
        '/Voice Recorder',
        '/Sound Recorder',
        '/Ringtones',
        '/Alarms',
        '/Notifications',
        '/Sounds',

        // Common media folders (likely containing personal photos)
        '/Pictures',
        '/Gallery',
        '/Camera',
      ];

      // Special cases that should never be auto-excluded
      final protectedFolders = [
        '/Movies',
        '/Download',
        '/Downloads',
        '/Video',
        '/Videos',
      ];

      // Check if path matches any auto-excluded pattern & is not in protected folders
      // Only skip recursion into subfolders if this is an excluded pattern
      if (autoExcludedPatterns.any(
        (pattern) =>
            path.contains(pattern) &&
            !protectedFolders.any((protected) => path.contains(protected)),
      )) {
        return; // Skip recursion into subfolders for excluded patterns
      }

      // Limit recursion depth
      final depth = path.split('/').length;
      if (depth > 10) return;

      // Process subdirectories
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          await _scanDirectory(entity.path, folders, userExcludedFolders);
        }
      }
    } catch (e) {
      debugPrint('Error accessing $path: $e');
    }
  }

  static Future<int> _countFilesInDirectory(Directory dir) async {
    try {
      return await dir.list().where((entity) => entity is File).length;
    } catch (e) {
      debugPrint('Error counting files: $e');
      return 0;
    }
  }

  // Helper function to check if folder contains video files
  static Future<bool> _isVideoFolder(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return false;

      final entities = await dir.list().toList();

      // Check if folder contains video files
      for (final entity in entities) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if ([
            'mp4',
            'mkv',
            'avi',
            'mov',
            'wmv',
            '3gp',
            'flv',
            'webm',
          ].contains(extension)) {
            return true;
          }
        }
      }

      // Check first level of subdirectories for video files (limited depth check)
      for (final entity in entities) {
        if (entity is Directory) {
          try {
            final subEntities = await entity.list().toList();
            for (final subEntity in subEntities) {
              if (subEntity is File) {
                final extension = subEntity.path.split('.').last.toLowerCase();
                if ([
                  'mp4',
                  'mkv',
                  'avi',
                  'mov',
                  'wmv',
                  '3gp',
                  'flv',
                  'webm',
                ].contains(extension)) {
                  return true;
                }
              }
            }
          } catch (e) {
            // Ignore errors in subdirectories
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking for videos in $path: $e');
      return false;
    }
  }

  static Future<bool> _isQualityFolder(String path) async {
    final folderName = path.split('/').last.toLowerCase();
    final qualityKeywords = await getQualityKeywords();
    return qualityKeywords.any(
      (keyword) => folderName.contains(keyword.toLowerCase()),
    );
  }

  static Future<List<String>> getExcludedFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(EXCLUDED_FOLDERS_KEY) ?? defaultExcludedPaths;
  }

  static Future<List<String>> getQualityKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(QUALITY_KEYWORDS) ?? defaultQualityKeywords;
  }

  static Future<void> saveExcludedFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(EXCLUDED_FOLDERS_KEY, folders);
  }

  static Future<void> saveQualityKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(QUALITY_KEYWORDS, keywords);
  }
}
