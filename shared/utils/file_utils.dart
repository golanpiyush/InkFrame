// import 'dart:io';

class FileUtils {
  static bool isVideoFile(String path) {
    final videoExtensions = ['.mp4', '.avi', '.mkv'];
    return videoExtensions.any((ext) => path.endsWith(ext));
  }
}
