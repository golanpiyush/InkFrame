import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class SubtitleService {
  // Cache for 30 minutes
  static const Duration cacheDuration = Duration(minutes: 30);
  static const String cacheFolderName = 'subtitle_cache';

  static String sanitizeTitle(String raw) {
    const filteredTags = [
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

    var title = p
        .basenameWithoutExtension(raw)
        .replaceAll(RegExp(r'[._-]'), ' ')
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ');

    for (final tag in filteredTags) {
      title = title.replaceAll(RegExp('\\b$tag\\b', caseSensitive: false), ' ');
    }

    title =
        title
            .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    return title;
  }

  /// Fetches or returns persistent .srt File for [videoPath].
  static Future<File?> getOrDownloadSubtitle(
    String videoPath, {
    BuildContext? context,
  }) async {
    // First check if storage permission is granted
    final permissionStatus = await Permission.storage.status;
    if (!permissionStatus.isGranted) {
      debugPrint('❌ Storage permission denied.');
      return null;
    }

    try {
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        debugPrint('❌ Video file does not exist: $videoPath');
        return null;
      }

      final title = sanitizeTitle(videoPath);
      debugPrint('🎬 SubtitleService: fetching for "$title"');

      // Check if subtitle already exists
      final subtitlePath = p.join(
        p.dirname(videoPath),
        '${p.basenameWithoutExtension(videoPath)}.srt',
      );

      final subtitleFile = File(subtitlePath);
      if (await subtitleFile.exists()) {
        debugPrint('✅ Found existing subtitle file: $subtitlePath');
        return subtitleFile;
      }

      // Try to find subtitle with same name but .srt extension
      final srtFile = File('${p.withoutExtension(videoPath)}.srt');
      if (await srtFile.exists()) {
        debugPrint('✅ Found subtitle file with same name: ${srtFile.path}');
        return srtFile;
      }

      // If we reach here, we need to download or find subtitles from external source
      // For now, this is a placeholder for your subtitle download functionality
      // Add your subtitle API integration here

      debugPrint(
        '⚠️ No subtitle file found locally. Download functionality not implemented.',
      );
      return null;
    } catch (e) {
      debugPrint('❌ Error in subtitle service: $e');
      return null;
    }
  }
}
