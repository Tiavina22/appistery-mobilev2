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
      DateTime.now().difference(startTime);

      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? response.data as List;
        final stories = data
            .map((story) => Story.fromJson(story as Map<String, dynamic>))
            .toList();
        DateTime.now().difference(startTime);
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
         final story = Story.fromJson(data as Map<String, dynamic>);
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
      await _dio.post(
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
      await _dio.delete(
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

  // Maps multilingues brutes (pour le switch de langue)
  final Map<String, String> titleMap;
  final Map<String, String> synopsisMap;

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
    this.titleMap = const {},
    this.synopsisMap = const {},
  });

  /// Mapping des codes de locale vers les clés JSONB backend
  static String _localeToKey(String localeCode) {
    switch (localeCode) {
      case 'mg':
        return 'gasy';
      case 'fr':
        return 'fr';
      case 'en':
        return 'en';
      default:
        return 'gasy';
    }
  }

  /// Noms affichables des langues
  static String languageDisplayName(String key) {
    switch (key) {
      case 'gasy':
        return 'Malagasy';
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      default:
        return key;
    }
  }

  /// Liste des langues disponibles pour cette histoire
  List<String> get availableLanguages {
    final langs = <String>{};
    for (final key in titleMap.keys) {
      if (titleMap[key] != null && titleMap[key]!.isNotEmpty) {
        langs.add(key);
      }
    }
    // Ajouter aussi les langues du synopsis
    for (final key in synopsisMap.keys) {
      if (synopsisMap[key] != null && synopsisMap[key]!.isNotEmpty) {
        langs.add(key);
      }
    }
    return langs.toList();
  }

  /// Obtenir le titre dans une langue donnée (localeCode: mg, fr, en)
  String getTitle(String localeCode) {
    final key = _localeToKey(localeCode);
    return titleMap[key] ?? titleMap['gasy'] ?? titleMap['fr'] ?? titleMap['en'] ?? title;
  }

  /// Obtenir la description/synopsis dans une langue donnée
  String getDescription(String localeCode) {
    final key = _localeToKey(localeCode);
    return synopsisMap[key] ?? synopsisMap['gasy'] ?? synopsisMap['fr'] ?? synopsisMap['en'] ?? description;
  }

  /// Helper statique pour extraire du contenu multilingue (chapitres etc.)
  static String getLocalizedContent(dynamic content, String localeCode) {
    if (content is Map) {
      final key = _localeToKey(localeCode);
      return content[key]?.toString() ??
             content['gasy']?.toString() ??
             content['fr']?.toString() ??
             content['en']?.toString() ??
             content.values.firstOrNull?.toString() ?? '';
    }
    return content?.toString() ?? '';
  }

  factory Story.fromJson(Map<String, dynamic> json) {
    // Conserver les maps multilingues brutes
    Map<String, String> titleMap = {};
    Map<String, String> synopsisMap = {};

    // Gérer le titre qui peut être un string ou un JSON avec des langues
    String title = 'Unknown';
    if (json['title'] is String) {
      title = json['title'];
      titleMap = {'gasy': title};
    } else if (json['title'] is Map) {
      final rawMap = json['title'] as Map;
      for (final entry in rawMap.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          titleMap[entry.key.toString()] = entry.value.toString();
        }
      }
      // Par défaut : gasy d'abord
      title = titleMap['gasy'] ?? titleMap['fr'] ?? titleMap['en'] ?? 'Unknown';
    }

    // Gérer la description/synopsis
    String description = '';
    if (json['synopsis'] is String) {
      description = json['synopsis'];
      synopsisMap = {'gasy': description};
    } else if (json['synopsis'] is Map) {
      final rawMap = json['synopsis'] as Map;
      for (final entry in rawMap.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          synopsisMap[entry.key.toString()] = entry.value.toString();
        }
      }
      description = synopsisMap['gasy'] ?? synopsisMap['fr'] ?? synopsisMap['en'] ?? '';
    } else if (json['description'] is String) {
      description = json['description'];
      synopsisMap = {'gasy': description};
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
      titleMap: titleMap,
      synopsisMap: synopsisMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': titleMap.isNotEmpty ? titleMap : title,
      'synopsis': synopsisMap.isNotEmpty ? synopsisMap : description,
      'description': description,
      'cover_image': coverImage,
      'coverImage': coverImage,
      // Save author as a full object so fromJson can restore avatar/id/bio
      'author': {
        'id': authorId,
        'pseudo': author,
        'avatar': authorAvatar,
        'biography': authorBio,
        'followers_count': authorFollowers,
      },
      'author_id': authorId,
      'author_name': author,
      'genre': genre,
      'chapters': chapters,
      'chapters_count': chapters,
      'rating': rating,
      'is_favorite': isFavorite,
      'is_premium': isPremium,
      'chaptersList': chaptersList,
      'created_at': createdAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pseudo': pseudo,
      'avatar': avatar,
      'biography': biography,
    };
  }
}
