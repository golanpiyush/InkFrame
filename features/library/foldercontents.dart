import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart'; // Import the video_thumbnail package
import 'package:path/path.dart' as p;
import 'package:inkframe/features/player/player_screen.dart';

class FolderContents extends StatelessWidget {
  final String folderPath;

  const FolderContents({required this.folderPath, super.key});

  @override
  Widget build(BuildContext context) {
    final directory = Directory(folderPath);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          p.basename(folderPath),
          style: const TextStyle(fontFamily: 'ink-frames-regular'),
        ),
      ),
      body: FutureBuilder<List<File>>(
        future: _getVideoFiles(directory),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No videos found',
                style: TextStyle(fontFamily: 'ink-frames-regular'),
              ),
            );
          }

          final videos = snapshot.data!;
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final file = videos[index];
              return FutureBuilder<String?>(
                // FutureBuilder for thumbnail generation using video_thumbnail package
                future: _generateThumbnail(file.path),
                builder: (context, thumbSnapshot) {
                  final thumbnailPath = thumbSnapshot.data;
                  return ListTile(
                    leading:
                        thumbnailPath != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(thumbnailPath),
                                width: 80,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            )
                            : const Icon(Icons.videocam),
                    title: Text(
                      p.basename(file.path),
                      style: const TextStyle(fontFamily: 'ink-frames-regular'),
                    ),
                    subtitle: Text(
                      _formatFileSize(file.lengthSync()),
                      style: const TextStyle(fontFamily: 'ink-frames-regular'),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(videoPath: file.path),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<File>> _getVideoFiles(Directory dir) async {
    final List<File> videoFiles = [];
    final videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv'];
    final defaultQualityKeywords = [
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

    try {
      final List<FileSystemEntity> entities = dir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (videoExtensions.contains(ext)) {
            final fileName = p.basename(entity.path).toLowerCase();
            final folderName = p.basename(p.dirname(entity.path)).toLowerCase();

            final containsKeyword = defaultQualityKeywords.any(
              (keyword) =>
                  fileName.contains(keyword) || folderName.contains(keyword),
            );

            if (containsKeyword) {
              videoFiles.add(entity);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading folder contents: $e');
    }

    return videoFiles;
  }

  // Using the video_thumbnail package for generating thumbnails
  Future<String?> _generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outPath = p.join(
        tempDir.path,
        '${p.basenameWithoutExtension(videoPath)}_thumb.jpg',
      );

      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128,
        quality: 75,
      );

      if (uint8list != null) {
        final file = File(outPath);
        await file.writeAsBytes(uint8list);
        return outPath;
      }
      return null;
    } catch (e) {
      debugPrint('Thumbnail generation error for $videoPath: $e');
      return null;
    }
  }

  String _formatFileSize(int bytes) {
    final sizeInMB = bytes / (1024 * 1024);
    if (sizeInMB >= 1024) {
      return '${(sizeInMB / 1024).toStringAsFixed(1)} GB';
    } else {
      return '${sizeInMB.toStringAsFixed(1)} MB';
    }
  }
}
