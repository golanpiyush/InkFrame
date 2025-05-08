// subtitle_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SubtitleWidget extends StatefulWidget {
  final File subtitleFile;

  const SubtitleWidget({Key? key, required this.subtitleFile})
    : super(key: key);

  @override
  _SubtitleWidgetState createState() => _SubtitleWidgetState();
}

class _SubtitleWidgetState extends State<SubtitleWidget> {
  String _rawSrt = '';
  double _fontSize = 16;
  Color _fontColor = Colors.white;
  Color _bgColor = Colors.black54;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSrt();
  }

  Future<void> _loadSrt() async {
    final text = await widget.subtitleFile.readAsString();
    setState(() => _rawSrt = text);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            color: _bgColor,
            padding: EdgeInsets.all(8),
            child: Text(
              _rawSrt,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _fontSize, color: _fontColor),
            ),
          ),
          SizedBox(height: 8),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Font Size Slider
        Column(
          children: [
            Text('Font Size'),
            Slider(
              min: 12,
              max: 30,
              value: _fontSize,
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ],
        ),
        // Font Color Picker (simple toggles)
        IconButton(
          icon: Icon(Icons.format_color_text),
          onPressed: () async {
            // toggle between white & yellow for example
            setState(
              () =>
                  _fontColor =
                      _fontColor == Colors.white ? Colors.yellow : Colors.white,
            );
          },
        ),
        // Background Color Picker
        IconButton(
          icon: Icon(Icons.format_color_fill),
          onPressed: () async {
            setState(
              () =>
                  _bgColor =
                      _bgColor == Colors.black54
                          ? Colors.transparent
                          : Colors.black54,
            );
          },
        ),
        // Speed Control
        Column(
          children: [
            Text('Speed'),
            Slider(
              min: 0.5,
              max: 2.0,
              divisions: 6,
              value: _speed,
              onChanged:
                  (v) => setState(() {
                    _speed = v;
                    // implement speed change in your player
                    SystemChrome.setPreferredOrientations([]);
                  }),
            ),
          ],
        ),
      ],
    );
  }
}
