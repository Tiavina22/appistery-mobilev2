import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoryService {
  late final Dio _dio;
  final String apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:5000';
  static const _secureStorage = FlutterSecureStorage();

  StoryService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: apiUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Ajouter un interceptor pour l'authentification
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          print('Dio Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  Future<List<Story>> getAllStories() async {
    try {
      print('DEBUG: Fetching stories from $apiUrl/api/stories/all');
      final response = await _dio.get('/api/stories/all');
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final stories = data
            .map((story) => Story.fromJson(story as Map<String, dynamic>))
            .toList();
        print('DEBUG: Parsed ${stories.length} stories');
        return stories;
      }
      throw Exception('Failed to load stories: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException - ${e.message}');
      print('DEBUG: Error type: ${e.type}');
      print('DEBUG: Error response: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('DEBUG: Unknown error - $e');
      throw Exception('Error loading stories: $e');
    }
  }

  Future<List<Story>> searchStories(String query) async {
    try {
      print('DEBUG: Searching stories with query: $query');
      final response = await _dio.get(
        '/api/stories/search',
        queryParameters: {'q': query},
      );
      print('DEBUG: Search response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final stories = data
            .map((story) => Story.fromJson(story as Map<String, dynamic>))
            .toList();
        print('DEBUG: Parsed ${stories.length} search results');
        return stories;
      }
      throw Exception('Failed to search stories: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException searching - ${e.message}');
      throw Exception('Error searching stories: ${e.message}');
    } catch (e) {
      throw Exception('Error searching stories: $e');
    }
  }

  Future<Story> getStoryById(int id) async {
    try {
      print('DEBUG: Fetching story with ID: $id');
      final response = await _dio.get('/api/stories/$id');
      print('DEBUG: Story response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final story = Story.fromJson(data as Map<String, dynamic>);
        print('DEBUG: Parsed story: ${story.title}');
        return story;
      }
      throw Exception('Failed to load story: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException getting story - ${e.message}');
      throw Exception('Error loading story: ${e.message}');
    } catch (e) {
      throw Exception('Error loading story: $e');
    }
  }

  Future<void> addFavorite(int storyId) async {
    try {
      print('DEBUG: Adding favorite for story $storyId');
      final response = await _dio.post(
        '/api/stories/favorites/add',
        data: {'story_id': storyId},
      );
      print('DEBUG: Add favorite response: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException adding favorite - ${e.message}');
      throw Exception('Error adding favorite: ${e.message}');
    } catch (e) {
      throw Exception('Error adding favorite: $e');
    }
  }

  Future<void> removeFavorite(int storyId) async {
    try {
      print('DEBUG: Removing favorite for story $storyId');
      final response = await _dio.delete(
        '/api/stories/favorites/remove/$storyId',
      );
      print('DEBUG: Remove favorite response: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException removing favorite - ${e.message}');
      throw Exception('Error removing favorite: ${e.message}');
    } catch (e) {
      throw Exception('Error removing favorite: $e');
    }
  }

  Future<List<Story>> getFavorites() async {
    try {
      print('DEBUG: Fetching favorites from $apiUrl/api/stories/favorites');
      final response = await _dio.get('/api/stories/favorites');
      print('DEBUG: Favorites response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final stories = data
            .map((story) => Story.fromJson(story as Map<String, dynamic>))
            .toList();
        print('DEBUG: Parsed ${stories.length} favorite stories');
        return stories;
      }
      throw Exception('Failed to load favorites: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException getting favorites - ${e.message}');
      throw Exception('Error loading favorites: ${e.message}');
    } catch (e) {
      throw Exception('Error loading favorites: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      print('DEBUG: Fetching genres from $apiUrl/api/stories/genres');
      final response = await _dio.get('/api/stories/genres');
      print('DEBUG: Genres response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final genres = data
            .map((genre) => Map<String, dynamic>.from(genre as Map))
            .toList();
        print('DEBUG: Parsed ${genres.length} genres');
        return genres;
      }
      throw Exception('Failed to load genres: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException getting genres - ${e.message}');
      throw Exception('Error loading genres: ${e.message}');
    } catch (e) {
      throw Exception('Error loading genres: $e');
    }
  }

  Future<List<Author>> getAuthors() async {
    try {
      print('DEBUG: Fetching authors from $apiUrl/api/stories/authors');
      final response = await _dio.get('/api/stories/authors');
      print('DEBUG: Authors response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final authors = data
            .map((author) => Author.fromJson(author as Map<String, dynamic>))
            .toList();
        print('DEBUG: Parsed ${authors.length} authors');
        return authors;
      }
      throw Exception('Failed to load authors: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException getting authors - ${e.message}');
      throw Exception('Error loading authors: ${e.message}');
    } catch (e) {
      throw Exception('Error loading authors: $e');
    }
  }
}

class Story {
  final int id;
  final String title;
  final String description;
  final String? coverImage;
  final String author;
  final String? authorAvatar;
  final String? authorBio;
  final int? authorFollowers;
  final int chapters;
  final double? rating;
  final bool isFavorite;
  final String genre;
  final List<Map<String, dynamic>> chaptersList;

  Story({
    required this.id,
    required this.title,
    required this.description,
    this.coverImage,
    required this.author,
    this.authorAvatar,
    this.authorBio,
    this.authorFollowers,
    required this.chapters,
    this.rating,
    this.isFavorite = false,
    required this.genre,
    this.chaptersList = const [],
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    // Gérer le titre qui peut être un string ou un JSON avec des langues
    String title = 'Unknown';
    if (json['title'] is String) {
      title = json['title'];
    } else if (json['title'] is Map) {
      final titleMap = json['title'] as Map;
      title = titleMap['fr'] ?? titleMap['en'] ?? titleMap['gasy'] ?? 'Unknown';
    }

    // Gérer la description/synopsis
    String description = '';
    if (json['synopsis'] is String) {
      description = json['synopsis'];
    } else if (json['synopsis'] is Map) {
      final synopsisMap = json['synopsis'] as Map;
      description =
          synopsisMap['fr'] ?? synopsisMap['en'] ?? synopsisMap['gasy'] ?? '';
    } else if (json['description'] is String) {
      description = json['description'];
    }

    // Gérer l'auteur qui peut être un string ou un objet
    String author = 'Unknown';
    String? authorAvatar;
    String? authorBio;
    int? authorFollowers;
    if (json['author'] is String) {
      author = json['author'];
    } else if (json['author'] is Map) {
      // Afficher le pseudo d'abord, sinon fallback sur email ou biography
      author =
          json['author']['pseudo'] ??
          json['author']['email'] ??
          json['author']['biography'] ??
          'Unknown';
      // Récupérer l'avatar, la bio et les followers de l'auteur
      authorAvatar = json['author']['avatar'];
      authorBio = json['author']['biography'];
      authorFollowers =
          json['author']['followers_count'] ?? json['author']['followersCount'];
    } else if (json['author_name'] is String) {
      author = json['author_name'];
    }

    // Gérer le genre
    String genre = 'Story';
    if (json['genre'] is String) {
      genre = json['genre'];
    } else if (json['genre'] is Map) {
      genre = json['genre']['title'] ?? 'Story';
    }

    // Gérer la liste des chapitres
    List<Map<String, dynamic>> chaptersList = [];
    if (json['chaptersList'] is List) {
      chaptersList = List<Map<String, dynamic>>.from(
        json['chaptersList'].map((ch) => Map<String, dynamic>.from(ch)),
      );
    } else if (json['chapters'] is List) {
      chaptersList = List<Map<String, dynamic>>.from(
        json['chapters'].map((ch) => Map<String, dynamic>.from(ch)),
      );
    } else if (json['Chapters'] is List) {
      chaptersList = List<Map<String, dynamic>>.from(
        json['Chapters'].map((ch) => Map<String, dynamic>.from(ch)),
      );
    }

    return Story(
      id: json['id'] ?? 0,
      title: title,
      description: description,
      coverImage: json['cover_image'] ?? json['coverImage'],
      author: author,
      authorAvatar: authorAvatar,
      authorBio: authorBio,
      authorFollowers: authorFollowers,
      chapters: json['chapters_count'] ?? json['chapters'] ?? 0,
      rating: json['rating']?.toDouble(),
      isFavorite: json['is_favorite'] ?? false,
      genre: genre,
      chaptersList: chaptersList,
    );
  }
}

class Author {
  final int id;
  final String pseudo;
  final String? avatar;
  final String? biography;

  Author({required this.id, required this.pseudo, this.avatar, this.biography});

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'] ?? 0,
      pseudo: json['pseudo'] ?? 'Unknown Author',
      avatar: json['avatar'],
      biography: json['biography'],
    );
  }
}
