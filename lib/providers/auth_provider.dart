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
    // Vérifier s'il existe un abonnement actif
    return _user!['is_premium'] ?? _user!['isPremium'] ?? false;
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
    }
    notifyListeners();
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
