import 'package:flutter/material.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
      ),
      body: SwitchListTile(
        title: const Text('Dark Mode', style: TextStyle(color: Colors.white)),
        value: controller.darkMode,
        onChanged: (value) => controller.toggleDarkMode(),
      ),
    );
  }
}
