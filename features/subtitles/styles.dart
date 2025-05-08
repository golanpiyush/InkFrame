// lib/styles.dart
import 'package:flutter/material.dart';

class SubtitleTextStyle {
  /// Base style for your subtitles.
  static TextStyle defaultStyle = const TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.w500,
    shadows: [
      Shadow(offset: Offset(1.0, 1.0), blurRadius: 2.0, color: Colors.black87),
    ],
  );
}

enum SubtitlePosition { bottom, top }
