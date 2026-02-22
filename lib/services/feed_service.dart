import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../config/api_config.dart';

class FeedItem {
  final int id;
  final String title;
  final String synopsis;
  final String? coverImage;
  final bool isPremium;
  final int chaptersCount;
  final DateTime? createdAt;
  final FeedAuthor? author;
  final FeedGenre? genre;
  final FeedReactions reactions;
  final int commentCount;

  FeedItem({
    required this.id,
    required this.title,
    required this.synopsis,
    this.coverImage,
    this.isPremium = false,
    this.chaptersCount = 0,
    this.createdAt,
    this.author,
    this.genre,
    required this.reactions,
    this.commentCount = 0,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    // Parse title
    String title = 'Sans titre';
    if (json['title'] is String) {
      title = json['title'];
    } else if (json['title'] is Map) {
      final t = json['title'] as Map;
      title = t['fr'] ?? t['en'] ?? t['gasy'] ?? 'Sans titre';
    }

    // Parse synopsis
    String synopsis = '';
    if (json['synopsis'] is String) {
      synopsis = json['synopsis'];
    } else if (json['synopsis'] is Map) {
      final s = json['synopsis'] as Map;
      synopsis = s['fr'] ?? s['en'] ?? s['gasy'] ?? '';
    }

    return FeedItem(
      id: json['id'] ?? 0,
      title: title,
      synopsis: synopsis,
      coverImage: json['cover_image'],
      isPremium: json['is_premium'] ?? false,
      chaptersCount: json['chapters_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      author: json['author'] != null
          ? FeedAuthor.fromJson(json['author'])
          : null,
      genre: json['genre'] != null
          ? FeedGenre.fromJson(json['genre'])
          : null,
      reactions: FeedReactions.fromJson(json['reactions'] ?? {}),
      commentCount: json['comments']?['total'] ?? 0,
    );
  }
}

class FeedAuthor {
  final int id;
  final String pseudo;
  final String? avatar;
  final String? biography;

  FeedAuthor({
    required this.id,
    required this.pseudo,
    this.avatar,
    this.biography,
  });

  factory FeedAuthor.fromJson(Map<String, dynamic> json) {
    return FeedAuthor(
      id: json['id'] ?? 0,
      pseudo: json['pseudo'] ?? 'Inconnu',
      avatar: json['avatar'],
      biography: json['biography'],
    );
  }
}

class FeedGenre {
  final int id;
  final String title;

  FeedGenre({required this.id, required this.title});

  factory FeedGenre.fromJson(Map<String, dynamic> json) {
    return FeedGenre(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
    );
  }
}

class FeedReactions {
  final int total;
  final Map<String, int> counts;
  final String? userReaction;

  FeedReactions({
    this.total = 0,
    this.counts = const {},
    this.userReaction,
  });

  factory FeedReactions.fromJson(Map<String, dynamic> json) {
    final countsRaw = json['counts'] as Map<String, dynamic>? ?? {};
    final counts = countsRaw.map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0));

    return FeedReactions(
      total: json['total'] ?? 0,
      counts: counts,
      userReaction: json['user_reaction'],
    );
  }
}

class FeedService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final AuthService _authService = AuthService();

  /// Fetch the activity feed (paginated)
  Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 10}) async {
    try {
      final token = await _authService.getToken();
      final options = token != null
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null;

      final response = await _dio.get(
        '/api/feed',
        queryParameters: {'page': page, 'limit': limit},
        options: options,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final items = (response.data['data'] as List)
            .map((item) => FeedItem.fromJson(item as Map<String, dynamic>))
            .toList();

        return {
          'items': items,
          'pagination': response.data['pagination'],
        };
      }

      throw Exception('Erreur lors de la récupération du feed');
    } catch (e) {
      rethrow;
    }
  }
}
