// lib/features/subtitles/subtitle_style_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Enum to represent different subtitle styling options
enum SubtitleStyleOption {
  bold,
  italic,
  underline,
  backgroundColor,
  textColor,
  fontFamily,
}

/// Service to manage subtitle styling
class SubtitleStyleService {
  /// Default subtitle style configuration
  static SubtitleStyleConfig defaultConfig = SubtitleStyleConfig(
    textColor: Colors.white, // Default text color set to white
    backgroundColor: Colors.black54,
    isBold: false,
    isItalic: false,
    isUnderlined: false,
    fontSize: 16,
    fontFamily: 'Roboto',
  );

  /// Generate a TextStyle based on the current configuration, using Google Fonts
  static TextStyle generateTextStyle(SubtitleStyleConfig config) {
    return GoogleFonts.getFont(
      config.fontFamily,
      color: config.textColor,
      backgroundColor: config.backgroundColor,
      fontWeight: config.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: config.isItalic ? FontStyle.italic : FontStyle.normal,
      decoration:
          config.isUnderlined ? TextDecoration.underline : TextDecoration.none,
      fontSize: config.fontSize,
    );
  }

  /// Update a specific style option
  static SubtitleStyleConfig updateStyle(
    SubtitleStyleConfig currentConfig,
    SubtitleStyleOption option,
    dynamic value,
  ) {
    switch (option) {
      case SubtitleStyleOption.bold:
        return currentConfig.copyWith(isBold: value as bool);
      case SubtitleStyleOption.italic:
        return currentConfig.copyWith(isItalic: value as bool);
      case SubtitleStyleOption.underline:
        return currentConfig.copyWith(isUnderlined: value as bool);
      case SubtitleStyleOption.backgroundColor:
        return currentConfig.copyWith(backgroundColor: value as Color);
      case SubtitleStyleOption.textColor:
        return currentConfig.copyWith(textColor: value as Color);
      case SubtitleStyleOption.fontFamily:
        return currentConfig.copyWith(fontFamily: value as String);
    }
  }
}

/// Configuration class for subtitle styling
class SubtitleStyleConfig {
  final Color textColor;
  final Color backgroundColor;
  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final double fontSize;
  final String fontFamily;

  const SubtitleStyleConfig({
    required this.textColor,
    required this.backgroundColor,
    required this.isBold,
    required this.isItalic,
    required this.isUnderlined,
    required this.fontSize,
    required this.fontFamily,
  }) : assert(textColor != Colors.black, 'Text color cannot be black.');

  /// Create a copy of the configuration with optional overrides
  SubtitleStyleConfig copyWith({
    Color? textColor,
    Color? backgroundColor,
    bool? isBold,
    bool? isItalic,
    bool? isUnderlined,
    double? fontSize,
    String? fontFamily,
  }) {
    // Enforce the restriction that text color cannot be black
    textColor = textColor ?? this.textColor;
    if (textColor == Colors.black) {
      textColor = Colors.white; // Default to white if black is passed
    }

    return SubtitleStyleConfig(
      textColor: textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderlined: isUnderlined ?? this.isUnderlined,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  /// Convert to a simple Map for JSON encoding
  Map<String, dynamic> toMap() {
    return {
      'textColor': textColor.value,
      'backgroundColor': backgroundColor.value,
      'isBold': isBold,
      'isItalic': isItalic,
      'isUnderlined': isUnderlined,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
    };
  }

  /// Create from Map (from JSON)
  factory SubtitleStyleConfig.fromMap(Map<String, dynamic> map) {
    Color textColor = Color(map['textColor'] as int);
    if (textColor == Colors.black) {
      textColor = Colors.white; // Ensure black is not allowed
    }

    return SubtitleStyleConfig(
      textColor: textColor,
      backgroundColor: Color(map['backgroundColor'] as int),
      isBold: map['isBold'] as bool,
      isItalic: map['isItalic'] as bool,
      isUnderlined: map['isUnderlined'] as bool,
      fontSize: (map['fontSize'] as num).toDouble(),
      fontFamily: map['fontFamily'] as String,
    );
  }

  /// JSON encode
  String toJson() => json.encode(toMap());

  /// JSON decode
  factory SubtitleStyleConfig.fromJson(String source) =>
      SubtitleStyleConfig.fromMap(json.decode(source));
}
