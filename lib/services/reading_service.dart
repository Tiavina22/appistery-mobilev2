import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ReadingService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();

  ReadingService() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  // Récupérer un chapitre
  Future<Map<String, dynamic>> getChapter(int chapterId) async {
    try {
      final response = await _dio.get('/api/chapters/public/$chapterId');

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      } else {
        throw Exception(
          response.data['message'] ??
              'Erreur lors de la récupération du chapitre',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response!.data['message'] ??
              'Erreur lors de la récupération du chapitre',
        );
      } else {
        throw Exception('Erreur réseau: ${e.message}');
      }
    }
  }

  // Enregistrer une vue
  Future<void> recordView(int storyId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return;
      }

      await _dio.post(
        '/api/stories/$storyId/view',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException {
    }
  }

  // Sauvegarder la progression de lecture
  Future<void> saveProgress({
    required int storyId,
    required int chapterId,
    required double scrollPosition,
    required bool isCompleted,
    required int readingTimeSeconds,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return;
      }

      await _dio.post(
        '/api/stories/$storyId/chapters/$chapterId/progress',
        data: {
          'scroll_position': scrollPosition,
          'is_completed': isCompleted,
          'reading_time_seconds': readingTimeSeconds,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException {
    }
  }

  // Obtenir la progression de lecture
  Future<Map<String, dynamic>?> getProgress(int storyId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return null;
      }

      final response = await _dio.get(
        '/api/stories/$storyId/progress',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        final data = response.data['data'];
        // Si le backend retourne une liste, prendre le premier élément
        if (data is List && data.isNotEmpty) {
          return data[0] as Map<String, dynamic>;
        } else if (data is Map) {
          return data as Map<String, dynamic>;
        }
        return null;
      }
      return null;
    } on DioException {
      return null;
    }
  }

  // Récupérer la dernière position de lecture
  Future<Map<String, dynamic>?> getLastPosition(int storyId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await _dio.get(
        '/api/stories/$storyId/last-position',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      return null;
    } on DioException {
      return null;
    }
  }

  // Marquer une histoire comme complètement lue
  Future<bool> markStoryCompleted(int storyId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return false;
      }

      final response = await _dio.post(
        '/api/stories/$storyId/mark-completed',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        return true;
      }
      return false;
    } on DioException {
      return false;
    }
  }

  // Vérifier si une histoire est complètement lue
  Future<bool> isStoryCompleted(int storyId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await _dio.get(
        '/api/stories/$storyId/is-completed',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data']['is_completed'] ?? false;
      }
      return false;
    } on DioException {
      return false;
    }
  }

  // Obtenir les infos de completion d'une histoire
  Future<Map<String, dynamic>?> getCompletionInfo(int storyId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await _dio.get(
        '/api/stories/$storyId/completion-info',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      return null;
    } on DioException {
      return null;
    }
  }

  // Obtenir les stats de lecture d'une histoire (publique)
  Future<Map<String, dynamic>?> getReadingStats(int storyId) async {
    try {
      final response = await _dio.get('/api/stories/$storyId/reading-stats');

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      return null;
    } on DioException {
      return null;
    }
  }

  // Récupérer les histoires lues par l'utilisateur
  Future<List<Map<String, dynamic>>> getUserReadStories() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return [];
      }

      final response = await _dio.get(
        '/api/my-read-stories',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        final List<dynamic> data = response.data['data'] ?? [];
        return List<Map<String, dynamic>>.from(
          data.map((story) => Map<String, dynamic>.from(story as Map)),
        );
      }
      return [];
    } on DioException {
      return [];
    }
  }
}
