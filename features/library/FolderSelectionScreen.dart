import 'package:flutter/material.dart';
import 'package:inkframe/features/library/library_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'media_service.dart';

class FolderSelectionScreen extends StatefulWidget {
  final List<String> initiallyExcluded;

  const FolderSelectionScreen({
    super.key,
    required this.initiallyExcluded,
    required this.onComplete,
  });
  final Future<void> Function() onComplete;

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
      bool hasPermission = await MediaService.requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            errorMessage =
                'Storage permission not granted. Please grant permissions in app settings.';
            isLoading = false;
          });
        }
        return;
      }

      List<Map<String, dynamic>> folders = await MediaService.getAllFolders();

      if (mounted) {
        setState(() {
          allFolders = folders;
          selectedExclusions = widget.initiallyExcluded.toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error loading folders: $e';
          isLoading = false;
        });
      }
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

  // Update getFilteredFolders
  List<Map<String, dynamic>> getFilteredFolders() {
    if (showOnlyVideoFolders) {
      return allFolders.where((folder) {
        final name = (folder['name'] as String).toLowerCase();
        final path = (folder['path'] as String).toLowerCase();
        final hasVideo = folder['hasVideoFiles'] as bool;
        final isQuality = folder['isQualityFolder'] as bool;

        return hasVideo ||
            isQuality ||
            name.contains('movie') ||
            name.contains('video') ||
            path.contains('/movies') ||
            path.contains('/video');
      }).toList();
    } else if (showOnlyMoviesMode) {
      return allFolders.where((folder) {
        final path = (folder['path'] as String).toLowerCase();
        final name = (folder['name'] as String).toLowerCase();
        final isQuality = folder['isQualityFolder'] as bool;

        return path.contains('/movies') ||
            path.contains('/download') ||
            name.contains('movies') ||
            name.contains('downloads') ||
            isQuality;
      }).toList();
    } else {
      return allFolders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFolders = getFilteredFolders();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Folders to Exclude"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadFolders),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder:
                    (context) => StatefulBuilder(
                      builder:
                          (context, setModalState) => Container(
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
                                const SizedBox(height: 16),
                                // Inside the filter options bottom sheet
                                SwitchListTile(
                                  title: const Text("Movie Mode"),
                                  subtitle: const Text(
                                    "Show only Movies, Downloads, quality folders, and folders with large video files",
                                  ),
                                  value: showOnlyMoviesMode,
                                  onChanged: (value) {
                                    setModalState(
                                      () => showOnlyMoviesMode = value,
                                    );
                                    setState(() => showOnlyMoviesMode = value);
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text("Show only video folders"),
                                  subtitle: const Text(
                                    "Only display folders with video files or quality indicators",
                                  ),
                                  value: showOnlyVideoFolders,
                                  onChanged: (value) {
                                    setModalState(() {
                                      showOnlyVideoFolders = value;
                                    });
                                    setState(() {
                                      showOnlyVideoFolders = value;
                                    });
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text(
                                    "Sort by quality folders first",
                                  ),
                                  subtitle: const Text(
                                    "Prioritize folders with quality indicators",
                                  ),
                                  value: sortByQuality,
                                  onChanged: (value) {
                                    setModalState(() {
                                      sortByQuality = value;
                                    });
                                    setState(() {
                                      sortByQuality = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                    ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text("About Folder Selection"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Excluded folders won't be scanned for media files. "
                            "Tap on a folder to exclude or include it.",
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Folder Types:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.movie,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text("Contains video files"),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                "Bold and italic",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Quality folder (contains quality keywords)",
                              ),
                            ],
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("GOT IT"),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (errorMessage.isNotEmpty)
            Container(
              color: Colors.red[100],
              padding: const EdgeInsets.all(8),
              width: double.infinity,
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
                    onPressed: () {
                      openAppSettings();
                    },
                  ),
                ],
              ),
            ),
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Showing ${filteredFolders.length} folders",
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  "${filteredFolders.where((f) => f['isQualityFolder'] == true).length} quality folders",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredFolders.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "No folders found",
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: loadFolders,
                            child: const Text("RETRY"),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredFolders.length,
                      itemBuilder: (context, index) {
                        final folder = filteredFolders[index];
                        final path = folder['path'] as String;
                        final name = folder['name'] as String;
                        final isQualityFolder =
                            folder['isQualityFolder'] as bool;
                        final hasVideoFiles = folder['hasVideoFiles'] as bool;
                        final isExcluded = selectedExclusions.contains(path);

                        // Determine folder type for appropriate styling
                        final isMovieFolder =
                            path.contains('/Movies') ||
                            name.toLowerCase() == 'movies' ||
                            name.toLowerCase() == 'movie';
                        final isDownloadFolder =
                            path.contains('/Download') ||
                            name.toLowerCase() == 'download' ||
                            name.toLowerCase() == 'downloads';

                        Color? cardColor;
                        if (isQualityFolder) {
                          cardColor = Colors.amber.withOpacity(0.1);
                        } else if (isMovieFolder) {
                          cardColor = Colors.blue.withOpacity(0.1);
                        } else if (isDownloadFolder) {
                          cardColor = Colors.green.withOpacity(0.1);
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          color: cardColor,
                          elevation: isQualityFolder || isMovieFolder ? 2 : 1,
                          child: ListTile(
                            leading: Stack(
                              children: [
                                Icon(
                                  isMovieFolder
                                      ? Icons.movie_creation
                                      : isDownloadFolder
                                      ? Icons.download
                                      : hasVideoFiles
                                      ? Icons.movie
                                      : Icons.folder,
                                  color:
                                      isExcluded
                                          ? Colors.grey
                                          : isQualityFolder
                                          ? Colors.amber[700]
                                          : isMovieFolder
                                          ? Colors.blue[700]
                                          : isDownloadFolder
                                          ? Colors.green[700]
                                          : Theme.of(context).primaryColor,
                                  size: 28,
                                ),
                                if (isQualityFolder)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.high_quality,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: isExcluded ? Colors.grey : null,
                                        fontStyle:
                                            isQualityFolder
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                        fontWeight:
                                            isQualityFolder
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      curve: Curves.easeInOut,
                                      height: 2,
                                      width:
                                          isExcluded ? constraints.maxWidth : 0,
                                      color: Colors.grey,
                                    ),
                                  ],
                                );
                              },
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  path,
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration:
                                        isExcluded
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                    color:
                                        isExcluded
                                            ? Colors.grey
                                            : Colors.black54,
                                  ),
                                ),
                                if (isQualityFolder)
                                  Text(
                                    "Quality folder",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.amber[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Checkbox(
                              value: isExcluded,
                              activeColor:
                                  isQualityFolder ? Colors.amber[700] : null,
                              onChanged: (_) => toggleSelection(path),
                            ),
                            onTap: () => toggleSelection(path),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await MediaService.saveExcludedFolders(selectedExclusions);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LibraryScreen()),
            );
          }
        },
        icon: const Icon(Icons.save),
        label: const Text("SAVE SELECTION"),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${selectedExclusions.length} folders excluded",
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    selectedExclusions.clear();
                  });
                },
                icon: const Icon(Icons.clear_all),
                label: const Text("CLEAR ALL"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
