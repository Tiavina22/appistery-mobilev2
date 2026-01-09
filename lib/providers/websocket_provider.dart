import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class WebSocketProvider extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();

  bool _isConnected = false;
  List<Map<String, dynamic>> _notifications = [];

  bool get isConnected => _isConnected;
  List<Map<String, dynamic>> get notifications => _notifications;
  WebSocketService get wsService => _wsService;

  WebSocketProvider() {
    _initializeWebSocket();
  }

  // Initialiser WebSocket et ses listeners
  Future<void> _initializeWebSocket() async {
    await _wsService.connect();

    // Écouter les changements de connexion
    _wsService.socket?.on('connect', (_) {
      _isConnected = true;
      notifyListeners();
      print('WebSocketProvider: Connected');
    });

    _wsService.socket?.on('disconnect', (_) {
      _isConnected = false;
      notifyListeners();
      print('WebSocketProvider: Disconnected');
    });

    // Écouter les notifications
    _wsService.onNotification((data) {
      _addNotification(data);
    });

    // Écouter les nouvelles histoires
    _wsService.onNewStory((data) {
      print('WebSocketProvider: New story received: $data');
      _addNotification({
        'type': 'new_story',
        'title': 'Nouvelle histoire',
        'message': data['title'] ?? 'Une nouvelle histoire a été publiée',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Écouter les nouveaux chapitres
    _wsService.onNewChapter((data) {
      print('WebSocketProvider: New chapter received: $data');
      _addNotification({
        'type': 'new_chapter',
        'title': 'Nouveau chapitre',
        'message': data['title'] ?? 'Un nouveau chapitre a été publié',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Écouter les mises à jour d'histoires
    _wsService.onStoryUpdated((data) {
      print('WebSocketProvider: Story updated: $data');
      notifyListeners();
    });
  }

  // Ajouter une notification
  void _addNotification(Map<String, dynamic> notification) {
    _notifications.insert(0, notification);
    if (_notifications.length > 50) {
      _notifications = _notifications.sublist(0, 50);
    }
    notifyListeners();
  }

  // Marquer une notification comme lue
  void markNotificationAsRead(int index) {
    if (index < _notifications.length) {
      _notifications[index]['read'] = true;
      notifyListeners();
    }
  }

  // Supprimer une notification
  void removeNotification(int index) {
    if (index < _notifications.length) {
      _notifications.removeAt(index);
      notifyListeners();
    }
  }

  // Effacer toutes les notifications
  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  // Ajouter un listener pour un événement spécifique
  void on(String event, Function(dynamic) callback) {
    _wsService.socket?.on(event, callback);
  }

  // Reconnecter
  Future<void> reconnect() async {
    _wsService.disconnect();
    await Future.delayed(const Duration(seconds: 1));
    await _wsService.connect();
  }

  // Déconnecter
  void disconnect() {
    _wsService.disconnect();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }
}
