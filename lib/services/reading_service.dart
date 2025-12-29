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
      if (token == null) return;

      await _dio.post(
        '/api/stories/$storyId/view',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      print('Erreur lors de l\'enregistrement de la vue: ${e.message}');
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
      if (token == null) return;

      await _dio.post(
        '/api/stories/$storyId/chapters/$chapterId/progress',
        data: {
          'scroll_position': scrollPosition,
          'is_completed': isCompleted,
          'reading_time_seconds': readingTimeSeconds,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      print('Erreur lors de la sauvegarde de la progression: ${e.message}');
    }
  }

  // Récupérer la progression de lecture
  Future<Map<String, dynamic>?> getProgress(int storyId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await _dio.get(
        '/api/stories/$storyId/progress',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      return null;
    } on DioException catch (e) {
      print('Erreur lors de la récupération de la progression: ${e.message}');
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
    } on DioException catch (e) {
      print(
        'Erreur lors de la récupération de la dernière position: ${e.message}',
      );
      return null;
    }
  }
}
