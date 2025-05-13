import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class Actor {
  final String name;
  final String role;

  Actor({
    required this.name,
    this.role = 'N/A', // default value
  });
}

class MovieDetails {
  final String title;
  final String posterUrl;
  final String releaseYear;
  final int runtime;
  final String actors;
  final String synopsis;
  final double matchPercentage;
  final bool isMostLiked;

  MovieDetails({
    required this.title,
    required this.posterUrl,
    required this.releaseYear,
    required this.runtime,
    required this.actors,
    required this.synopsis,
    required this.matchPercentage,
    required this.isMostLiked,
  });

  // Convert MovieDetails to a Map for storing in shared preferences
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'posterUrl': posterUrl,
      'releaseYear': releaseYear,
      'runtime': runtime,
      'actors': actors,
      'synopsis': synopsis,
      'matchPercentage': matchPercentage,
      'isMostLiked': isMostLiked,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Convert Map to MovieDetails
  factory MovieDetails.fromMap(Map<String, dynamic> map) {
    return MovieDetails(
      title: map['title'],
      posterUrl: map['posterUrl'],
      releaseYear: map['releaseYear'],
      runtime: map['runtime'],
      actors: map['actors'],
      synopsis: map['synopsis'],
      matchPercentage: map['matchPercentage'],
      isMostLiked: map['isMostLiked'],
    );
  }
}

class MovieHelper {
  static const String _apiKey = '23a12e40'; // Replace with your OMDb API Key

  // Cache movie details for 7 days
  static const int cacheDuration = 7; // days

  // Fetch movie details and cache them for 7 days
  static Future<MovieDetails?> fetchMovieDetails(String query) async {
    // First, check if cached data exists
    final cachedMovieDetails = await _getCachedMovieDetails(query);
    if (cachedMovieDetails != null) {
      print('Returning cached data for $query');
      return cachedMovieDetails;
    }

    // Use regex to separate the movie title and year (if present)
    final regex = RegExp(r"^(.*?)(?:\s*(\d{4}))?$");
    final match = regex.firstMatch(query);

    if (match == null) {
      print('Error: Invalid query format');
      return null;
    }

    final title = match.group(1)?.trim() ?? '';
    final year = match.group(2);

    print('Fetching details for movie: $title');
    final url =
        'https://www.omdbapi.com/?apikey=$_apiKey&t=${Uri.encodeQueryComponent(title)}${year != null ? '&y=$year' : ''}';

    try {
      final response = await http.get(Uri.parse(url));
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        print('Error: Failed to fetch data');
        return null;
      }

      final data = json.decode(response.body);
      if (data['Response'] != 'True') {
        print('Error: ${data['Error']}');
        return null;
      }

      final movieTitle = data['Title'] ?? 'Unknown';
      String poster = data['Poster'] ?? '';

      // If the fetched poster is low resolution (e.g., 'https://someimage.com?w300'),
      // replace it with the higher quality version if it exists.
      if (poster.contains('w500')) {
        poster = poster.replaceFirst(
          'w300',
          'original',
        ); // Request the original image
      }

      final releaseYear = data['Year'] ?? 'N/A';
      final runtimeStr = data['Runtime'] ?? '0 min';
      final cast = data['Actors'] ?? 'N/A';
      final synopsis = data['Plot'] ?? 'No synopsis available';
      final imdbRatingStr = data['imdbRating'] ?? '0.0';

      // Parse runtime like "136 min" → 136
      final runtime = int.tryParse(runtimeStr.split(' ').first) ?? 0;

      // Match percentage based on IMDb rating, normalized to 0-100
      final matchPercentage = double.tryParse(imdbRatingStr) ?? 0.0;

      // Determine if the movie is most liked (rating above 7.0 as an example)
      final isMostLiked = matchPercentage >= 7.0;

      // Create movie details and cache them
      final movieDetails = MovieDetails(
        title: movieTitle,
        posterUrl: poster, // Now includes the high-quality poster URL
        releaseYear: releaseYear,
        runtime: runtime,
        actors: cast,
        synopsis: synopsis,
        matchPercentage: matchPercentage * 10, // Convert to 0-100 scale
        isMostLiked: isMostLiked,
      );

      // Cache the movie details
      await _cacheMovieDetails(query, movieDetails);

      return movieDetails;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // Cache the movie details in shared preferences
  static Future<void> _cacheMovieDetails(
    String query,
    MovieDetails movieDetails,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(query, json.encode(movieDetails.toMap()));
  }

  // Retrieve the cached movie details
  static Future<MovieDetails?> _getCachedMovieDetails(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(query);

    if (cachedData == null) {
      return null;
    }

    final Map<String, dynamic> map = json.decode(cachedData);

    // Check if the cached data is still valid (within 7 days)
    final timestamp = map['timestamp'] as int;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final differenceInDays = (currentTime - timestamp) / (1000 * 60 * 60 * 24);

    if (differenceInDays <= cacheDuration) {
      return MovieDetails.fromMap(
        map,
      ); // Return cached data if it's still valid
    } else {
      return null; // Cached data is stale, so return null
    }
  }

  static List<Actor> parseActors(String actorsString) {
    return actorsString
        .split(',')
        .map((name) => Actor(name: name.trim()))
        .toList();
  }
}
