/// lib/features/library/library_screen.dart (updated)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkframe/app_global_context.dart';
import 'package:inkframe/features/library/FolderSelectionScreen.dart';
import 'package:inkframe/shared/utils/filterwords.dart';
import 'package:inkframe/shared/utils/folder_info.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'foldercontents.dart';
import 'media_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _cacheKey = 'library_folders_cache';
  static const _cacheTimestampKey = 'library_folders_cache_ts';
  static const _cacheTTL = Duration(hours: 24);
  String? _currentScanningPath;

  List<FolderInfo> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadFiles();
  }

  Future<void> _requestPermissionAndLoadFiles() async {
    setState(() => _isLoading = true);

    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      final perm = (sdk >= 33 ? Permission.photos : Permission.storage);
      if (!await perm.request().isGranted) {
        _handlePermissionDenied();
        return;
      }
    }

    await _loadFiles();
  }

  void _handlePermissionDenied() {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Storage permission required'),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    // Clear the cache
    print('Cache Cleared');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);

    // Reload all files
    await _loadFiles();

    // Show a confirmation to the user
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Library refreshed')));
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final ts = prefs.getInt(_cacheTimestampKey) ?? 0;

    try {
      // Check if the cache is still valid (e.g., 24 hours old)
      final cacheValidityDuration =
          24 * 60 * 60 * 1000; // 24 hours in milliseconds
      final isCacheValid = (now - ts) < cacheValidityDuration;

      if (isCacheValid) {
        // Use cached data if valid
        final cachedData = prefs.getString(_cacheKey);
        if (cachedData != null) {
          final List<dynamic> cachedFolders = jsonDecode(cachedData);
          _folders = cachedFolders.map((f) => FolderInfo.fromMap(f)).toList();
        }
      } else {
        // Reload data if cache is invalid
        final raw = await MediaService.getAllFolders();

        final userExcluded =
            prefs.getStringList('excluded_folders') ?? <String>[];

        final filtered =
            raw.where((f) {
              final path = (f['path'] as String? ?? '').toLowerCase();

              final isDefaultExcluded = MediaService.defaultExcludedPaths.any(
                (ex) => path.contains(ex.toLowerCase()),
              );

              final isUserExcluded = userExcluded.any((excludedPath) {
                final normExcluded = excludedPath.toLowerCase();
                if (normExcluded == '/storage/emulated/0') return false;

                return path == normExcluded ||
                    path.startsWith('$normExcluded/') ||
                    path.startsWith('$normExcluded\\');
              });

              final shouldExclude = isDefaultExcluded || isUserExcluded;
              return !shouldExclude;
            }).toList();

        // Assign the `stripTerms` to the list from the filterwords.dart file
        final stripTerms =
            FilterWords.words; // Accessing the list from filterwords.dart

        const exts = ['.mp4', '.mkv', '.avi', '.mov', '.flv', '.webm'];
        final List<FolderInfo> vids = [];

        for (final f in filtered) {
          final path = f['path'] as String;
          setState(() => _currentScanningPath = path);
          String name = f['name'] as String? ?? p.basename(path);

          // 1. Strip predefined terms (WEBRip, x264, etc.)
          for (var term in stripTerms) {
            name = name.replaceAll(
              RegExp('\\b${RegExp.escape(term)}\\b', caseSensitive: false),
              '',
            );
          }

          // 2. Remove website domains and TLDs
          name = name.replaceAll(
            RegExp(
              r'(www\.|\.com|\.org|\.net|\.gov|\.edu|\.co\.uk)',
              caseSensitive: false,
            ),
            '',
          );

          // 3. Remove square brackets and their content
          name = name.replaceAll(RegExp(r'\[.*?\]'), '');

          // 4. Clean residual formatting
          name =
              name
                  .replaceAll(
                    RegExp(r'[\._\-]+'),
                    ' ',
                  ) // Convert dots/underscores/hyphens to spaces
                  .replaceAll(
                    RegExp(r'\s{2,}'),
                    ' ',
                  ) // Collapse multiple spaces
                  .trim();

          // 5. Extract release year (e.g., 2020, 1999) from the name
          final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(name);
          String? releaseYear = yearMatch?.group(0);

          // If release year exists, we remove it from the name to show separately
          final dir = Directory(path);
          int count = 0;
          int size = 0;

          try {
            if (await dir.exists()) {
              await for (var ent in dir.list(
                recursive: false,
                followLinks: false,
              )) {
                if (ent is File &&
                    exts.contains(p.extension(ent.path).toLowerCase())) {
                  count++;
                  size += await ent.length();
                }
              }
            }
          } catch (_) {}

          if (count > 0) {
            vids.add(
              FolderInfo(
                name: name,
                path: path,
                videoCount: count,
                totalSize: size,
              ),
            );
          }
        }

        // Cache the results
        await prefs.setString(
          _cacheKey,
          jsonEncode(vids.map((f) => f.toMap()).toList()),
        );
        await prefs.setInt(_cacheTimestampKey, now);
        _folders = vids;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading folders: $e')));
    }

    setState(() {
      _isLoading = false;
      _currentScanningPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Library'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.folder_open),
            tooltip: 'Select Folders',

            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final userExcluded =
                  prefs.getStringList('excluded_folders') ?? <String>[];

              AppGlobalContext.navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder:
                      (context) => FolderSelectionScreen(
                        initiallyExcluded: userExcluded,
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Scanning directory: ',
                      style: TextStyle(fontSize: 16),
                    ),
                    if (_currentScanningPath != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          _currentScanningPath!,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _refreshData,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.1,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: _folders.length,
                    itemBuilder: (c, i) {
                      final f = _folders[i];
                      return _FolderGridItem(
                        name: f.name,
                        itemCount: f.videoCount,
                        onTap:
                            () => Navigator.push(
                              c,
                              MaterialPageRoute(
                                builder:
                                    (_) => FolderContents(folderPath: f.path),
                              ),
                            ),
                      );
                    },
                  ),
                ),
              ),
    );
  }
}

class _FolderGridItem extends StatelessWidget {
  final String name;
  final int itemCount;
  final VoidCallback onTap;

  const _FolderGridItem({
    required this.name,
    required this.itemCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext c) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A84FF), Color(0xFF007AFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(Icons.folder, size: 64, color: Colors.white70),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                Text(
                  name,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$itemCount videos',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
