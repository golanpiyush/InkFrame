import 'dart:io';

import 'package:video_player/video_player.dart';

class PlayerController {
  final String videoPath;
  late VideoPlayerController videoController;

  PlayerController(this.videoPath) {
    videoController = VideoPlayerController.file(File(videoPath));
  }

  Future<void> initialize() async {
    await videoController.initialize();
    await videoController.setLooping(true);
  }

  void dispose() {
    videoController.dispose();
  }
}
