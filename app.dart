import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inkframe/features/library/FolderSelectionScreen.dart';
import 'package:inkframe/features/library/library_screen.dart';
import 'shared/themes/app_theme.dart';
import 'app_global_context.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> hasExcludedFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final excluded = prefs.getStringList('excluded_folders');
    return excluded != null && excluded.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InkFrame',
      theme: AppTheme.darkTheme,
      navigatorKey: AppGlobalContext.navigatorKey,
      home: FutureBuilder<bool>(
        future: hasExcludedFolders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data == true) {
            return LibraryScreen(); // Already excluded folders exist
          }

          // No excluded folders → show folder selection screen
          return FolderSelectionScreen(
            initiallyExcluded: [],
            // onComplete: () async {
            //   WidgetsBinding.instance.addPostFrameCallback((_) {
            //     AppGlobalContext.navigatorKey.currentState?.pushReplacement(
            //       MaterialPageRoute(builder: (_) => LibraryScreen()),
            //     );
            //   });
            // },
          );
        },
      ),
    );
  }
}
