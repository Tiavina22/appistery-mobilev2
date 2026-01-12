import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class SubscriptionOfferService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final AuthService _authService = AuthService();

  // Récupérer toutes les offres
  Future<Map<String, dynamic>> getAllOffers({
    String? state,
    bool? isInternational,
    String? currency,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (state != null) queryParams['state'] = state;
      if (isInternational != null)
        queryParams['is_international'] = isInternational;
      if (currency != null) queryParams['currency'] = currency;

      final response = await _dio.get(
        '/api/subscription-offers',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return {
        'success': response.statusCode == 200,
        'data': response.data['data'] ?? [],
        'count': response.data['count'] ?? 0,
      };
    } on DioException catch (e) {
      print('❌ Erreur lors de la récupération des offres: ${e.message}');
      return {'success': false, 'data': [], 'error': e.message};
    }
  }

  // Récupérer les offres par localisation
  Future<Map<String, dynamic>> getOffersByLocation({
    required String location,
  }) async {
    try {
      // location: 'madagascar' ou 'international'
      final response = await _dio.get(
        '/api/subscription-offers/location',
        queryParameters: {'location': location},
      );

      return {
        'success': response.statusCode == 200,
        'data': response.data['data'] ?? [],
        'count': response.data['count'] ?? 0,
        'location': response.data['location'],
      };
    } on DioException catch (e) {
      print(
        '❌ Erreur lors de la récupération des offres par localisation: ${e.message}',
      );
      return {'success': false, 'data': [], 'error': e.message};
    }
  }

  // Récupérer une offre par ID
  Future<Map<String, dynamic>> getOfferById(int offerId) async {
    try {
      final response = await _dio.get('/api/subscription-offers/$offerId');

      return {
        'success': response.statusCode == 200,
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      print('❌ Erreur lors de la récupération de l\'offre: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  // Créer une offre (Admin uniquement)
  Future<Map<String, dynamic>> createOffer({
    required Map<String, dynamic> name,
    required int duration,
    required double amount,
    String state = 'active',
    bool isInternational = false,
    String currency = 'MGA',
    required List<dynamic> advantages,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.post(
        '/api/subscription-offers',
        data: {
          'name': name,
          'duration': duration,
          'amount': amount,
          'state': state,
          'is_international': isInternational,
          'currency': currency,
          'advantages': advantages,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': response.statusCode == 201,
        'message': response.data['message'],
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      print('❌ Erreur lors de la création de l\'offre: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  // Mettre à jour une offre (Admin uniquement)
  Future<Map<String, dynamic>> updateOffer({
    required int offerId,
    Map<String, dynamic>? name,
    int? duration,
    double? amount,
    String? state,
    bool? isInternational,
    String? currency,
    List<dynamic>? advantages,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (duration != null) data['duration'] = duration;
      if (amount != null) data['amount'] = amount;
      if (state != null) data['state'] = state;
      if (isInternational != null) data['is_international'] = isInternational;
      if (currency != null) data['currency'] = currency;
      if (advantages != null) data['advantages'] = advantages;

      final response = await _dio.put(
        '/api/subscription-offers/$offerId',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': response.statusCode == 200,
        'message': response.data['message'],
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'offre: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  // Supprimer une offre (Admin uniquement)
  Future<Map<String, dynamic>> deleteOffer(int offerId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.delete(
        '/api/subscription-offers/$offerId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': response.statusCode == 200,
        'message': response.data['message'],
      };
    } on DioException catch (e) {
      print('❌ Erreur lors de la suppression de l\'offre: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  // Récupérer l'abonnement actif de l'utilisateur
  Future<Map<String, dynamic>> getActiveSubscription() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Non authentifié'};
      }

      final response = await _dio.get(
        '/api/subscriptions/active',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': response.data['success'] ?? true,
        'hasActiveSubscription':
            response.data['hasActiveSubscription'] ?? false,
        'subscription': response.data['subscription'],
      };
    } on DioException catch (e) {
      print(
        '❌ Erreur lors de la récupération de l\'abonnement actif: ${e.message}',
      );
      return {'success': false, 'error': e.message};
    }
  }
}
