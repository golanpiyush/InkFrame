import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:inkframe/features/library/foldercontents.dart';
import 'package:inkframe/features/library/media_service.dart';
import 'package:permission_handler/permission_handler.dart';

class LibraryScreen extends StatefulWidget {
  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
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

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    try {
      final raw = await MediaService.getAllFolders();
      final filtered = raw.where((f) {
        final path = f['path'] as String? ?? '';
        return !MediaService.defaultExcludedPaths.any(
          (ex) => path.contains(ex),
        );
      });

      const exts = ['.mp4', '.mkv', '.avi', '.mov', '.flv', '.webm'];
      final List<FolderInfo> vids = [];

      for (final f in filtered) {
        final path = f['path'] as String;
        final name = f['name'] as String? ?? p.basename(path);
        final dir = Directory(path);
        int count = 0;

        try {
          if (await dir.exists()) {
            await for (final ent in dir.list(
              recursive: false,
              followLinks: false,
            )) {
              if (ent is File &&
                  exts.contains(p.extension(ent.path).toLowerCase())) {
                count++;
              }
            }
          }
        } catch (_) {
          // skip unreadable dirs
        }

        if (count > 0) {
          vids.add(FolderInfo(name: name, path: path, videoCount: count));
        }
      }

      setState(() {
        _folders = vids;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading folders: $e')));
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: Text('Library'), elevation: 0),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
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
    );
  }
}

class FolderInfo {
  final String name;
  final String path;
  final int videoCount;
  FolderInfo({
    required this.name,
    required this.path,
    required this.videoCount,
  });
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$itemCount videos',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
