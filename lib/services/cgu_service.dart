import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CguService {
  late final Dio _dio;
  final String apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:5000';

  CguService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: apiUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  Future<Map<String, dynamic>> getCgu({String language = 'fr'}) async {
    try {
      print('DEBUG: Fetching CGU from $apiUrl/api/cgu?lang=$language');
      final response = await _dio.get(
        '/api/cgu',
        queryParameters: {'lang': language},
      );
      print('DEBUG: CGU response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        print('DEBUG: CGU fetched successfully for language: $language');
        return data;
      }
      throw Exception('Failed to load CGU: ${response.statusCode}');
    } on DioException catch (e) {
      print('DEBUG: DioException - ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('DEBUG: Unknown error - $e');
      throw Exception('Error loading CGU: $e');
    }
  }
}
