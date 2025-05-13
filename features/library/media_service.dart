import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaService {
  static const String EXCLUDED_FOLDERS_KEY = 'excluded_folders';
  static const String QUALITY_KEYWORDS = 'quality_keywords';
  static const String SELECTED_FOLDERS_KEY = 'selected_folders';
  static const String CACHED_FOLDERS_KEY = 'cached_folders';
  static const String CACHE_TIMESTAMP_KEY = 'folders_cache_timestamp';

  // Cache duration in milliseconds (24 hours)
  static const int CACHE_DURATION = 24 * 60 * 60 * 1000;

  // Minimum video file size in bytes (1MB)
  static const int MIN_VIDEO_SIZE = 1 * 1024 * 1024; // 1MB

  // List of video file extensions
  static const List<String> VIDEO_EXTENSIONS = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    '3gp',
    'flv',
    'webm',
  ];

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

  // Protected paths that should never be excluded
  static final List<String> protectedPaths = [
    '/storage/emulated/0',
    '/Movies',
    '/Download',
    '/Downloads',
    '/Video',
    '/Videos',
  ];

  static Future<bool> requestStoragePermission() async {
    try {
      // Create a list to track which permissions we have
      final List<bool> grantedPermissions = [];

      // Request basic storage permission first
      PermissionStatus status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      grantedPermissions.add(status.isGranted);

      // Request additional permissions for Android
      if (Platform.isAndroid) {
        // Request manage external storage for broader access
        final manageExternalStatus =
            await Permission.manageExternalStorage.request();
        grantedPermissions.add(manageExternalStatus.isGranted);

        // For Android 13+, request video permission (more focused approach)
        try {
          final videosStatus = await Permission.videos.request();
          grantedPermissions.add(videosStatus.isGranted);
        } catch (e) {
          debugPrint('Error requesting video permissions: $e');
          // Ignore error, we'll fall back to other permissions
        }
      }

      // Return true if ANY permission was granted
      return grantedPermissions.any((granted) => granted);
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      // In case of error, conservatively return false
      return false;
    }
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

    // Fallback - if no directories were found, add the root directory
    if (directories.isEmpty && Platform.isAndroid) {
      try {
        final rootDir = Directory('/storage/emulated/0');
        if (await rootDir.exists()) {
          directories.add(rootDir);
        }
      } catch (e) {
        debugPrint('Error adding fallback root directory: $e');
      }
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
          dir.path.startsWith('${existingDir.path}/'),
    );
  }

  static Future<List<Map<String, dynamic>>> getAllFolders({
    bool forceRefresh = false,
  }) async {
    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedFolders = await _loadCachedFolders();
      if (cachedFolders != null) {
        debugPrint('Loaded folders from cache');
        return cachedFolders;
      }
    }

    final List<Map<String, dynamic>> folders = [];
    bool hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      debugPrint('Storage permission not granted');
      return folders;
    }

    final List<String> excludedFolders = await getExcludedFolders();
    final List<Directory> baseDirectories = await getAllMediaDirectories();

    // Fallback to ensure we always have at least the root directory
    if (baseDirectories.isEmpty) {
      folders.add({
        'path': '/storage/emulated/0',
        'name': 'Internal Storage',
        'isSelected': false,
        'videoCount': 0,
        'totalSize': 0,
      });
      return folders;
    }

    for (final baseDir in baseDirectories) {
      try {
        await _scanDirectory(baseDir.path, folders, excludedFolders);
      } catch (e) {
        debugPrint('Error scanning ${baseDir.path}: $e');
      }
    }

    // Always make sure Movies and Download folders are at the top if they exist
    _prioritizeImportantFolders(folders);

    // Cache the folders for next time
    await _cacheFolders(folders);

    return folders;
  }

  static void _prioritizeImportantFolders(List<Map<String, dynamic>> folders) {
    // First extract and remove the Movies and Download folders
    final moviesFolders =
        folders
            .where(
              (folder) =>
                  folder['path'].contains('/Movies') ||
                  folder['name'].toLowerCase() == 'movies' ||
                  folder['name'].toLowerCase() == 'movie',
            )
            .toList();

    final downloadFolders =
        folders
            .where(
              (folder) =>
                  folder['path'].contains('/Download') ||
                  folder['name'].toLowerCase() == 'download' ||
                  folder['name'].toLowerCase() == 'downloads',
            )
            .toList();

    // Remove them from the original list
    folders.removeWhere(
      (folder) =>
          folder['path'].contains('/Movies') ||
          folder['name'].toLowerCase() == 'movies' ||
          folder['name'].toLowerCase() == 'movie' ||
          folder['path'].contains('/Download') ||
          folder['name'].toLowerCase() == 'download' ||
          folder['name'].toLowerCase() == 'downloads',
    );

    // Add them back in priority order
    for (final folder in [...moviesFolders, ...downloadFolders]) {
      folders.insert(0, folder);
    }
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

    // Never exclude protected paths
    bool isProtectedPath = false;
    for (final protectedPath in protectedPaths) {
      if (path == protectedPath || path.endsWith(protectedPath)) {
        isProtectedPath = true;
        break;
      }
    }

    // Skip excluded paths, but only if they're not protected
    if (!isProtectedPath && _isExcludedPath(path, userExcludedFolders)) {
      return;
    }

    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;

      final name = path.split('/').last.isEmpty ? path : path.split('/').last;

      // Check if folder has video files over 1MB (more expensive operation)
      final videoFileSummary = await _getVideoSummary(path);
      final bool hasValidVideos = videoFileSummary['count'] > 0;

      // If it has valid video files, add it
      if (hasValidVideos) {
        // Check if this path is already in our folders list to avoid duplicates
        final alreadyAdded = folders.any((folder) => folder['path'] == path);

        if (!alreadyAdded) {
          // Check if this folder is currently selected by the user
          final selectedFolders = await getSelectedFolders();
          // Explicitly set isSelected to a boolean value
          final bool isSelected = selectedFolders.contains(path) ? true : false;

          folders.add({
            'path': path,
            'name': name,
            'isSelected': isSelected,
            'videoCount': videoFileSummary['count'],
            'totalSize': videoFileSummary['totalSize'],
          });
        }
      }

      // Auto-excluded patterns - only apply AFTER checking for video files
      // Skip recursion into subfolders for auto-excluded patterns unless protected
      if (!isProtectedPath && _isAutoExcludedPath(path)) {
        return;
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

  // Helper function to check if path is in user excluded paths
  static bool _isExcludedPath(String path, List<String> userExcludedFolders) {
    // Always handle the root directory case
    if (path == '/storage/emulated/0') {
      return false;
    }

    return userExcludedFolders.any((excluded) => path.contains(excluded));
  }

  // Helper function to check against auto-excluded patterns
  static bool _isAutoExcludedPath(String path) {
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

    // Check if path matches any auto-excluded pattern
    for (final pattern in autoExcludedPatterns) {
      if (path.contains(pattern)) {
        // Double check that it's not a protected path
        for (final protectedPath in protectedPaths) {
          if (path.contains(protectedPath)) {
            return false; // It's protected, don't exclude
          }
        }
        return true; // Not protected and matches exclusion pattern
      }
    }

    return false; // Not excluded
  }

  // Helper function to check if a file is a valid video
  static bool _isVideoFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return VIDEO_EXTENSIONS.contains(extension);
  }

  // Helper function to check if folder contains video files over 1MB
  static Future<Map<String, dynamic>> _getVideoSummary(String path) async {
    int videoCount = 0;
    int totalSize = 0;

    try {
      final dir = Directory(path);
      if (!await dir.exists()) return {'count': 0, 'totalSize': 0};

      final entities = await dir.list().toList();

      // First process files in this directory
      await _processVideoFiles(entities, (count, size) {
        videoCount += count;
        totalSize += size;
      });

      // Then check first level of subdirectories (limited depth)
      for (final entity in entities) {
        if (entity is Directory) {
          try {
            final subEntities = await entity.list().toList();
            await _processVideoFiles(subEntities, (count, size) {
              videoCount += count;
              totalSize += size;
            });
          } catch (e) {
            // Ignore errors in subdirectories
          }
        }
      }

      return {'count': videoCount, 'totalSize': totalSize};
    } catch (e) {
      debugPrint('Error checking for videos in $path: $e');
      return {'count': 0, 'totalSize': 0};
    }
  }

  // Helper to process video files
  static Future<void> _processVideoFiles(
    List<FileSystemEntity> entities,
    Function(int count, int size) callback,
  ) async {
    int count = 0;
    int size = 0;

    for (final entity in entities) {
      if (entity is File && _isVideoFile(entity.path)) {
        try {
          final fileSize = await entity.length();
          if (fileSize >= MIN_VIDEO_SIZE) {
            count++;
            size += fileSize;
          }
        } catch (e) {
          debugPrint('Error getting file size for ${entity.path}: $e');
        }
      }
    }

    callback(count, size);
  }

  // Cache management
  static Future<void> _cacheFolders(List<Map<String, dynamic>> folders) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert folders to simple string format for caching
      final List<String> serialized =
          folders.map((folder) {
            // Ensure isSelected is properly converted to a string boolean
            final bool isSelected = folder['isSelected'] == true;
            return '${folder['path']}|${folder['name']}|${folder['videoCount']}|${folder['totalSize']}|$isSelected';
          }).toList();

      await prefs.setStringList(CACHED_FOLDERS_KEY, serialized);
      await prefs.setInt(
        CACHE_TIMESTAMP_KEY,
        DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('Saved ${folders.length} folders to cache');
    } catch (e) {
      debugPrint('Error caching folders: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> _loadCachedFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cache exists and isn't expired
      final timestamp = prefs.getInt(CACHE_TIMESTAMP_KEY);
      if (timestamp == null) return null;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > CACHE_DURATION) {
        debugPrint('Cache expired');
        return null;
      }

      final serialized = prefs.getStringList(CACHED_FOLDERS_KEY);
      if (serialized == null || serialized.isEmpty) return null;

      // Deserialize the cached folders
      final List<Map<String, dynamic>> folders = [];
      for (final item in serialized) {
        final parts = item.split('|');
        if (parts.length >= 4) {
          // Allow for backward compatibility
          final Map<String, dynamic> folder = {
            'path': parts[0],
            'name': parts[1],
            'videoCount': int.tryParse(parts[2]) ?? 0,
            'totalSize': int.tryParse(parts[3]) ?? 0,
            // Ensure isSelected is always a boolean and has a default value
            'isSelected': parts.length >= 5 ? parts[4] == 'true' : false,
          };
          folders.add(folder);
        }
      }

      return folders;
    } catch (e) {
      debugPrint('Error loading cached folders: $e');
      return null;
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CACHED_FOLDERS_KEY);
      await prefs.remove(CACHE_TIMESTAMP_KEY);
      debugPrint('Cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  // Selected folders management
  static Future<List<String>> getSelectedFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(SELECTED_FOLDERS_KEY) ?? [];
  }

  static Future<void> saveSelectedFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(SELECTED_FOLDERS_KEY, folders);
    debugPrint('Saved ${folders.length} selected folders');
  }

  static Future<void> toggleFolderSelection(
    String path,
    bool isSelected,
  ) async {
    final selectedFolders = await getSelectedFolders();

    if (isSelected && !selectedFolders.contains(path)) {
      selectedFolders.add(path);
    } else if (!isSelected && selectedFolders.contains(path)) {
      selectedFolders.remove(path);
    }

    await saveSelectedFolders(selectedFolders);

    // Update the cache to reflect this change
    final cachedFolders = await _loadCachedFolders();
    if (cachedFolders != null) {
      for (final folder in cachedFolders) {
        if (folder['path'] == path) {
          // Ensure we're setting a boolean value
          folder['isSelected'] = isSelected ? true : false;
        }
      }
      await _cacheFolders(cachedFolders);
    }
  }

  static Future<List<String>> getExcludedFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> excludedFolders =
        prefs.getStringList(EXCLUDED_FOLDERS_KEY) ?? defaultExcludedPaths;

    // Filter out any protected paths that might have been mistakenly saved
    return excludedFolders
        .where(
          (path) =>
              !protectedPaths.any(
                (protectedPath) =>
                    path == protectedPath || path.endsWith(protectedPath),
              ),
        )
        .toList();
  }

  static Future<List<String>> getQualityKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(QUALITY_KEYWORDS) ?? defaultQualityKeywords;
  }

  static Future<void> saveExcludedFolders(List<String> folders) async {
    // Filter out any protected paths
    final filteredFolders =
        folders
            .where(
              (path) =>
                  !protectedPaths.any(
                    (protectedPath) =>
                        path == protectedPath || path.endsWith(protectedPath),
                  ),
            )
            .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(EXCLUDED_FOLDERS_KEY, filteredFolders);
    // Clear cache when excluded folders change
    await clearCache();
  }

  static Future<void> setExcludedFolders(List<String> folders) async {
    // Filter out any protected paths
    final filteredFolders =
        folders
            .where(
              (path) =>
                  !protectedPaths.any(
                    (protectedPath) =>
                        path == protectedPath || path.endsWith(protectedPath),
                  ),
            )
            .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(EXCLUDED_FOLDERS_KEY, filteredFolders);
  }

  static Future<void> saveQualityKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(QUALITY_KEYWORDS, keywords);
  }
}
