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
    if (_user == null) return null;
    // Vérifier si le pays est un objet avec un code ou juste le code
    final country = _user!['country'];
    if (country is Map) {
      return country['code'] as String?;
    }
    return country as String?;
  }

  // Vérifier si l'utilisateur est de Madagascar
  bool get isMadagascarUser {
    final country = userCountry;
    return country == 'MG' || country == 'mg' || country == 'Madagascar';
  }

  AuthProvider() {
    _checkLoginStatus();
  }

  // Vérifier le statut de connexion au démarrage
  Future<void> _checkLoginStatus() async {
    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn) {
      // Récupérer le profil complet depuis l'API
      _user = await _authService.getUserProfile();
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
