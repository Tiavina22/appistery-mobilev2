import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final int id;
  final int user_id;
  final String type;
  final String title;
  final String message;
  final int? actor_id;
  final int? related_story_id;
  final int? related_chapter_id;
  final bool is_read;
  final DateTime created_at;
  final Map<String, dynamic>? actor;
  final Map<String, dynamic>? story;

  AppNotification({
    required this.id,
    required this.user_id,
    required this.type,
    required this.title,
    required this.message,
    this.actor_id,
    this.related_story_id,
    this.related_chapter_id,
    required this.is_read,
    required this.created_at,
    this.actor,
    this.story,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      user_id: json['user_id'],
      type: json['type'],
      title: json['title'],
      message: json['message'],
      actor_id: json['actor_id'],
      related_story_id: json['related_story_id'],
      related_chapter_id: json['related_chapter_id'],
      is_read: json['is_read'] ?? false,
      created_at: DateTime.parse(json['created_at']),
      actor: json['actor'],
      story: json['story'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': user_id,
      'type': type,
      'title': title,
      'message': message,
      'actor_id': actor_id,
      'related_story_id': related_story_id,
      'related_chapter_id': related_chapter_id,
      'is_read': is_read,
      'created_at': created_at.toIso8601String(),
      'actor': actor,
      'story': story,
    };
  }
}

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Charger les notifications
  Future<void> loadNotifications({int limit = 20, int offset = 0}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Charger depuis le cache d'abord
      final cachedNotifications = await _getCachedNotifications();
      if (cachedNotifications != null && cachedNotifications.isNotEmpty) {
        _notifications = cachedNotifications;
        _isLoading = false;
        notifyListeners();
        
        // 2. Rafraîchir en arrière-plan
        _refreshNotificationsInBackground(limit, offset);
        return;
      }
      
      // 3. Si pas de cache, charger depuis le serveur
      final result = await _service.getNotifications(
        limit: limit,
        offset: offset,
      );

      if (result['success']) {
        _notifications = (result['data'] as List)
            .map((json) => AppNotification.fromJson(json))
            .toList();
        
        // Sauvegarder dans le cache
        await _cacheNotifications(_notifications);
        
        await loadUnreadCount();
      } else {
        _error =
            result['error'] ?? 'Erreur lors du chargement des notifications';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Rafraîchir les notifications en arrière-plan
  Future<void> _refreshNotificationsInBackground(int limit, int offset) async {
    try {
      final result = await _service.getNotifications(
        limit: limit,
        offset: offset,
      );

      if (result['success']) {
        _notifications = (result['data'] as List)
            .map((json) => AppNotification.fromJson(json))
            .toList();
        
        await _cacheNotifications(_notifications);
        await loadUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Sauvegarder les notifications dans le cache
  Future<void> _cacheNotifications(List<AppNotification> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = notifications.map((n) => n.toJson()).toList();
      await prefs.setString('cached_notifications', jsonEncode(notificationsJson));
      await prefs.setInt(
        'cached_notifications_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Récupérer les notifications du cache
  Future<List<AppNotification>?> _getCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('cached_notifications_timestamp');
      
      // Vérifier si le cache est encore valide (10 minutes)
      if (timestamp == null) return null;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > Duration(minutes: 10).inMilliseconds) {
        return null;
      }
      
      final notificationsJson = prefs.getString('cached_notifications');
      if (notificationsJson == null) return null;
      
      final List<dynamic> decoded = jsonDecode(notificationsJson);
      return decoded.map((json) => AppNotification.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  // Charger le nombre de notifications non lues
  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await _service.getUnreadCount();
      notifyListeners();
    } catch (e) {
    }
  }

  // Marquer une notification comme lue
  Future<void> markAsRead(int notificationId) async {
    try {
      final success = await _service.markAsRead(notificationId);

      if (success) {
        // Mettre à jour l'état local
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          final notification = _notifications[index];
          _notifications[index] = AppNotification(
            id: notification.id,
            user_id: notification.user_id,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            actor_id: notification.actor_id,
            related_story_id: notification.related_story_id,
            related_chapter_id: notification.related_chapter_id,
            is_read: true,
            created_at: notification.created_at,
            actor: notification.actor,
            story: notification.story,
          );

          // Mettre à jour le compte non lues
          await loadUnreadCount();
          notifyListeners();
        }
      }
    } catch (e) {
    }
  }

  // Marquer toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    try {
      final success = await _service.markAllAsRead();

      if (success) {
        // Mettre à jour toutes les notifications
        _notifications = _notifications
            .map(
              (n) => AppNotification(
                id: n.id,
                user_id: n.user_id,
                type: n.type,
                title: n.title,
                message: n.message,
                actor_id: n.actor_id,
                related_story_id: n.related_story_id,
                related_chapter_id: n.related_chapter_id,
                is_read: true,
                created_at: n.created_at,
                actor: n.actor,
                story: n.story,
              ),
            )
            .toList();

        _unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
    }
  }

  // Ajouter une notification reçue via WebSocket
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _unreadCount++;
    notifyListeners();
  }

  // Supprimer une notification
  Future<void> deleteNotification(int notificationId) async {
    try {
      final success = await _service.deleteNotification(notificationId);

      if (success) {
        _notifications.removeWhere((n) => n.id == notificationId);
        await loadUnreadCount();
        notifyListeners();
      }
    } catch (e) {
    }
  }
}
