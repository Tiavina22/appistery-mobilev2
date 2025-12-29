import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';

class AuthorService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();

  String get baseUrl => dotenv.env['API_URL'] ?? 'http://localhost:5500';

  // Obtenir le profil d'un auteur
  Future<Map<String, dynamic>> getAuthorProfile(int authorId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/authors/$authorId/public/profile',
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      } else {
        throw Exception(
          response.data['message'] ??
              'Erreur lors de la récupération du profil',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Obtenir les histoires d'un auteur
  Future<List<dynamic>> getAuthorStories(int authorId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/authors/$authorId/public/stories',
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'] as List;
      } else {
        throw Exception(response.data['message'] ?? 'Erreur');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Suivre un auteur
  Future<void> followAuthor(int authorId) async {
    try {
      final token = await _authService.getToken();
      final response = await _dio.post(
        '$baseUrl/api/authors/$authorId/follow',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 201 || !response.data['success']) {
        throw Exception(response.data['message'] ?? 'Erreur lors du suivi');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Ne plus suivre un auteur
  Future<void> unfollowAuthor(int authorId) async {
    try {
      final token = await _authService.getToken();
      final response = await _dio.delete(
        '$baseUrl/api/authors/$authorId/follow',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200 || !response.data['success']) {
        throw Exception(
          response.data['message'] ?? 'Erreur lors du désabonnement',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Vérifier si on suit un auteur
  Future<bool> isFollowing(int authorId) async {
    try {
      final token = await _authService.getToken();
      final response = await _dio.get(
        '$baseUrl/api/authors/$authorId/following',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data']['isFollowing'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Obtenir le nombre de followers
  Future<int> getFollowersCount(int authorId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/authors/$authorId/followers/count',
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data']['followers_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Obtenir les stats d'un auteur
  Future<Map<String, dynamic>> getAuthorStats(int authorId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/authors/$authorId/public/stats',
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
