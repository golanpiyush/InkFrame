import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inkframe/features/library/FolderSelectionScreen.dart';
import 'package:inkframe/features/library/library_screen.dart';
import 'shared/themes/app_theme.dart';
import 'app_global_context.dart'; // <-- Add this import

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> hasCompletedFolderSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('folder_selection_completed') ?? false;
  }

  Future<void> setFolderSelectionCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('folder_selection_completed', true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InkFrame',
      theme: AppTheme.darkTheme,
      navigatorKey:
          AppGlobalContext.navigatorKey, // <-- Set the global navigatorKey
      home: FutureBuilder<bool>(
        future: hasCompletedFolderSelection(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data == true) {
            return LibraryScreen();
          }

          return FolderSelectionScreen(
            initiallyExcluded: [],
            onComplete: () async {
              await setFolderSelectionCompleted();
              AppGlobalContext.navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (_) => LibraryScreen()),
              );
            },
          );
        },
      ),
    );
  }
}
