import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:io';
import 'device_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio = Dio();

  String get apiUrl => dotenv.env['API_URL'] ?? 'http://localhost:5500';

  // Sauvegarder le token
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // Récupérer le token
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Supprimer le token
  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
    await _storage.read(key: 'auth_token');
     }

  // Vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    // Vérifier si le token est expiré
    try {
      bool isExpired = JwtDecoder.isExpired(token);
      if (isExpired) {
        await deleteToken();
        return false;
      }
      return true;
    } catch (e) {
      // Si erreur lors du décodage, le token est invalide
      await deleteToken();
      return false;
    }
  }

  // Connexion
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Obtenir les infos d'appareil
      final deviceService = DeviceService();
      final deviceInfo = await deviceService.getDeviceInfo();

      final response = await _dio.post(
        '$apiUrl/api/auth/login',
        data: {
          'email': email,
          'password': password,
          ...deviceInfo, // Ajouter les infos d'appareil
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        await saveToken(token);
        return {'success': true, 'token': token, 'user': response.data['user']};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Erreur de connexion',
        'error_code': response.data['error_code'],
        'field': response.data['field'],
      };
    } on DioException catch (e) {
      // Vérifier si c'est une erreur de device déjà connecté
      final errorCode = e.response?.data['error_code'];
      final deviceName = e.response?.data['device_name'];
      final field = e.response?.data['field'];

      if (errorCode == 'DEVICE_ALREADY_CONNECTED') {
        return {
          'success': false,
          'message':
              e.response?.data['message'] ??
              'Ce compte est déjà connecté sur un autre appareil.',
          'error_code': 'DEVICE_ALREADY_CONNECTED',
          'device_name': deviceName ?? 'Appareil inconnu',
        };
      }

      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Erreur de connexion',
        'error_code': errorCode,
        'field': field,
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue'};
    }
  }

  // Inscription - Étape 1: Envoyer OTP
  Future<Map<String, dynamic>> sendOTP({
    required String email,
    required String username,
  }) async {
    try {
      final response = await _dio.post(
        '$apiUrl/api/auth/send-otp',
        data: {'email': email, 'username': username},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'email': response.data['email']};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Erreur d\'envoi OTP',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Erreur d\'envoi OTP',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue'};
    }
  }

  // Inscription - Étape 2: Vérifier OTP
  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '$apiUrl/api/auth/verify-otp',
        data: {'email': email, 'code': code},
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Code OTP invalide',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Code OTP invalide',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue'};
    }
  }

  // Inscription - Étape 3: Finaliser avec mot de passe + fichier avatar
  Future<Map<String, dynamic>> completeRegistration({
    required String username,
    required String email,
    required String password,
    String? telephone,
    String? language,
    File? avatarFile,
    int? countryId,
    bool? cguAccepted,
  }) async {
    try {
      // Si un fichier avatar est fourni, utiliser le nouvel endpoint avec upload
      if (avatarFile != null) {
        final formData = FormData.fromMap({
          'username': username,
          'email': email,
          'password': password,
          if (telephone != null) 'telephone': telephone,
          if (language != null) 'language': language,
          if (countryId != null) 'country_id': countryId,
          if (cguAccepted != null) 'cgu_accepted': cguAccepted,
          'avatar': await MultipartFile.fromFile(
            avatarFile.path,
            filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        });

        final response = await _dio.post(
          '$apiUrl/api/auth/complete-registration-with-avatar',
          data: formData,
        );

        if (response.statusCode == 201) {
          final token = response.data['token'];
          await saveToken(token);
          return {'success': true, 'token': token, 'user': response.data['user']};
        }

        return {
          'success': false,
          'message': response.data['message'] ?? 'Erreur d\'inscription',
        };
      } else {
        // Sinon, utiliser l'ancien endpoint sans avatar (backward compatibility)
        final response = await _dio.post(
          '$apiUrl/api/auth/complete-registration',
          data: {
            'username': username,
            'email': email,
            'password': password,
            if (telephone != null) 'telephone': telephone,
            if (language != null) 'language': language,
            if (countryId != null) 'country_id': countryId,
            if (cguAccepted != null) 'cgu_accepted': cguAccepted,
          },
        );

        if (response.statusCode == 201) {
          final token = response.data['token'];
          await saveToken(token);
          return {'success': true, 'token': token, 'user': response.data['user']};
        }

        return {
          'success': false,
          'message': response.data['message'] ?? 'Erreur d\'inscription',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Erreur d\'inscription',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue: $e'};
    }
  }

  // Déconnexion
  Future<void> logout() async {
    try {
      // Obtenir les infos d'appareil
      final deviceService = DeviceService();
      final deviceId = await deviceService.getDeviceId();
      
      // Appeler l'endpoint backend pour mettre à jour la session
      final dio = await getDioWithAuth();
      await dio.post(
        '/api/auth/logout',
        data: {'device_id': deviceId},
      );
    } catch (e) {
      // Si l'appel API échoue, on supprime quand même le token local
       } finally {
      // Toujours supprimer le token local
      await deleteToken();
    }
  }

  // Récupérer le profil complet de l'utilisateur connecté
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final dio = await getDioWithAuth();
      final response = await dio.get('/api/auth/profile');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['user'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Récupérer les informations de l'utilisateur depuis le token
  Future<Map<String, dynamic>?> getUserFromToken() async {
    final token = await getToken();

    if (token == null) {
      return null;
    }

    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return decodedToken;
    } catch (e) {
      return null;
    }
  }

  // Intercepteur pour ajouter le token aux requêtes
  Future<Dio> getDioWithAuth() async {
    final token = await getToken();
    final dio = Dio(
      BaseOptions(
        baseUrl: apiUrl,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return dio;
  }

  // Récupérer la liste des pays
  Future<Map<String, dynamic>> getCountries() async {
    try {
      final response = await _dio.get('$apiUrl/api/auth/countries');

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data['data']};
      }

      return {
        'success': false,
        'message': 'Erreur lors du chargement des pays',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Erreur réseau',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue'};
    }
  }

  // Récupérer les CGU
  Future<Map<String, dynamic>> getCGU(String language) async {
    try {
      final url = '$apiUrl/api/auth/cgu?language=$language';
      final response = await _dio.get(url);


      if (response.statusCode == 200) {
        final data = response.data['data'];
        return {'success': true, 'data': data};
      }

      return {'success': false, 'message': 'Erreur lors du chargement des CGU'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Erreur réseau: ${e.message}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue: $e'};
    }
  }

  // =============== MOT DE PASSE OUBLIÉ ===============

  // Étape 1 : Demander la réinitialisation (envoyer OTP)
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    try {
      final response = await _dio.post(
        '$apiUrl/api/auth/forgot-password',
        data: {'email': email},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'email': response.data['email'],
        };
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Erreur lors de la demande',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Erreur réseau',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue'};
    }
  }

  // Étape 2 : Vérifier l'OTP de réinitialisation
  Future<Map<String, dynamic>> verifyResetOTP({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '$apiUrl/api/auth/verify-reset-otp',
        data: {'email': email, 'code': code},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'email': response.data['email'],
        };
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Code OTP invalide',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Erreur réseau',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue'};
    }
  }

  // Étape 3 : Réinitialiser le mot de passe
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '$apiUrl/api/auth/reset-password',
        data: {'email': email, 'code': code, 'newPassword': newPassword},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['message']};
      }

      return {
        'success': false,
        'message':
            response.data['message'] ?? 'Erreur lors de la réinitialisation',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Erreur réseau',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur inattendue'};
    }
  }
}
