import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../config/api_config.dart';

class ReactionService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final AuthService _authService = AuthService();

  // Toggle reaction (like/unlike)
  Future<Map<String, dynamic>> toggleReaction(
    int storyId, {
    String reactionType = 'like',
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.post(
        '/api/stories/$storyId/reactions',
        data: {'reactionType': reactionType},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      throw Exception('Erreur lors de la réaction');
    } catch (e) {
      rethrow;
    }
  }

  // Get story reactions
  Future<Map<String, dynamic>> getStoryReactions(int storyId) async {
    try {
      final token = await _authService.getToken();
      final options = token != null
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null;

      final response = await _dio.get(
        '/api/stories/$storyId/reactions',
        options: options,
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      throw Exception('Erreur lors de la récupération des réactions');
    } catch (e) {
      rethrow;
    }
  }

  // Add comment
  Future<Map<String, dynamic>> addComment(
    int storyId,
    String commentText, {
    int? parentCommentId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.post(
        '/api/stories/$storyId/comments',
        data: {
          'commentText': commentText,
          if (parentCommentId != null) 'parentCommentId': parentCommentId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 201 && response.data['success']) {
        return response.data['data'];
      }
      throw Exception('Erreur lors de l\'ajout du commentaire');
    } catch (e) {
      rethrow;
    }
  }

  // Get story comments
  Future<Map<String, dynamic>> getStoryComments(
    int storyId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/api/stories/$storyId/comments',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      throw Exception('Erreur lors de la récupération des commentaires');
    } catch (e) {
      rethrow;
    }
  }

  // Update comment
  Future<void> updateComment(int commentId, String commentText) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.put(
        '/api/comments/$commentId',
        data: {'commentText': commentText},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200 || !response.data['success']) {
        throw Exception('Erreur lors de la modification du commentaire');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Delete comment
  Future<void> deleteComment(int commentId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.delete(
        '/api/comments/$commentId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200 || !response.data['success']) {
        throw Exception('Erreur lors de la suppression du commentaire');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Toggle comment like
  Future<Map<String, dynamic>> toggleCommentLike(int commentId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.post(
        '/api/comments/$commentId/like',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        return {
          'liked': response.data['liked'],
          'message': response.data['message'],
        };
      }
      throw Exception('Erreur lors du like du commentaire');
    } catch (e) {
      rethrow;
    }
  }

  // Get comment likes
  Future<Map<String, dynamic>> getCommentLikes(int commentId) async {
    try {
      final token = await _authService.getToken();
      final options = token != null
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null;

      final response = await _dio.get(
        '/api/comments/$commentId/likes',
        options: options,
      );

      if (response.statusCode == 200 && response.data['success']) {
        return {
          'likeCount': response.data['likeCount'] ?? 0,
          'userLiked': response.data['userLiked'] ?? false,
          'likes': response.data['likes'] ?? [],
        };
      }
      throw Exception('Erreur lors de la récupération des likes');
    } catch (e) {
      rethrow;
    }
  }
}
