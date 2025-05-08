import 'package:flutter/material.dart';

class SettingsController extends ChangeNotifier {
  bool _darkMode = true;

  bool get darkMode => _darkMode;

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }
}
