// lib/features/player/player_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkframe/features/subtitles/subtitle_style_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as p;

import '../subtitles/subtitle_service.dart';
import '../subtitles/subtitle_permission_handler.dart';
import '../subtitles/styles.dart';

class PlayerScreen extends StatefulWidget {
  final String videoPath;
  const PlayerScreen({super.key, required this.videoPath});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  late AnimationController _fadeController;
  // State fields you’ll need:
  late Offset _normalizedOffset;
  late Offset _startTranslate;
  late double _startScale;

  static const _prefsKey = 'subtitle_style_config';

  bool _showControls = true;
  IconData _centerIcon = Icons.play_arrow;
  Timer? _hideTimer;
  Timer? _progressTimer;
  bool _isDragging = false;

  // Zoom and pan management
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _translate = Offset.zero;
  Offset _previousTranslate = Offset.zero;

  // Subtitle state
  List<_SubtitleEntry> _subtitles = [];
  bool _subtitlesEnabled = true;
  final SubtitlePosition _position = SubtitlePosition.bottom;
  // Above initState():
  SubtitleStyleConfig _subtitleStyleConfig = SubtitleStyleService.defaultConfig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Set to fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _initializePlayer();
    _loadSavedSubtitleConfig();
  }

  Future<void> _initializePlayer() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath));
    await _videoController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      showControls: false,
    );

    _videoController.addListener(() {
      // Save position when video reaches end or if paused
      if (_videoController.value.position >= _videoController.value.duration) {
        setState(() {
          _videoController.pause();
          _videoController.seekTo(Duration.zero);
          _savePlaybackPosition(
            widget.videoPath,
          ); // Save position when video ends
        });
      }

      // Save playback position on periodic update
      if (_videoController.value.isPlaying && !(_isDragging)) {
        _savePlaybackPosition(widget.videoPath);
      }
    });

    setState(() {});

    _startProgressTimer();
    _checkPermissionAndLoadSubtitles();
    _loadPlaybackPosition(widget.videoPath);
    clearSubtitleCache(); // Load last position for this video
  }

  Future<void> _loadSavedSubtitleConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      try {
        final cfg = SubtitleStyleConfig.fromJson(json);
        setState(() => _subtitleStyleConfig = cfg);
      } catch (_) {
        // ignore parse errors
      }
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _videoController.value.isInitialized) {
        setState(() {});
      }
    });
  }

  // Reset zoom and pan
  void _resetZoomAndPan() {
    setState(() {
      _scale = 1.0;
      _translate = Offset.zero;
      _previousScale = 1.0;
      _previousTranslate = Offset.zero;
    });
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

  Future<void> _openSubtitleEditor() async {
    _videoController.pause();

    // Temporarily save the current subtitle style configuration
    SubtitleStyleConfig tempConfig = _subtitleStyleConfig;

    // Set the initial state of background color to transparent (disabled)
    bool disableBg = tempConfig.backgroundColor == Colors.transparent;

    final fonts = [
      'Roboto',
      'Lato',
      'Open Sans',
      'Montserrat',
      'Oswald',
      'Cinzel',
      'EB Garamond',
      'Cormorant Garamond',
      'Merriweather',
      'Playfair Display',
      'Raleway',
      'DM Serif Display',
      'Noto Serif',
      'Alegreya',
      'Crimson Text',
      'Cardo',
      'Arvo',
      'Libre Baskerville',
      'Tinos',
      'Josefin Slab',
      'Bitter',
      'PT Serif',
      'Noto Serif Display',
      'Yeseva One',
      'Marcellus',
      'Zilla Slab',
      'Old Standard TT',
      'Alice',
    ];

    final result = await showDialog<SubtitleStyleConfig>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: FractionallySizedBox(
            widthFactor: 0.9,
            heightFactor: 0.8,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (c, setEditorState) {
                  return Column(
                    children: [
                      Text(
                        'Subtitle Settings',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Font:'),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: tempConfig.fontFamily,
                                      items:
                                          fonts.map((f) {
                                            return DropdownMenuItem(
                                              value: f,
                                              child: Text(
                                                f,
                                                style: GoogleFonts.getFont(f),
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (v) {
                                        setEditorState(() {
                                          tempConfig = tempConfig.copyWith(
                                            fontFamily: v!,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              SwitchListTile(
                                title: const Text('Bold'),
                                value: tempConfig.isBold,
                                onChanged:
                                    (v) => setEditorState(() {
                                      tempConfig = tempConfig.copyWith(
                                        isBold: v,
                                      );
                                    }),
                              ),
                              SwitchListTile(
                                title: const Text('Italic'),
                                value: tempConfig.isItalic,
                                onChanged:
                                    (v) => setEditorState(() {
                                      tempConfig = tempConfig.copyWith(
                                        isItalic: v,
                                      );
                                    }),
                              ),
                              const Divider(),
                              Text('Font Size: ${tempConfig.fontSize.toInt()}'),
                              Slider(
                                min: 12,
                                max: 32,
                                divisions: 10,
                                value: tempConfig.fontSize,
                                onChanged:
                                    (v) => setEditorState(() {
                                      tempConfig = tempConfig.copyWith(
                                        fontSize: v,
                                      );
                                    }),
                              ),
                              const Divider(),
                              const Text('Text Color'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children:
                                    [
                                      Colors.white, // Default color: white
                                      Colors.yellow,
                                      Colors.red,
                                      Colors.green,
                                      Colors.blue,
                                    ].map((c) {
                                      final selected =
                                          tempConfig.textColor == c;
                                      return GestureDetector(
                                        onTap: () {
                                          setEditorState(() {
                                            tempConfig = tempConfig.copyWith(
                                              textColor: c,
                                            );
                                          });
                                        },
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                            border:
                                                selected
                                                    ? Border.all(
                                                      color: Colors.blueAccent,
                                                      width: 2,
                                                    )
                                                    : null,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Background Color'),
                                  TextButton(
                                    onPressed: () {
                                      setEditorState(() {
                                        disableBg = !disableBg;
                                        tempConfig = tempConfig.copyWith(
                                          backgroundColor:
                                              disableBg
                                                  ? Colors.transparent
                                                  : Colors.black54,
                                        );
                                      });
                                    },
                                    child: Text(
                                      disableBg ? 'Enable BG' : 'Disable BG',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (!disableBg)
                                Wrap(
                                  spacing: 8,
                                  children:
                                      [
                                        Colors.black54,
                                        Colors.black87,
                                        Colors.white54,
                                        Colors.blueGrey,
                                      ].map((c) {
                                        final selected =
                                            tempConfig.backgroundColor == c;
                                        return GestureDetector(
                                          onTap:
                                              () => setEditorState(() {
                                                tempConfig = tempConfig
                                                    .copyWith(
                                                      backgroundColor: c,
                                                    );
                                              }),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                              border:
                                                  selected
                                                      ? Border.all(
                                                        color:
                                                            Colors.blueAccent,
                                                        width: 2,
                                                      )
                                                      : null,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(ctx, null),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            child: const Text('Save'),
                            onPressed: () => Navigator.pop(ctx, tempConfig),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _subtitleStyleConfig = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, result.toJson());
    }

    _videoController.play();
  }

  // Clear subtitle cache for testing
  Future<void> clearSubtitleCache() async {
    final cacheDir = await SubtitleService.getSubtitleCacheDir();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      debugPrint('🧹 Subtitle cache cleared');
      // Fluttertoast.showToast(msg: 'Subtitle cache cleared');
    }
  }

  // Add this helper method to save subtitle config
  Future<void> _saveSubtitleConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _subtitleStyleConfig.toJson());
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
      subtitleFile ??= await SubtitleService.getOrDownloadSubtitle(
          videoPath,
          context: context,
        );

      if (subtitleFile == null || !await subtitleFile.exists()) {
        debugPrint('❌ No subtitle file available.');
        return false;
      }

      final lines = await subtitleFile.readAsLines();
      final entries = <_SubtitleEntry>[];
      var buffer = <String>[];
      Duration? start, end;

      // More comprehensive regex to capture unwanted subtitle formatting
      final unwantedRegex = RegExp(
        r'\\[an]\d+|<i>|<\/i>|\\N|{\\.*}|<.*?>', // Remove \an, <i>, </i>, \N, { ... }, and any HTML tags
      );

      for (var line in lines) {
        line = line.trim();

        // Filter out unwanted formatting
        line = line.replaceAll(unwantedRegex, '').trim();

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
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    _fadeController.dispose();
    _chewieController?.dispose();
    _videoController.dispose();
    _hideTimer?.cancel();
    _progressTimer?.cancel();

    // Reset to default orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null || !_videoController.value.isInitialized) {
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Pinch to Zoom Gesture Detector
            GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: Stack(
                children: [
                  // Transformed Video Player
                  Center(
                    child: Transform(
                      transform:
                          Matrix4.identity()
                            ..scale(_scale)
                            ..translate(_translate.dx, _translate.dy),
                      child: AspectRatio(
                        aspectRatio: _videoController.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
                    ),
                  ),

                  // Zoom Level Indicator
                  if (_scale > 1.0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Zoom: ${(_scale * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Subtitle Overlay
            if (_currentSubtitle != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: _position == SubtitlePosition.bottom ? 40 : null,
                top: _position == SubtitlePosition.top ? 40 : null,
                child: Text(
                  _currentSubtitle!,
                  textAlign: TextAlign.center,
                  style: SubtitleStyleService.generateTextStyle(
                    _subtitleStyleConfig,
                  ),
                ),
              ),

            // Controls Overlay
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  // Pinch to Zoom Handlers
  void _onScaleStart(ScaleStartDetails details) {
    // Record starting values
    _startScale = _scale;
    _startTranslate = _translate;

    // Convert the global focal point to local coordinates inside our video box
    final box = context.findRenderObject() as RenderBox;
    final focalLocal = box.globalToLocal(details.focalPoint);

    // Compute the “normalized” offset, i.e. where that focal point sits in the video’s coordinate system
    _normalizedOffset = (focalLocal - _startTranslate) / _startScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final focalLocal = box.globalToLocal(details.focalPoint);

    // 1) Compute new scale
    final newScale = (_startScale * details.scale).clamp(1.0, 4.0);

    // 2) Compute translation so that the content scales around the focal point:
    //    newTranslate + normalizedOffset * newScale = focalLocal
    final newTranslate = focalLocal - _normalizedOffset * newScale;

    setState(() {
      _scale = newScale;
      _translate = _clampTranslate(newTranslate);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_scale < 1.01) {
      _resetZoomAndPan();
    }
  }

  // _clampTranslate stays the same as before
  Offset _clampTranslate(Offset offset) {
    if (_scale <= 1.0) return Offset.zero;
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final videoAspect = _videoController.value.aspectRatio;
    final videoWidth = size.width;
    final videoHeight = videoWidth / videoAspect;
    final maxDx = ((_scale - 1) * videoWidth) / 2;
    final maxDy = ((_scale - 1) * videoHeight) / 2;

    return Offset(
      offset.dx.clamp(-maxDx, maxDx),
      offset.dy.clamp(-maxDy, maxDy),
    );
  }

  // Build progress bar widget
  // Update the _buildProgressBar widget
  Widget _buildProgressBar() {
    if (!_videoController.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final currentPosition = _videoController.value.position;
    final totalDuration = _videoController.value.duration;

    return Row(
      children: [
        Text(
          _formatDuration(currentPosition),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: currentPosition.inMilliseconds.toDouble(),
              min: 0,
              max: totalDuration.inMilliseconds.toDouble(),
              onChangeStart: (_) {
                setState(() => _isDragging = true);
                _videoController.pause();
              },
              onChanged:
                  (value) => _videoController.seekTo(
                    Duration(milliseconds: value.toInt()),
                  ),
              onChangeEnd: (value) {
                setState(() => _isDragging = false);
                _videoController.play();
                _startHideTimer();
              },
            ),
          ),
        ),
        // Modified duration display with subtitle size controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(totalDuration),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            IconButton(
              icon: const Icon(Icons.remove, size: 16, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _subtitleStyleConfig = _subtitleStyleConfig.copyWith(
                    fontSize: math.max(12, _subtitleStyleConfig.fontSize - 1),
                  );
                });
                _saveSubtitleConfig();
              },
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _subtitleStyleConfig = _subtitleStyleConfig.copyWith(
                    fontSize: math.min(32, _subtitleStyleConfig.fontSize + 1),
                  );
                });
                _saveSubtitleConfig();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls() {
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
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
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
                // Subtitle Editor Button
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Edit Subtitles',
                  onPressed: _openSubtitleEditor,
                ),

                // <<-- Subtitles Toggle Button -->
                IconButton(
                  icon: Icon(
                    _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
                    color: Colors.white,
                  ),
                  tooltip:
                      _subtitlesEnabled ? 'Hide Subtitles' : 'Show Subtitles',
                  onPressed: () {
                    setState(() {
                      _subtitlesEnabled = !_subtitlesEnabled;
                    });
                  },
                ),

                // Reset Zoom Button (only visible if zoomed)
                if (_scale > 1.0)
                  IconButton(
                    icon: const Icon(Icons.zoom_out_map, color: Colors.white),
                    onPressed: _resetZoomAndPan,
                  ),
              ],
            ),
          ),
          const Spacer(),
          // Playback controls
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
                          _videoController.value.isPlaying
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
                _buildProgressBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePlaybackPosition(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      'last_playback_position_$videoPath',
      _videoController.value.position.inSeconds.toDouble(),
    );
  }

  Future<void> _loadPlaybackPosition(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final lastPosition =
        prefs.getDouble('last_playback_position_$videoPath') ?? 0.0;
    if (lastPosition > 0.0) {
      _videoController.seekTo(Duration(seconds: lastPosition.toInt()));
    }
  }

  // Existing helper methods (togglePlayPause, seekRelative, etc.) remain the same

  // Existing methods like _checkPermissionAndLoadSubtitles remain the same
}

// Subtitle entry class (as in previous implementation)
class _SubtitleEntry {
  final Duration start, end;
  final String text;
  _SubtitleEntry(this.start, this.end, this.text);
}
