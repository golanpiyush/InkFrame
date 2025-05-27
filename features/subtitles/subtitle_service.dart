import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:inkframe/shared/utils/filterwords.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SubtitleService {
  // SubDL API key and base URL
  static const String apiKey = '';
  static const String subDlApiUrl = 'https://api.subdl.com/api/v1/subtitles';

  // Cache configuration
  static const Duration cacheDuration = Duration(minutes: 30);
  static const String cacheFolderName = 'subtitle_cache';

  // Use external filter list
  static final List<String> filteredTags = FilterWords.words;

  /// Helper: get (and create if needed) the cache directory
  static Future<Directory> getSubtitleCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$cacheFolderName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate a safe cache key
  static String generateCacheKey(String title, {String? releaseInfo}) {
    final key = releaseInfo != null ? '$title-$releaseInfo' : title;
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  /// Try to return a cached .srt if it exists and is fresh
  static Future<File?> getCachedSubtitle(String cacheKey) async {
    try {
      final cacheDir = await getSubtitleCacheDir();
      final cachedFile = File('${cacheDir.path}/$cacheKey.srt');
      if (!await cachedFile.exists()) return null;

      final age = DateTime.now().difference((await cachedFile.stat()).modified);
      if (age < cacheDuration) {
        debugPrint('✅ Found valid cached subtitle: ${cachedFile.path}');
        return cachedFile;
      }
      debugPrint('⚠️ Cache expired: ${cachedFile.path}');
      await cachedFile.delete();
    } catch (e) {
      debugPrint('⚠️ Error checking cache: $e');
    }
    return null;
  }

  /// Copy into cache folder
  static Future<void> cacheSubtitle(String cacheKey, File subtitleFile) async {
    try {
      final cacheDir = await getSubtitleCacheDir();
      await subtitleFile.copy('${cacheDir.path}/$cacheKey.srt');
      debugPrint('✅ Cached subtitle: $cacheKey.srt');
    } catch (e) {
      debugPrint('⚠️ Error caching subtitle: $e');
    }
  }

  /// Sanitize a raw filename: strip out any tags in `filteredTags`
  static String sanitizeTitle(String raw) {
    // Step 1: Get the file name without extension and replace common symbols with spaces
    var title =
        p
            .basenameWithoutExtension(raw)
            .replaceAll(
              RegExp(r'[._\-\(\)\[\]]'),
              ' ',
            ) // Replace common symbols with spaces
            .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with one
            .trim(); // Remove any leading or trailing spaces

    // Step 2: Remove unwanted terms inside brackets (e.g., [YTS])
    title = title.replaceAll(
      RegExp(r'\[.*?\]'),
      '',
    ); // Remove content inside brackets

    // Step 3: Define the list of filtered tags and make it case-insensitive
    if (FilterWords.woords.isEmpty) {
      print("FilterWords.woords is empty. Please check your filter word list.");
    } else {
      // Debugging: Print the title before filtering
      print("Title before filtering: $title");

      for (final tag in FilterWords.woords) {
        // Check the word and print it for debugging
        print("Checking tag: $tag");

        title =
            title
                .replaceAll(
                  RegExp(
                    r'(\s|^)' + RegExp.escape(tag) + r'(\s|$)',
                    caseSensitive: false,
                  ),
                  ' ', // Replace filtered tags with a space
                )
                .trim();
      }
    }

    // Step 4: Remove size-related terms like "1400MB", "1000GB", etc.
    title = title.replaceAll(
      RegExp(r'\d+(MB|GB|KB)', caseSensitive: false),
      '',
    );

    // Step 5: Remove any terms that are purely numbers (e.g., "2020", "1000")
    title = title.replaceAll(RegExp(r'\b\d{4,}\b'), '');

    // Step 6: Normalize spaces and clean up
    title =
        title
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim(); // Replace multiple spaces with one and trim

    // Final cleanup
    print('CLEANED TITLE: $title');
    return title;
  }

  /// Extract a 4-digit year if present
  static String? extractYear(String title) {
    final m = RegExp(r'\b(19|20)\d{2}\b').firstMatch(title);
    return m?.group(0);
  }

  /// Search SubDL API and return typed list
  static Future<List<Map<String, dynamic>>> searchSubtitles(
    String query, {
    bool useFileName = false,
  }) async {
    try {
      final params = <String, String>{'api_key': apiKey, 'languages': 'en'};

      if (useFileName) {
        params['file_name'] = query;
      } else {
        params['film_name'] = query;
      }

      final uri = Uri.parse(subDlApiUrl).replace(queryParameters: params);
      debugPrint('🌐 Request: $uri');

      final response = await http
          .get(uri, headers: {'X-API-Key': apiKey})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('❌ Failed search: ${response.statusCode} ${response.body}');
        return <Map<String, dynamic>>[];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final subs = <dynamic>[
        if (data['subtitles'] != null) ...data['subtitles'],
        if (data['results'] != null) ...data['results'],
      ];

      return subs
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('❌ Subtitle Error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Extract tags like "esub", "webrip", etc. for a second-pass search
  static String extractReleaseInfo(String filename) {
    const relevantTags = [
      'esub',
      'webrip',
      'bdrip',
      'x264',
      'x265',
      '1080p',
      '720p',
      'hdrip',
      'web-dl',
      'bluray',
      'hdtv',
      // add more if you need
    ];
    final lower = filename.toLowerCase();
    return relevantTags.where(lower.contains).join(' ');
  }

  /// Download, clean, and save a subtitle by its ID
  static Future<String?> downloadSubtitle(String id, String destPath) async {
    try {
      final resp = await http.get(
        Uri.parse('$subDlApiUrl/download/$id'),
        headers: {'X-API-Key': apiKey},
      );
      if (resp.statusCode != 200) {
        debugPrint('❌ Download failed ${resp.statusCode}');
        return null;
      }
      String content = utf8.decode(resp.bodyBytes);
      content = cleanSrtContent(content);
      await File(destPath).writeAsString(content);
      debugPrint('✅ Downloaded & cleaned: $destPath');
      return destPath;
    } catch (e) {
      debugPrint('❌ Error downloading subtitle: $e');
      return null;
    }
  }

  /// Normalize SRT formatting
  static String cleanSrtContent(String c) =>
      c
          .replaceAll(RegExp(r'\\N', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'{\\an\d+}'), '')
          .replaceAll(RegExp(r'<\/?i>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\r\n|\r|\n'), '\n')
          .trim();

  /// The main entry: get or download subtitle for a given video file
  static Future<File?> getOrDownloadSubtitle(
    String videoPath, {
    BuildContext? context,
  }) async {
    try {
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) return null;

      final srtPath = p.setExtension(videoPath, '.srt');
      if (await File(srtPath).exists()) return File(srtPath);

      // Prepare keys
      final filename = p.basename(videoPath);
      final cleanTitle = sanitizeTitle(filename);
      var cacheKey = generateCacheKey(cleanTitle);

      // 1) Try generic cache
      File? cached = await getCachedSubtitle(cacheKey);

      // 2) If missing and we have release tags, try specific cache
      final releaseInfo = extractReleaseInfo(filename);
      if (cached == null && releaseInfo.isNotEmpty) {
        final specificKey = generateCacheKey(
          cleanTitle,
          releaseInfo: releaseInfo,
        );
        cached = await getCachedSubtitle(specificKey);
        if (cached != null) cacheKey = specificKey;
      }

      if (cached != null) {
        await cached.copy(srtPath);
        return File(srtPath);
      }

      // 3) No cache → search API
      var results = await searchSubtitles(cleanTitle);

      // 4) If no results & we have tags, retry by filename
      if (results.isEmpty && releaseInfo.isNotEmpty) {
        results = await searchSubtitles(filename, useFileName: true);
        if (results.isNotEmpty) {
          cacheKey = generateCacheKey(cleanTitle, releaseInfo: releaseInfo);
        }
      }

      // 5) Download best match
      if (results.isNotEmpty) {
        final id = results.first['id']?.toString();
        if (id != null && id.isNotEmpty) {
          final path = await downloadSubtitle(id, srtPath);
          if (path != null) {
            await cacheSubtitle(cacheKey, File(path));
            return File(path);
          }
        }
      }

      // 6) Fallback search without year/tags
      if (results.isEmpty) {
        final fallbackKey = generateCacheKey(cleanTitle);
        cached = await getCachedSubtitle(fallbackKey);
        if (cached != null) {
          await cached.copy(srtPath);
          return File(srtPath);
        }
        results = await searchSubtitles(cleanTitle);
        if (results.isNotEmpty) {
          final id = results.first['id']?.toString();
          if (id != null && id.isNotEmpty) {
            final path = await downloadSubtitle(id, srtPath);
            if (path != null) {
              await cacheSubtitle(fallbackKey, File(path));
              return File(path);
            }
          }
        }
      }

      if (context != null) Fluttertoast.showToast(msg: "No subtitles found");
      return null;
    } catch (e) {
      debugPrint('❌ Error in getOrDownloadSubtitle: $e');
      if (context != null) Fluttertoast.showToast(msg: "Error: $e");
      return null;
    }
  }

  /// Clear out all cached .srt files
  static Future<int> clearSubtitleCache() async {
    try {
      final dir = await getSubtitleCacheDir();

      // 1) List all directory entries
      final entries = await dir.list().toList();

      // 2) Filter only .srt File instances
      final files =
          entries
              .where((e) => e is File && e.path.toLowerCase().endsWith('.srt'))
              .cast<File>()
              .toList();

      // 3) Delete each file
      for (final file in files) {
        await file.delete();
      }

      debugPrint('🧹 Cleared ${files.length} subtitle file(s)');
      return files.length;
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
      return 0;
    }
  }

  /// Size of cache in KB
  static Future<int> getCacheSizeKB() async {
    try {
      final dir = await getSubtitleCacheDir();
      // First, collect all entries into a List<FileSystemEntity>
      final entries = await dir.list().toList();

      int totalBytes = 0;
      // Only sum up File sizes
      for (final entity in entries) {
        if (entity is File) {
          final stat = await entity.stat();
          totalBytes += stat.size;
        }
      }

      // Convert bytes → kilobytes (integer division)
      return totalBytes ~/ 1024;
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
      return 0;
    }
  }
}
