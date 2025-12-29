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
    await _authService.logout();
    _isLoggedIn = false;
    _user = null;
    _errorMessage = null;
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
