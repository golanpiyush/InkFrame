import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkframe/features/library/library_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'media_service.dart';

class FolderSelectionScreen extends StatefulWidget {
  final List<String> initiallyExcluded;
  const FolderSelectionScreen({
    super.key,
    required this.initiallyExcluded,
    
  });
  
  // const FolderSelectionScreen();

  @override
  State<FolderSelectionScreen> createState() => _FolderSelectionScreenState();
}

class _FolderSelectionScreenState extends State<FolderSelectionScreen> {
  List<Map<String, dynamic>> allFolders = [];
  List<String> selectedExclusions = [];
  bool isLoading = true;
  String errorMessage = '';
  bool showOnlyVideoFolders = true;
  bool sortByQuality = true;
  bool showOnlyMoviesMode = false;

  @override
  void initState() {
    super.initState();
    loadFolders();
  }

  Future<void> loadFolders() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final hasPermission = await MediaService.requestStoragePermission();
      if (!hasPermission) {
        setState(() {
          errorMessage =
              'Storage permission not granted. Please grant permissions in app settings.';
          isLoading = false;
        });
        return;
      }
      final folders = await MediaService.getAllFolders();
      setState(() {
        allFolders = folders;
        // selectedExclusions = widget.initiallyExcluded.toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading folders: $e';
        isLoading = false;
      });
    }
  }

  void toggleSelection(String path) {
    setState(() {
      if (selectedExclusions.contains(path)) {
        selectedExclusions.remove(path);
      } else {
        selectedExclusions.add(path);
      }
    });
  }

  List<Map<String, dynamic>> getFilteredFolders() {
    const qualityKeywords = [
      'webrip',
      'bdrip',
      'x264',
      'x265',
      'yify',
      'bluray',
      'brrip',
      'hdtv',
      'dvdrip',
      '1080p',
      '720p',
      '4k',
      'uhd',
      'hdrip',
    ];
    final enriched =
        allFolders.map((f) {
          final name = (f['name'] as String?) ?? '';
          final path = (f['path'] as String?) ?? '';
          final lowerName = name.toLowerCase();
          final lowerPath = path.toLowerCase();
          final hasVideo = (f['videoCount'] as int? ?? 0) > 0;
          final isQuality = qualityKeywords.any(
            (kw) => lowerName.contains(kw) || lowerPath.contains(kw),
          );
          final isExcluded = selectedExclusions.contains(path);
          return {
            'name': name,
            'path': path,
            'videoCount': f['videoCount'] as int? ?? 0,
            'isQuality': isQuality,
            'isExcluded': isExcluded,
          };
        }).toList();

    // don't show excluded here; we'll still render them so they animate out
    final filtered =
        enriched.where((f) {
          final lowerName = (f['name'] as String).toLowerCase();
          final lowerPath = (f['path'] as String).toLowerCase();
          final hasVideo = (f['videoCount'] as int) > 0;
          final isQuality = f['isQuality'] as bool;
          if (showOnlyVideoFolders) {
            return hasVideo ||
                isQuality ||
                lowerName.contains('movie') ||
                lowerName.contains('video') ||
                lowerPath.contains('/movies') ||
                lowerPath.contains('/video');
          } else if (showOnlyMoviesMode) {
            return lowerPath.contains('/movies') ||
                lowerPath.contains('/download') ||
                lowerName.contains('movies') ||
                lowerName.contains('downloads') ||
                isQuality;
          }
          return true;
        }).toList();

    if (sortByQuality) {
      filtered.sort(
        (a, b) => ((b['isQuality'] as bool) ? 1 : 0).compareTo(
          (a['isQuality'] as bool) ? 1 : 0,
        ),
      );
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final folders = getFilteredFolders();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Folder Exclusion",
          style: GoogleFonts.montserrat(), // Apply Montserrat Italic here
        ),

        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadFolders),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilters(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAbout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (errorMessage.isNotEmpty) _buildErrorBanner(),
          _buildStatsBar(folders),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: folders.length,
                      itemBuilder: (_, i) {
                        final f = folders[i];
                        return _buildFolderTile(f);
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await MediaService.saveExcludedFolders(selectedExclusions);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LibraryScreen()),
          );
        },
        icon: const Icon(Icons.save),
        label: const Text("SAVE EXCLUDED"),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                "${selectedExclusions.length} excluded",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              ),

              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => selectedExclusions.clear()),
                icon: const Icon(Icons.clear_all),
                label: Text(
                  "CLEAR ALL",
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red, // optional: text/icon color
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      color: Colors.red[100],
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.red),
            onPressed: openAppSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(List<Map<String, dynamic>> folders) {
    final qualityCount = folders.where((f) => f['isQuality'] as bool).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing ${folders.length} folders",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            "$qualityCount quality folders",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile(Map<String, dynamic> f) {
    final name = f['name'] as String;
    final path = f['path'] as String;
    final isExcluded = f['isExcluded'] as bool;
    final videoCount = f['videoCount'] as int;

    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOutCubic,
      color: isExcluded ? Colors.grey.withOpacity(0.15) : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        // 🔥 Tap Handler with Root Path Check
        onTap: () {
          if (path.trim().replaceAll(RegExp(r'/+$'), '') ==
              '/storage/emulated/0') {
            Fluttertoast.showToast(
              msg: "Root folder cannot be excluded.",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red.withOpacity(0.9),
              textColor: Colors.white,
              fontSize: 14.0,
            );
          } else {
            toggleSelection(path);
          }
        },

        leading: Icon(
          videoCount > 0 ? Icons.movie : Icons.folder,
          color: isExcluded ? Colors.grey : Colors.white,
        ),
        title: LayoutBuilder(
          builder: (context, bc) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isExcluded ? Colors.grey : Colors.white,
                    fontSize: 16,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.linear,
                    height: 2,
                    width: isExcluded ? bc.maxWidth : 0,
                    color: Colors.grey,
                  ),
                ),
              ],
            );
          },
        ),
        subtitle: Text(
          path,
          style: TextStyle(
            decoration:
                isExcluded ? TextDecoration.lineThrough : TextDecoration.none,
            color: isExcluded ? Colors.grey : Colors.white24,
            fontSize: 12,
          ),
        ),
        trailing: Transform.scale(
          scale: 1.3,
          child: Checkbox(
            value: isExcluded,
            onChanged: (_) {
              if (path.trim().replaceAll(RegExp(r'/+$'), '') ==
                  '/storage/emulated/0') {
                Fluttertoast.showToast(
                  msg: "Root folder cannot be excluded.",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.9),
                  textColor: Colors.white,
                  fontSize: 14.0,
                );
              } else {
                toggleSelection(path);
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(
              color:
                  isExcluded
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
            ),
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  void _showFilters(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c2, setM) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Filter Options",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SwitchListTile(
                        title: const Text("Show only video folders"),
                        value: showOnlyVideoFolders,
                        onChanged: (value) {
                          setM(() => showOnlyVideoFolders = value);
                          setState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: const Text("Sort by quality"),
                        value: sortByQuality,
                        onChanged: (value) {
                          setM(() => sortByQuality = value);
                          setState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: const Text("Show only movies folders"),
                        value: showOnlyMoviesMode,
                        onChanged: (value) {
                          setM(() => showOnlyMoviesMode = value);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        child: const Text(
                          "Close Filters",
                          style: TextStyle(
                            color: Colors.black, // Set the text color to white
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("How it works?"),
            content: const Text(
              "This screen allows you to exclude certain folders from the media scan. "
              "You can filter folders by type, such as video or movie folders, "
              "and choose to sort by quality.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }
}
