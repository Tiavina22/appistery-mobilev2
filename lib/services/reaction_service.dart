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
      print(
        '💚 [ReactionService.toggleReaction] storyId=$storyId, type=$reactionType',
      );
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
        print('  ✅ Réaction toggle réussie');
        return response.data['data'];
      }
      throw Exception('Erreur lors de la réaction');
    } catch (e) {
      print('  ❌ Erreur toggleReaction: $e');
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
      print('  ❌ Erreur getStoryReactions: $e');
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
      print('💬 [ReactionService.addComment] storyId=$storyId');
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
        print('  ✅ Commentaire ajouté');
        return response.data['data'];
      }
      throw Exception('Erreur lors de l\'ajout du commentaire');
    } catch (e) {
      print('  ❌ Erreur addComment: $e');
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
      print(
        '📖 [ReactionService.getStoryComments] storyId=$storyId, page=$page',
      );
      final response = await _dio.get(
        '/api/stories/$storyId/comments',
        queryParameters: {'page': page, 'limit': limit},
      );

      print('  📦 Response status: ${response.statusCode}');
      print('  📦 Response data: ${response.data}');

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      throw Exception('Erreur lors de la récupération des commentaires');
    } catch (e) {
      print('  ❌ Erreur getStoryComments: $e');
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
      print('  ❌ Erreur updateComment: $e');
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
      print('  ❌ Erreur deleteComment: $e');
      rethrow;
    }
  }
}
