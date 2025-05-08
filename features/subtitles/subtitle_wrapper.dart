// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';

// class SubtitleWrapper extends StatefulWidget {
//   final VideoPlayerController videoController;
//   final File subtitleFile;
//   final double fontSize;
//   final Color textColor;
//   final Color outlineColor;
//   final double outlineWidth;

//   const SubtitleWrapper({
//     Key? key,
//     required this.videoController,
//     required this.subtitleFile,
//     this.fontSize = 16.0,
//     this.textColor = Colors.white,
//     this.outlineColor = Colors.black,
//     this.outlineWidth = 2.0,
//   }) : super(key: key);

//   @override
//   State<SubtitleWrapper> createState() => _SubtitleWrapperState();
// }

// class _SubtitleWrapperState extends State<SubtitleWrapper> {
//   List<Subtitle> _subtitles = [];
//   Subtitle? _currentSubtitle;
//   StreamSubscription? _subscription;

//   @override
//   void initState() {
//     super.initState();
//     _loadSubtitles();
//   }

//   @override
//   void dispose() {
//     _subscription?.cancel();
//     super.dispose();
//   }

//   @override
//   void didUpdateWidget(covariant SubtitleWrapper oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     // If subtitle file changed, reload subtitles
//     if (widget.subtitleFile.path != oldWidget.subtitleFile.path) {
//       _loadSubtitles();
//     }
//   }

//   Future<void> _loadSubtitles() async {
//     try {
//       final subtitleContent = await widget.subtitleFile.readAsString();
//       final result = await SubtitleUtil.parseSubtitle(subtitleContent);

//       if (result != null) {
//         setState(() {
//           _subtitles = result;
//         });

//         _setupSubtitleListener();
//       }
//     } catch (e) {
//       print('Error loading subtitles: $e');
//     }
//   }

//   void _setupSubtitleListener() {
//     _subscription?.cancel();

//     _subscription = widget.videoController.position.listen((position) {
//       if (!mounted) return;

//       final currentSubtitle = _getSubtitleForPosition(position);
//       if (currentSubtitle != _currentSubtitle) {
//         setState(() {
//           _currentSubtitle = currentSubtitle;
//         });
//       }
//     });
//   }

//   Subtitle? _getSubtitleForPosition(Duration position) {
//     for (final subtitle in _subtitles) {
//       if (position >= subtitle.start && position <= subtitle.end) {
//         return subtitle;
//       }
//     }
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_currentSubtitle == null) {
//       return SizedBox.shrink();
//     }

//     return Align(
//       alignment: Alignment.bottomCenter,
//       child: Padding(
//         padding: EdgeInsets.only(left: 24, right: 24, bottom: 50),
//         child: Stack(
//           children: [
//             // Outline/shadow for better visibility
//             ...List.generate(8, (index) {
//               final angle = index * 45 * (3.14 / 180); // Convert to radians
//               final dx = widget.outlineWidth * 0.5 * cos(angle);
//               final dy = widget.outlineWidth * 0.5 * sin(angle);

//               return Positioned(
//                 left: dx,
//                 top: dy,
//                 child: Text(
//                   _currentSubtitle!.data,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: widget.fontSize,
//                     color: widget.outlineColor,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               );
//             }),

//             // Main subtitle text
//             Text(
//               _currentSubtitle!.data,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: widget.fontSize,
//                 color: widget.textColor,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // A simple subtitle parser utility if you don't have a subtitle package
// class SubtitleUtil {
//   static Future<List<Subtitle>> parseSubtitle(String content) async {
//     final subtitles = <Subtitle>[];
//     final lines = content.split('\n');

//     int i = 0;
//     while (i < lines.length) {
//       // Skip empty lines
//       if (lines[i].trim().isEmpty) {
//         i++;
//         continue;
//       }

//       // Check if it's a number (subtitle index)
//       if (int.tryParse(lines[i].trim()) != null) {
//         i++;

//         // Next line should be the timestamp
//         if (i < lines.length) {
//           final timestamps = lines[i].split(' --> ');
//           if (timestamps.length == 2) {
//             final start = _parseTimestamp(timestamps[0].trim());
//             final end = _parseTimestamp(timestamps[1].trim());

//             i++;

//             // Collect all text lines until empty line or next subtitle index
//             String textData = '';
//             while (i < lines.length &&
//                 lines[i].trim().isNotEmpty &&
//                 int.tryParse(lines[i].trim()) == null) {
//               if (textData.isNotEmpty) {
//                 textData += ' ';
//               }
//               textData += lines[i].trim();
//               i++;
//             }

//             if (start != null && end != null) {
//               subtitles.add(
//                 Subtitle(
//                   index: subtitles.length,
//                   start: start,
//                   end: end,
//                   data: textData,
//                 ),
//               );
//             }
//           } else {
//             i++;
//           }
//         }
//       } else {
//         i++;
//       }
//     }

//     return subtitles;
//   }

//   static Duration? _parseTimestamp(String timestamp) {
//     // Format: HH:MM:SS,mmm or HH:MM:SS.mmm
//     final parts = timestamp.replaceAll(',', '.').split(':');
//     if (parts.length != 3) return null;

//     try {
//       final hours = int.parse(parts[0]);
//       final minutes = int.parse(parts[1]);

//       final secondsParts = parts[2].split('.');
//       final seconds = int.parse(secondsParts[0]);
//       final milliseconds =
//           secondsParts.length > 1
//               ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
//               : 0;

//       return Duration(
//         hours: hours,
//         minutes: minutes,
//         seconds: seconds,
//         milliseconds: milliseconds,
//       );
//     } catch (e) {
//       return null;
//     }
//   }
// }

// // Simple subtitle model class
// class Subtitle {
//   final int index;
//   final Duration start;
//   final Duration end;
//   final String data;

//   Subtitle({
//     required this.index,
//     required this.start,
//     required this.end,
//     required this.data,
//   });
// }
