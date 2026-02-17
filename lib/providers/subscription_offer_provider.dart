import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/subscription_offer_service.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

class SubscriptionOffer {
  final int id;
  final Map<String, dynamic> name;
  final int duration;
  final String state;
  final bool isInternational;
  final double amount;
  final String currency;
  final List<dynamic> advantages;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionOffer({
    required this.id,
    required this.name,
    required this.duration,
    required this.state,
    required this.isInternational,
    required this.amount,
    required this.currency,
    required this.advantages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionOffer.fromJson(Map<String, dynamic> json) {
    return SubscriptionOffer(
      id: json['id'],
      name: json['name'] ?? {},
      duration: json['duration'],
      state: json['state'] ?? 'active',
      isInternational: json['is_international'] ?? false,
      amount: double.parse(json['amount'].toString()),
      currency: json['currency'] ?? 'MGA',
      advantages: json['advantages'] ?? [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  String getNameByLanguage(String languageCode) {
    if (name[languageCode] != null) {
      return name[languageCode];
    }
    // Fallback à la première langue disponible
    if (name.isNotEmpty) {
      return name.values.first;
    }
    return 'Offre';
  }

  List<String> getAdvantagesByLanguage(String languageCode) {
    if (advantages.isNotEmpty) {
      for (var item in advantages) {
        if (item is Map && item['lang'] == languageCode) {
          return List<String>.from(item['advantages'] ?? []);
        }
      }
    }
    return [];
  }
}

class SubscriptionOfferProvider extends ChangeNotifier {
  final SubscriptionOfferService _service = SubscriptionOfferService();
  final WebSocketService _webSocketService = WebSocketService();

  List<SubscriptionOffer> _offers = [];
  List<SubscriptionOffer> _madagascarOffers = [];
  List<SubscriptionOffer> _internationalOffers = [];
  Map<String, dynamic>? _activeSubscription;
  bool _isLoading = false;
  String? _error;

  List<SubscriptionOffer> get offers => _offers;
  List<SubscriptionOffer> get madagascarOffers => _madagascarOffers;
  List<SubscriptionOffer> get internationalOffers => _internationalOffers;
  Map<String, dynamic>? get activeSubscription => _activeSubscription;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SubscriptionOfferProvider() {
    _initializeWebSocketListeners();
  }

  void _initializeWebSocketListeners() {
    // Écouter les mises à jour d'abonnement
    _webSocketService.onSubscriptionUpdated((data) {
      if (data != null && data is Map<String, dynamic>) {
        _activeSubscription = data;
        notifyListeners();
      }
    });

    // Écouter les nouveaux abonnements
    _webSocketService.onSubscriptionActivated((data) {
      if (data != null && data is Map<String, dynamic>) {
        _activeSubscription = data;
        notifyListeners();
      }
    });

    // Écouter les abonnements expirés/annulés
    _webSocketService.onSubscriptionExpired((data) {
      _activeSubscription = null;
      notifyListeners();
    });
  }

  // Cache methods
  Future<void> _cacheOffers(List<SubscriptionOffer> offers, String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offersJson = offers.map((offer) => {
        'id': offer.id,
        'name': offer.name,
        'duration': offer.duration,
        'state': offer.state,
        'is_international': offer.isInternational,
        'amount': offer.amount.toString(),
        'currency': offer.currency,
        'advantages': offer.advantages,
        'created_at': offer.createdAt.toIso8601String(),
        'updated_at': offer.updatedAt.toIso8601String(),
      }).toList();
      await prefs.setString(key, jsonEncode(offersJson));
      await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      // Ignore cache errors
    }
  }

  Future<List<SubscriptionOffer>?> _getCachedOffers(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(key);
      final timestamp = prefs.getString('${key}_timestamp');
      
      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.parse(timestamp);
        final now = DateTime.now();
        
        // Cache valide pour 30 minutes
        if (now.difference(cacheTime).inMinutes < 30) {
          final List<dynamic> decodedData = jsonDecode(cachedData);
          return decodedData
              .map((json) => SubscriptionOffer.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      // Ignore cache errors
    }
    return null;
  }

  Future<void> _cacheActiveSubscription(Map<String, dynamic>? subscription) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (subscription != null) {
        await prefs.setString('active_subscription', jsonEncode(subscription));
        await prefs.setString('active_subscription_timestamp', DateTime.now().toIso8601String());
      } else {
        await prefs.remove('active_subscription');
        await prefs.remove('active_subscription_timestamp');
      }
    } catch (e) {
      // Ignore cache errors
    }
  }

  Future<Map<String, dynamic>?> _getCachedActiveSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('active_subscription');
      final timestamp = prefs.getString('active_subscription_timestamp');
      
      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.parse(timestamp);
        final now = DateTime.now();
        
        // Cache valide pour 10 minutes
        if (now.difference(cacheTime).inMinutes < 10) {
          return jsonDecode(cachedData) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      // Ignore cache errors
    }
    return null;
  }

  // Charger l'abonnement actif de l'utilisateur
  Future<void> loadActiveSubscription() async {
    try {
      // 1. Charger depuis le cache d'abord
      final cached = await _getCachedActiveSubscription();
      if (cached != null) {
        _activeSubscription = cached;
        notifyListeners();
        
        // 2. Rafraîchir en arrière-plan
        _refreshActiveSubscriptionInBackground();
        return;
      }

      // 3. Pas de cache, charger depuis le serveur
      final result = await _service.getActiveSubscription();
      if (result['success'] == true &&
          result['hasActiveSubscription'] == true) {
        _activeSubscription = result['subscription'];
        await _cacheActiveSubscription(_activeSubscription);
      } else {
        _activeSubscription = null;
        await _cacheActiveSubscription(null);
      }
      notifyListeners();
    } catch (e) {
      _activeSubscription = null;
    }
  }

  Future<void> _refreshActiveSubscriptionInBackground() async {
    try {
      final result = await _service.getActiveSubscription();
      if (result['success'] == true &&
          result['hasActiveSubscription'] == true) {
        final newSubscription = result['subscription'];
        
        // Comparer avec le cache actuel
        if (jsonEncode(_activeSubscription) != jsonEncode(newSubscription)) {
          _activeSubscription = newSubscription;
          await _cacheActiveSubscription(_activeSubscription);
          notifyListeners();
        }
      } else if (_activeSubscription != null) {
        // L'abonnement a expiré
        _activeSubscription = null;
        await _cacheActiveSubscription(null);
        notifyListeners();
      }
    } catch (e) {
      // Ignore les erreurs de rafraîchissement en arrière-plan
    }
  }

  // Charger toutes les offres actives
  Future<void> loadOffers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.getAllOffers(state: 'active');

      if (result['success']) {
        _offers = (result['data'] as List)
            .map((json) => SubscriptionOffer.fromJson(json))
            .toList();
      } else {
        _error = result['error'] ?? 'Erreur lors du chargement des offres';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Charger les offres basées sur le pays de l'utilisateur
  Future<void> loadOffersByUserCountry(AuthProvider authProvider) async {
    try {
      // Déterminer si l'utilisateur est de Madagascar ou International
      final isMadagascar = authProvider.isMadagascarUser;
      final location = isMadagascar ? 'madagascar' : 'international';
      final cacheKey = 'subscription_offers_$location';

      // 1. Charger depuis le cache d'abord
      final cached = await _getCachedOffers(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        if (isMadagascar) {
          _madagascarOffers = cached;
          _internationalOffers = [];
        } else {
          _internationalOffers = cached;
          _madagascarOffers = [];
        }
        _offers = cached;
        _isLoading = false;
        notifyListeners();
        
        // 2. Rafraîchir en arrière-plan
        _refreshOffersByLocationInBackground(location, isMadagascar, cacheKey);
        return;
      }

      // 3. Pas de cache, charger depuis le serveur
      _isLoading = true;
      _error = null;
      notifyListeners();

      final localResult = await _service.getOffersByLocation(
        location: location,
      );
      if (localResult['success']) {
        final offersList = (localResult['data'] as List)
            .map((json) => SubscriptionOffer.fromJson(json))
            .toList();

        if (isMadagascar) {
          _madagascarOffers = offersList;
          _internationalOffers = [];
        } else {
          _internationalOffers = offersList;
          _madagascarOffers = [];
        }

        _offers = offersList;
        await _cacheOffers(offersList, cacheKey);
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshOffersByLocationInBackground(String location, bool isMadagascar, String cacheKey) async {
    try {
      final localResult = await _service.getOffersByLocation(
        location: location,
      );
      if (localResult['success']) {
        final offersList = (localResult['data'] as List)
            .map((json) => SubscriptionOffer.fromJson(json))
            .toList();

        // Comparer avec le cache actuel
        if (jsonEncode(_offers.map((o) => o.id).toList()) != 
            jsonEncode(offersList.map((o) => o.id).toList())) {
          if (isMadagascar) {
            _madagascarOffers = offersList;
            _internationalOffers = [];
          } else {
            _internationalOffers = offersList;
            _madagascarOffers = [];
          }
          _offers = offersList;
          await _cacheOffers(offersList, cacheKey);
          notifyListeners();
        }
      }
    } catch (e) {
      // Ignore les erreurs de rafraîchissement en arrière-plan
    }
  }

  // Charger les offres Madagascar et Internationales
  Future<void> loadAllLocationOffers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Charger Madagascar
      final madResult = await _service.getOffersByLocation(
        location: 'madagascar',
      );
      if (madResult['success']) {
        _madagascarOffers = (madResult['data'] as List)
            .map((json) => SubscriptionOffer.fromJson(json))
            .toList();
      }

      // Charger International
      final intResult = await _service.getOffersByLocation(
        location: 'international',
      );
      if (intResult['success']) {
        _internationalOffers = (intResult['data'] as List)
            .map((json) => SubscriptionOffer.fromJson(json))
            .toList();
      }

      // Combiner les deux listes
      _offers = [..._madagascarOffers, ..._internationalOffers];
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Obtenir une offre par ID
  Future<SubscriptionOffer?> getOfferById(int offerId) async {
    try {
      final result = await _service.getOfferById(offerId);

      if (result['success']) {
        return SubscriptionOffer.fromJson(result['data']);
      } else {
        _error = result['error'];
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Créer une offre (Admin)
  Future<bool> createOffer({
    required Map<String, dynamic> name,
    required int duration,
    required double amount,
    String state = 'active',
    bool isInternational = false,
    String currency = 'MGA',
    required List<dynamic> advantages,
  }) async {
    try {
      final result = await _service.createOffer(
        name: name,
        duration: duration,
        amount: amount,
        state: state,
        isInternational: isInternational,
        currency: currency,
        advantages: advantages,
      );

      if (result['success']) {
        final newOffer = SubscriptionOffer.fromJson(result['data']);
        _offers.add(newOffer);
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Mettre à jour une offre (Admin)
  Future<bool> updateOffer({
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
      final result = await _service.updateOffer(
        offerId: offerId,
        name: name,
        duration: duration,
        amount: amount,
        state: state,
        isInternational: isInternational,
        currency: currency,
        advantages: advantages,
      );

      if (result['success']) {
        final index = _offers.indexWhere((o) => o.id == offerId);
        if (index != -1) {
          _offers[index] = SubscriptionOffer.fromJson(result['data']);
          notifyListeners();
        }
        return true;
      } else {
        _error = result['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Supprimer une offre (Admin)
  Future<bool> deleteOffer(int offerId) async {
    try {
      final result = await _service.deleteOffer(offerId);

      if (result['success']) {
        _offers.removeWhere((o) => o.id == offerId);
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
