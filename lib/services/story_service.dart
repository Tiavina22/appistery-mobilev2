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
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
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
          return handler.next(error);
        },
      ),
    );
  }

  Future<List<Story>> getAllStories() async {
    try {
      final response = await _dio.get('/api/stories/all');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final stories = data
            .map((story) => Story.fromJson(story as Map<String, dynamic>))
            .toList();
        return stories;
      }
      throw Exception('Failed to load stories: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error loading stories: $e');
    }
  }

  Future<List<Story>> getAllStoriesPaginated({
    required int limit,
    required int offset,
  }) async {
    try {
      final startTime = DateTime.now();
      final response = await _dio.get(
        '/api/stories/all',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final networkDuration = DateTime.now().difference(startTime);

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final stories = data
            .map((story) => Story.fromJson(story as Map<String, dynamic>))
            .toList();
        final totalDuration = DateTime.now().difference(startTime);
        return stories;
      }
      throw Exception('Failed to load stories: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error loading stories: $e');
    }
  }

  Future<List<Story>> searchStories(String query) async {
    try {
      final response = await _dio.get(
        '/api/stories/search',
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final stories = data
            .map((story) => Story.fromJson(story as Map<String, dynamic>))
            .toList();
        return stories;
      }
      throw Exception('Failed to search stories: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Error searching stories: ${e.message}');
    } catch (e) {
      throw Exception('Error searching stories: $e');
    }
  }

  Future<Story> getStoryById(int id) async {
    try {
      final response = await _dio.get('/api/stories/$id');

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        print('DEBUG getStoryById: chapters in data: ${data['chapters']}');
        print('DEBUG getStoryById: Chapters in data: ${data['Chapters']}');
        print('DEBUG getStoryById: chaptersList in data: ${data['chaptersList']}');
        final story = Story.fromJson(data as Map<String, dynamic>);
        print('DEBUG getStoryById: story.chaptersList.length: ${story.chaptersList.length}');
        return story;
      }
      throw Exception('Failed to load story: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Error loading story: ${e.message}');
    } catch (e) {
      throw Exception('Error loading story: $e');
    }
  }

  Future<void> addFavorite(int storyId) async {
    try {
      final response = await _dio.post(
        '/api/stories/favorites/add',
        data: {'story_id': storyId},
      );
    } on DioException catch (e) {
      throw Exception('Error adding favorite: ${e.message}');
    } catch (e) {
      throw Exception('Error adding favorite: $e');
    }
  }

  Future<void> removeFavorite(int storyId) async {
    try {
      final response = await _dio.delete(
        '/api/stories/favorites/remove/$storyId',
      );
    } on DioException catch (e) {
      throw Exception('Error removing favorite: ${e.message}');
    } catch (e) {
      throw Exception('Error removing favorite: $e');
    }
  }

  Future<List<Story>> getFavorites() async {
    try {
      final response = await _dio.get('/api/stories/favorites');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final stories = data
            .map((story) => Story.fromJson(story as Map<String, dynamic>))
            .toList();
        return stories;
      }
      throw Exception('Failed to load favorites: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Error loading favorites: ${e.message}');
    } catch (e) {
      throw Exception('Error loading favorites: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      final response = await _dio.get('/api/stories/genres');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final genres = data
            .map((genre) => Map<String, dynamic>.from(genre as Map))
            .toList();
        return genres;
      }
      throw Exception('Failed to load genres: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Error loading genres: ${e.message}');
    } catch (e) {
      throw Exception('Error loading genres: $e');
    }
  }

  Future<List<Author>> getAuthors() async {
    try {
     
      final response = await _dio.get('/api/stories/authors');
    

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final authors = data
            .map((author) => Author.fromJson(author as Map<String, dynamic>))
            .toList();
        
        return authors;
      }
      throw Exception('Failed to load authors: ${response.statusCode}');
    } on DioException catch (e) {
     
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
  final int? authorId;
  final String? authorAvatar;
  final String? authorBio;
  final int? authorFollowers;
  final int chapters;
  final double? rating;
  final bool isFavorite;
  final bool isPremium;
  final String genre;
  final List<Map<String, dynamic>> chaptersList;
  final DateTime? createdAt;

  Story({
    required this.id,
    required this.title,
    required this.description,
    this.coverImage,
    required this.author,
    this.authorId,
    this.authorAvatar,
    this.authorBio,
    this.authorFollowers,
    required this.chapters,
    this.rating,
    this.isFavorite = false,
    this.isPremium = false,
    required this.genre,
    this.chaptersList = const [],
    this.createdAt,
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
    int? authorId;
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
      // Récupérer l'ID, l'avatar, la bio et les followers de l'auteur
      authorId = json['author']['id'];
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

    // Calculer le nombre de chapitres (chapters_count ou longueur de la liste)
    int chaptersCount = 0;
    if (json['chapters_count'] != null) {
      chaptersCount = json['chapters_count'] is int 
          ? json['chapters_count'] 
          : int.tryParse(json['chapters_count'].toString()) ?? 0;
    } else if (chaptersList.isNotEmpty) {
      chaptersCount = chaptersList.length;
    } else if (json['chapters'] is int) {
      chaptersCount = json['chapters'];
    }

    return Story(
      id: json['id'] ?? 0,
      title: title,
      description: description,
      coverImage: json['cover_image'] ?? json['coverImage'],
      author: author,
      authorId: authorId,
      authorAvatar: authorAvatar,
      authorBio: authorBio,
      authorFollowers: authorFollowers,
      chapters: chaptersCount,
      rating: json['rating']?.toDouble(),
      isFavorite: json['is_favorite'] ?? false,
      isPremium: json['is_premium'] ?? false,
      genre: genre,
      chaptersList: chaptersList,
      createdAt: json['created_at'] != null || json['createdAt'] != null
          ? DateTime.tryParse(json['created_at'] ?? json['createdAt'])
          : null,
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
