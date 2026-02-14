import 'package:flutter/material.dart';
import '../services/subscription_offer_service.dart';
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
    if (advantages is List) {
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

  // Charger l'abonnement actif de l'utilisateur
  Future<void> loadActiveSubscription() async {
    try {
      final result = await _service.getActiveSubscription();
      if (result['success'] == true &&
          result['hasActiveSubscription'] == true) {
        _activeSubscription = result['subscription'];
      } else {
        _activeSubscription = null;
      }
      notifyListeners();
    } catch (e) {
      _activeSubscription = null;
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Déterminer si l'utilisateur est de Madagascar ou International
      final isMadagascar = authProvider.isMadagascarUser;
      final location = isMadagascar ? 'madagascar' : 'international';

      // Charger UNIQUEMENT les offres du pays de l'utilisateur
      final localResult = await _service.getOffersByLocation(
        location: location,
      );
      if (localResult['success']) {
        final offersList = (localResult['data'] as List)
            .map((json) => SubscriptionOffer.fromJson(json))
            .toList();

        if (isMadagascar) {
          _madagascarOffers = offersList;
          _internationalOffers = []; // Vider les offres internationales
        } else {
          _internationalOffers = offersList;
          _madagascarOffers = []; // Vider les offres Madagascar
        }

        // Mettre UNIQUEMENT les offres du pays de l'utilisateur
        _offers = offersList;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
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
