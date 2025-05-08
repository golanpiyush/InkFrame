// lib/player_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:inkframe/features/subtitles/subtitle_permission_handler.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:inkframe/features/subtitles/subtitle_service.dart';
// import 'package:inkframe/utils/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../subtitles/styles.dart';

class PlayerScreen extends StatefulWidget {
  final String videoPath;
  const PlayerScreen({Key? key, required this.videoPath}) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  late AnimationController _fadeController;
  bool _showControls = true;
  IconData _centerIcon = Icons.play_arrow;
  Timer? _hideTimer;
  bool _isDragging = false;

  // Manual subtitle state
  List<_SubtitleEntry> _subtitles = [];
  bool _subtitlesEnabled = true;
  SubtitlePosition _position = SubtitlePosition.bottom;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath));
    await _videoController.initialize();

    // Add this listener
    _videoController.addListener(() {
      // only rebuild if subtitles are enabled & there's actually text to show
      if (_subtitlesEnabled && _currentSubtitle != null) {
        setState(() {});
      }
    });

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      showControls: false,
    );

    setState(() {});

    // Check permissions and load subtitles after player is initialized
    _checkPermissionAndLoadSubtitles();
  }

  Future<void> _checkPermissionAndLoadSubtitles() async {
    // We don't need to only check once, since we have caching in the PermissionManager
    final hasPermission = await PermissionManager.checkStoragePermission(
      context,
    );
    if (hasPermission) {
      final subtitlesLoaded = await _loadSubtitles(widget.videoPath);
      if (!subtitlesLoaded) {
        debugPrint('⚠️ Permission granted but no subtitles found');
      }
    } else {
      debugPrint(
        '❌ Storage permission not available, skipping subtitle loading',
      );
      // Don't show error message to user - it's a normal condition
    }
  }

  Future<bool> _loadSubtitles(String videoPath) async {
    // No artificial delay needed
    try {
      // First try to find subtitles directly, without service
      final possibleSubtitlePaths = [
        '${p.withoutExtension(videoPath)}.srt',
        '${p.withoutExtension(videoPath)}.en.srt',
        '${p.withoutExtension(videoPath)}.eng.srt',
        '${p.dirname(videoPath)}/${p.basenameWithoutExtension(videoPath)}.srt',
        '${p.dirname(videoPath)}/subs/${p.basenameWithoutExtension(videoPath)}.srt',
      ];

      File? subtitleFile;

      // Try each possible path
      for (final path in possibleSubtitlePaths) {
        final file = File(path);
        if (await file.exists()) {
          debugPrint('✅ Found subtitle file at: $path');
          subtitleFile = file;
          break;
        }
      }

      // If not found directly, try the subtitle service
      if (subtitleFile == null) {
        subtitleFile = await SubtitleService.getOrDownloadSubtitle(
          videoPath,
          context: context,
        );
      }

      if (subtitleFile == null || !await subtitleFile.exists()) {
        debugPrint('❌ No subtitle file available.');
        return false;
      }

      final lines = await subtitleFile.readAsLines();
      final entries = <_SubtitleEntry>[];
      var buffer = <String>[];
      Duration? start, end;

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) {
          if (start != null && end != null && buffer.isNotEmpty) {
            entries.add(_SubtitleEntry(start, end, buffer.join('\n')));
          }
          start = end = null;
          buffer.clear();
        } else if (line.contains('-->')) {
          final parts = line.split('-->');
          start = _parseSrtTime(parts[0].trim());
          end = _parseSrtTime(parts[1].trim());
        } else if (int.tryParse(line) == null) {
          buffer.add(line);
        }
      }

      if (start != null && end != null && buffer.isNotEmpty) {
        entries.add(_SubtitleEntry(start, end, buffer.join('\n')));
      }

      debugPrint('✅ Loaded ${entries.length} subtitle entries');
      if (mounted) {
        setState(() => _subtitles = entries);
      }
      return entries.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error loading subtitles: $e');
      return false;
    }
  }

  Duration _parseSrtTime(String time) {
    final parts = time.split(RegExp('[:,]'));
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(parts[2]),
      milliseconds: int.parse(parts[3]),
    );
  }

  String? get _currentSubtitle {
    if (!_subtitlesEnabled || _subtitles.isEmpty) return null;
    final pos = _videoController.value.position;
    for (var e in _subtitles) {
      if (pos >= e.start && pos <= e.end) return e.text;
    }
    return null;
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDragging && mounted) setState(() => _showControls = false);
    });
  }

  void _togglePlayPause() {
    final video = _videoController;
    setState(() {
      video.value.isPlaying ? video.pause() : video.play();
      _centerIcon = video.value.isPlaying ? Icons.pause : Icons.play_arrow;
      _showControls = true;
    });
    _fadeController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _fadeController.reverse();
    });
    _startHideTimer();
  }

  void _seekRelative(Duration offset) {
    final video = _videoController;
    final newPos = video.value.position + offset;
    final duration = video.value.duration;

    final clamped =
        newPos < Duration.zero
            ? Duration.zero
            : (newPos > duration ? duration : newPos);

    video.seekTo(clamped);
    setState(() {
      _centerIcon = offset.isNegative ? Icons.fast_rewind : Icons.fast_forward;
      _showControls = true;
    });
    _fadeController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _fadeController.reverse();
    });
    _startHideTimer();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours.toString()}:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _chewieController?.dispose();
    _videoController.dispose();
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _videoController;
    if (_chewieController == null || !video.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
            _showControls ? _startHideTimer() : _hideTimer?.cancel();
          });
        },
        onDoubleTap: _togglePlayPause,
        onDoubleTapDown: (details) {
          final w = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < w / 3) {
            _seekRelative(const Duration(seconds: -10));
          } else if (details.globalPosition.dx > 2 * w / 3) {
            _seekRelative(const Duration(seconds: 10));
          }
        },
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: video.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
            ),
            // Center feedback icon
            Center(
              child: FadeTransition(
                opacity: _fadeController,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_centerIcon, color: Colors.white, size: 50),
                ),
              ),
            ),
            // Subtitle overlay
            if (_currentSubtitle != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: _position == SubtitlePosition.bottom ? 40 : null,
                top: _position == SubtitlePosition.top ? 40 : null,
                child: Text(
                  _currentSubtitle!,
                  textAlign: TextAlign.center,
                  style: SubtitleTextStyle.defaultStyle,
                ),
              ),
            // Controls panel
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: _buildControls(video),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(VideoPlayerController video) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: [0.0, 0.2, 0.8, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Top bar with back button and title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    p.basename(widget.videoPath),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Playback controls & progress
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.replay_10,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed:
                          () => _seekRelative(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: 24),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          video.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(
                        Icons.forward_10,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed:
                          () => _seekRelative(const Duration(seconds: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProgressBar(video),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(VideoPlayerController video) {
    return Row(
      children: [
        Text(
          _formatDuration(video.value.position),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              trackHeight: 6,
              activeTrackColor: Colors.red,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
              overlayColor: Colors.white30,
            ),
            child: Slider(
              min: 0,
              max: video.value.duration.inMilliseconds.toDouble(),
              value:
                  video.value.position.inMilliseconds
                      .clamp(0, video.value.duration.inMilliseconds)
                      .toDouble(),
              onChangeStart:
                  (_) => setState(() {
                    _isDragging = true;
                    _hideTimer?.cancel();
                  }),
              onChanged: (v) => video.seekTo(Duration(milliseconds: v.toInt())),
              onChangeEnd: (_) {
                setState(() => _isDragging = false);
                _startHideTimer();
              },
            ),
          ),
        ),
        Text(
          _formatDuration(video.value.duration),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        IconButton(
          icon: Icon(
            _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
            color: _subtitlesEnabled ? Colors.white : Colors.grey,
          ),
          onPressed: () {
            setState(() => _subtitlesEnabled = !_subtitlesEnabled);
            if (_subtitlesEnabled && _subtitles.isEmpty) {
              // Try to load subtitles again if they were previously disabled
              _checkPermissionAndLoadSubtitles();
            }
          },
        ),
      ],
    );
  }
}

/// A simple container for subtitle timing & text.
class _SubtitleEntry {
  final Duration start, end;
  final String text;
  _SubtitleEntry(this.start, this.end, this.text);
}
