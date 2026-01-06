import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VersionService {
  final String baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.206:5500';

  /// Check version compatibility with the backend
  /// Returns version info including update requirement
  Future<Map<String, dynamic>> checkVersion({
    required int versionCode,
    required String platform,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/version/check');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'versionCode': versionCode, 'platform': platform}),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['data'] ?? {};
      } else if (response.statusCode == 400 || response.statusCode == 404) {
        // No active version found - but backend may return fallback data
        print('No active version found on server');
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] ?? {};
        // Return empty map with any available download data
        return data.isEmpty ? {} : data;
      } else {
        throw Exception('Failed to check version: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking version: $e');
      rethrow;
    }
  }

  /// Get the current app version code from environment
  static int getAppVersionCode() {
    try {
      final versionCode = dotenv.env['APP_VERSION_CODE'];
      return int.parse(versionCode ?? '1');
    } catch (e) {
      return 1; // Default to 1 if parsing fails
    }
  }

  /// Get the current app version name from environment
  static String getAppVersionName() {
    return dotenv.env['APP_VERSION_NAME'] ?? '1.0.0';
  }

  /// Get the app platform from environment
  static String getAppPlatform() {
    return dotenv.env['APP_PLATFORM'] ?? 'android';
  }
}
