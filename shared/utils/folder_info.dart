import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model representing a folder with video count and total size (in bytes).
class FolderInfo {
  final String name;
  final String path;
  final int videoCount;
  final int totalSize;

  const FolderInfo({
    required this.name,
    required this.path,
    required this.videoCount,
    required this.totalSize,
  });

  static const String _cacheKey = 'folder_info_cache';
  static const String _cacheTimestampKey = 'folder_info_cache_timestamp';
  static const Duration _cacheTTL = Duration(hours: 24);

  Map<String, dynamic> toMap() => {
    'name': name,
    'path': path,
    'videoCount': videoCount,
    'totalSize': totalSize,
  };

  factory FolderInfo.fromMap(Map<String, dynamic> map) {
    return FolderInfo(
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      videoCount: map['videoCount'] ?? 0,
      totalSize: map['totalSize'] ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FolderInfo.fromJson(String json) =>
      FolderInfo.fromMap(jsonDecode(json));

  static Future<void> saveListToCache(List<FolderInfo> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(
      _cacheKey,
      jsonEncode(folders.map((f) => f.toMap()).toList()),
    );
    await prefs.setInt(_cacheTimestampKey, now);
  }

  static Future<List<FolderInfo>?> loadListFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_cacheTimestampKey);

    if (jsonString == null || timestamp == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > _cacheTTL.inMilliseconds) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => FolderInfo.fromMap(e)).toList();
    } catch (_) {
      return null;
    }
  }
}
