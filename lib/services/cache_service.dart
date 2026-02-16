import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'story_service.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _storiesCacheKey = 'cached_stories';
  static const String _storiesTimestampKey = 'cached_stories_timestamp';
  static const String _favoritesCacheKey = 'cached_favorites';
  static const String _favoritesTimestampKey = 'cached_favorites_timestamp';
  static const String _genresCacheKey = 'cached_genres';
  static const String _genresTimestampKey = 'cached_genres_timestamp';
  static const String _authorsCacheKey = 'cached_authors';
  static const String _authorsTimestampKey = 'cached_authors_timestamp';
  
  // Durée de validité du cache (30 minutes)
  static const Duration _cacheDuration = Duration(minutes: 30);

  // Sauvegarder les stories dans le cache
  Future<void> cacheStories(List<Story> stories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storiesJson = stories.map((s) => s.toJson()).toList();
      await prefs.setString(_storiesCacheKey, jsonEncode(storiesJson));
      await prefs.setInt(
        _storiesTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Récupérer les stories du cache
  Future<List<Story>?> getCachedStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_storiesTimestampKey);
      
      // Vérifier si le cache est encore valide
      if (timestamp == null) return null;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheDuration.inMilliseconds) {
        // Cache expiré
        return null;
      }
      
      final storiesJson = prefs.getString(_storiesCacheKey);
      if (storiesJson == null) return null;
      
      final List<dynamic> decoded = jsonDecode(storiesJson);
      return decoded.map((json) => Story.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  // Sauvegarder les favoris
  Future<void> cacheFavorites(List<Story> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = favorites.map((s) => s.toJson()).toList();
      await prefs.setString(_favoritesCacheKey, jsonEncode(favoritesJson));
      await prefs.setInt(
        _favoritesTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Récupérer les favoris du cache
  Future<List<Story>?> getCachedFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_favoritesTimestampKey);
      
      if (timestamp == null) return null;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheDuration.inMilliseconds) {
        return null;
      }
      
      final favoritesJson = prefs.getString(_favoritesCacheKey);
      if (favoritesJson == null) return null;
      
      final List<dynamic> decoded = jsonDecode(favoritesJson);
      return decoded.map((json) => Story.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  // Sauvegarder les genres
  Future<void> cacheGenres(List<Map<String, dynamic>> genres) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_genresCacheKey, jsonEncode(genres));
      await prefs.setInt(
        _genresTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Récupérer les genres du cache
  Future<List<Map<String, dynamic>>?> getCachedGenres() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_genresTimestampKey);
      
      if (timestamp == null) return null;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheDuration.inMilliseconds) {
        return null;
      }
      
      final genresJson = prefs.getString(_genresCacheKey);
      if (genresJson == null) return null;
      
      final List<dynamic> decoded = jsonDecode(genresJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }

  // Sauvegarder les auteurs
  Future<void> cacheAuthors(List<Author> authors) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authorsJson = authors.map((a) => a.toJson()).toList();
      await prefs.setString(_authorsCacheKey, jsonEncode(authorsJson));
      await prefs.setInt(
        _authorsTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Récupérer les auteurs du cache
  Future<List<Author>?> getCachedAuthors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_authorsTimestampKey);
      
      if (timestamp == null) return null;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheDuration.inMilliseconds) {
        return null;
      }
      
      final authorsJson = prefs.getString(_authorsCacheKey);
      if (authorsJson == null) return null;
      
      final List<dynamic> decoded = jsonDecode(authorsJson);
      return decoded.map((json) => Author.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  // Invalider tout le cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_storiesCacheKey),
        prefs.remove(_storiesTimestampKey),
        prefs.remove(_favoritesCacheKey),
        prefs.remove(_favoritesTimestampKey),
        prefs.remove(_genresCacheKey),
        prefs.remove(_genresTimestampKey),
        prefs.remove(_authorsCacheKey),
        prefs.remove(_authorsTimestampKey),
      ]);
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Invalider seulement le cache des stories
  Future<void> invalidateStoriesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_storiesCacheKey),
        prefs.remove(_storiesTimestampKey),
      ]);
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Invalider seulement le cache des favoris
  Future<void> invalidateFavoritesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_favoritesCacheKey),
        prefs.remove(_favoritesTimestampKey),
      ]);
    } catch (e) {
      // Silencieusement échouer
    }
  }
}
