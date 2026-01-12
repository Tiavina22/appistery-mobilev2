import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoggedIn = false;
  bool _isLoading = false;
  Map<String, dynamic>? _user;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;
  String? get errorMessage => _errorMessage;

  bool get isPremium {
    if (_user == null) return false;
    // Vérifier is_premium directement
    if (_user!['is_premium'] == true || _user!['isPremium'] == true) {
      return true;
    }
    // Fallback: si subscription est active et non expirée, considérer comme premium
    final status = _user!['subscription_status'] as String?;
    final expiresAt = _user!['subscription_expires_at'];
    if (status == 'active' && expiresAt != null) {
      final expiry = DateTime.tryParse(expiresAt.toString());
      if (expiry != null && expiry.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  // Obtenir le type d'abonnement
  String? get subscriptionType {
    if (_user == null) return null;
    return _user!['subscription_type'] as String?;
  }

  // Obtenir le statut de l'abonnement
  String? get subscriptionStatus {
    if (_user == null) return null;
    return _user!['subscription_status'] as String?;
  }

  // Obtenir la date d'expiration de l'abonnement
  DateTime? get subscriptionExpiresAt {
    if (_user == null) return null;
    final expiresAt = _user!['subscription_expires_at'];
    if (expiresAt == null) return null;
    return DateTime.tryParse(expiresAt.toString());
  }

  // Vérifier si l'utilisateur a un abonnement actif
  bool get hasActiveSubscription {
    if (_user == null) return false;
    final status = subscriptionStatus;
    final expiresAt = subscriptionExpiresAt;

    // Actif si status = 'active' et non expiré
    if (status == 'active' && expiresAt != null) {
      return expiresAt.isAfter(DateTime.now());
    }
    return false;
  }

  // Obtenir le pays de l'utilisateur
  String? get userCountry {
    if (_user == null) {
      print('🚨 userCountry: _user est null');
      return null;
    }
    // Vérifier si le pays est un objet avec un code ou juste le code
    final country = _user!['country'];
    print('🌍 userCountry: country data = $country');
    if (country is Map) {
      final code = country['code'] as String?;
      print('🌍 userCountry: Map detected, code = $code');
      return code;
    }
    print('🌍 userCountry: String/direct value = $country');
    return country as String?;
  }

  // Vérifier si l'utilisateur est de Madagascar
  bool get isMadagascarUser {
    final country = userCountry;
    final isMG = country == 'MG' || country == 'mg' || country == 'Madagascar';
    print('🏝️ isMadagascarUser: country=$country, isMG=$isMG');
    return isMG;
  }

  AuthProvider() {
    _checkLoginStatus();
  }

  // Vérifier le statut de connexion au démarrage
  Future<void> _checkLoginStatus() async {
    _isLoggedIn = await _authService.isLoggedIn();
    print('🔐 _checkLoginStatus: isLoggedIn=$_isLoggedIn');
    if (_isLoggedIn) {
      // Récupérer le profil complet depuis l'API
      _user = await _authService.getUserProfile();
      print(
        '👤 _checkLoginStatus: user data loaded, country=${_user?['country']}',
      );
      _logSubscriptionDetails('_checkLoginStatus');
    }
    notifyListeners();
  }

  // Log des détails de l'abonnement
  void _logSubscriptionDetails(String source) {
    print('═══════════════════════════════════════════════════════════');
    print('📊 [$source] SUBSCRIPTION DETAILS:');
    print('   👤 User ID: ${_user?['id']}');
    print('   📧 Email: ${_user?['email']}');
    print('   ⭐ is_premium: ${_user?['is_premium']}');
    print('   📦 subscription_type: ${_user?['subscription_type']}');
    print('   📋 subscription_status: ${_user?['subscription_status']}');
    print(
      '   📅 subscription_expires_at: ${_user?['subscription_expires_at']}',
    );
    print('   🔓 isPremium (getter): $isPremium');
    print('   ✅ hasActiveSubscription (getter): $hasActiveSubscription');
    print('═══════════════════════════════════════════════════════════');
  }

  // Connexion
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);

      if (result['success'] == true) {
        _isLoggedIn = true;
        _user = result['user'];
        _errorMessage = null;
        _isLoading = false;
        _logSubscriptionDetails('login');
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erreur de connexion';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Déconnexion
  Future<void> logout() async {
    print('🔴 AuthProvider: Déconnexion en cours...');
    await _authService.logout();
    _isLoggedIn = false;
    _user = null;
    _errorMessage = null;
    print('🔴 AuthProvider: Déconnexion terminée. isLoggedIn=$_isLoggedIn');
    notifyListeners();
  }

  // Rafraîchir le statut de connexion
  Future<void> refreshLoginStatus() async {
    await _checkLoginStatus();
  }

  // Définir manuellement le statut de connexion (après inscription)
  void setLoggedIn(bool loggedIn, Map<String, dynamic>? userData) {
    _isLoggedIn = loggedIn;
    _user = userData;
    notifyListeners();
  }
}
