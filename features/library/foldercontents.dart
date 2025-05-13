import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkframe/features/player/player_screen.dart';
import 'package:inkframe/shared/utils/filterwords.dart';
import 'package:inkframe/shared/utils/movie_helper.dart';
import 'package:path/path.dart' as p;

class FolderContents extends StatefulWidget {
  final String folderPath;
  const FolderContents({super.key, required this.folderPath});

  @override
  State<FolderContents> createState() => _FolderContentsState();
}

class _FolderContentsState extends State<FolderContents> {
  List<FileSystemEntity> _videoFiles = [];
  final Map<String, MovieDetails?> _movieData = {};

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  void _loadVideos() async {
    final dir = Directory(widget.folderPath);
    final files =
        dir.listSync().where((f) {
          final ext = p.extension(f.path).toLowerCase();
          return ['.mp4', '.mkv', '.avi'].contains(ext);
        }).toList();

    if (!mounted) {
      return; // Check if the widget is still mounted before calling setState
    }
    setState(() => _videoFiles = files);

    for (var file in files) {
      final queryTitle = _cleanFileName(p.basenameWithoutExtension(file.path));
      final movie = await MovieHelper.fetchMovieDetails(queryTitle);

      if (!mounted) {
        return; // Check if the widget is still mounted before calling setState
      }
      setState(() {
        _movieData[file.path] = movie;
      });
    }
  }

  String _cleanFileName(String name) {
    // Replace dots with spaces and common symbols like hyphens, underscores, and parentheses with spaces
    String cleaned = name
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'[-_()[]]+'), ' ');

    // Remove unwanted terms in brackets (e.g., [YTS])
    cleaned = cleaned.replaceAll(
      RegExp(r'\[.*?\]'),
      '',
    ); // Remove content inside brackets
    cleaned = cleaned.replaceAll(
      RegExp(r'\s{2,}'),
      ' ',
    ); // Replace multiple spaces with one

    // Remove any trailing hyphen or spaces
    cleaned = cleaned.replaceAll(
      RegExp(r'[-\s]+$'),
      '',
    ); // Removes trailing spaces or hyphen

    // Debugging: Show intermediate result
    print("Cleaned (after removing brackets and extra spaces): $cleaned");

    // Split filename into words
    List<String> words = cleaned.split(RegExp(r'\s+'));

    // Debugging: Print the list of words after cleaning
    print("Words after split: $words");

    // Filter out known junk terms (case-insensitive, whole word only)
    final filteredWords = words.where((word) {
      final lowerWord = word.toLowerCase();

      // Handle known terms like "Edition", "Anniversary", etc.
      bool isFiltered =
          FilterWords.woords.contains(lowerWord) ||
          lowerWord.contains(
            RegExp(r'\d{1,3}'),
          ) || // Remove any number-based junk terms
          lowerWord.contains('aac5') &&
              lowerWord.contains('1') || // Handle "AAC5 1" as junk term
          lowerWord == "edition" || // Handle "Edition" as junk term explicitly
          lowerWord ==
              "anniversary" || // Handle "Anniversary" as junk term explicitly
          lowerWord.contains(
            RegExp(r'\d+(MB|GB|KB)'),
          ) || // Filter out size-related terms like "1400MB"
          lowerWord.contains(RegExp(r'\d{4,}')) &&
              lowerWord.contains(
                RegExp(r'(MB|GB)'),
              ); // Filter terms like "1000MB", "4GB"

      return !isFiltered;
    });

    // Join filtered words back together into a cleaned name
    cleaned = filteredWords.join(' ');

    // Final debug print
    print("Final cleaned name: $cleaned");

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(p.basename(widget.folderPath)),
      ),
      body:
          _videoFiles.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: _videoFiles.length,
                itemBuilder: (context, index) {
                  final file = _videoFiles[index];
                  final movie = _movieData[file.path];

                  return movie != null
                      ? _buildMovieCard(movie, file.path)
                      : ListTile(
                        title: Text(
                          p.basename(file.path),
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                },
              ),
    );
  }

  Widget _buildMovieCard(MovieDetails movie, String path) {
    // Get actors list
    final List<Actor> actors = MovieHelper.parseActors(movie.actors);

    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Movie Preview Image with Overlay
          SizedBox(
            height: 400, // Increased height for the poster
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(movie.posterUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                ),

                // Navigation controls at top
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: Colors.white),
                        onPressed: () {},
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                // Movie title and info overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                movie.title.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, color: Colors.white),
                              onPressed: () {},
                              constraints: BoxConstraints(),
                              padding: EdgeInsets.all(8),
                            ),
                            IconButton(
                              icon: Icon(Icons.download, color: Colors.white),
                              onPressed: () {},
                              constraints: BoxConstraints(),
                              padding: EdgeInsets.all(8),
                            ),
                          ],
                        ),
                        // Movie info row
                        Wrap(
                          spacing: 10,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${movie.matchPercentage}% match',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              movie.releaseYear,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white30),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                'R',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '${movie.runtime}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'HD',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (movie.isMostLiked)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Most Liked',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Play button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () {
                  // Play the movie
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => PlayerScreen(
                            videoPath: path,
                          ), // Pass the path to the PlayerScreen
                    ),
                  );
                },
                icon: Icon(Icons.play_arrow),
                label: Text(
                  "Play",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // Prolog section with Montserrat font
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Prolog',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  movie.synopsis,
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Top Cast Section (Wrapped in SingleChildScrollView to avoid overflow)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Top Cast',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        actors.take(4).map((actor) {
                          return Container(
                            width: 70,
                            margin: EdgeInsets.only(right: 20.0),
                            child: Column(
                              children: [
                                // Circular actor image (placeholder)
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey.shade800,
                                  ),
                                  child: Center(
                                    child: Text(
                                      actor.name.isNotEmpty
                                          ? actor.name[0]
                                          : '?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                // Actor name
                                Text(
                                  actor.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  actor.role,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
