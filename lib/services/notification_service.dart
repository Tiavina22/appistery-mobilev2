import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../config/api_config.dart';

class NotificationService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final AuthService _authService = AuthService();

  // Récupérer toutes les notifications
  Future<Map<String, dynamic>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.get(
        '/notifications',
        queryParameters: {'limit': limit, 'offset': offset},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': response.statusCode == 200,
        'data': response.data['data'] ?? [],
        'total': response.data['total'] ?? 0,
        'count': response.data['count'] ?? 0,
      };
    } on DioException catch (e) {
      print('❌ Erreur lors de la récupération des notifications: ${e.message}');
      return {'success': false, 'data': [], 'error': e.message};
    }
  }

  // Obtenir le nombre de notifications non lues
  Future<int> getUnreadCount() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.get(
        '/notifications/unread-count',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['unread_count'] ?? 0;
    } on DioException catch (e) {
      print(
        '❌ Erreur lors du comptage des notifications non lues: ${e.message}',
      );
      return 0;
    }
  }

  // Marquer une notification comme lue
  Future<bool> markAsRead(int notificationId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.put(
        '/notifications/$notificationId/read',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      print('❌ Erreur lors du marquage de la notification: ${e.message}');
      return false;
    }
  }

  // Marquer toutes les notifications comme lues
  Future<bool> markAllAsRead() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.put(
        '/notifications/mark-all-read',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      print(
        '❌ Erreur lors du marquage de toutes les notifications: ${e.message}',
      );
      return false;
    }
  }

  // Supprimer une notification
  Future<bool> deleteNotification(int notificationId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.delete(
        '/notifications/$notificationId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      print('❌ Erreur lors de la suppression de la notification: ${e.message}');
      return false;
    }
  }
}
