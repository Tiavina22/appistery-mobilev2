import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  final AuthService _authService = AuthService();

  // Callbacks pour les événements
  final List<Function(dynamic)> _onNewStoryCallbacks = [];
  final List<Function(dynamic)> _onNewChapterCallbacks = [];
  final List<Function(dynamic)> _onStoryUpdatedCallbacks = [];
  final List<Function(dynamic)> _onNotificationCallbacks = [];
  final List<Function(dynamic)> _onFavoriteAddedCallbacks = [];
  final List<Function(dynamic)> _onFavoriteRemovedCallbacks = [];
  final List<Function(dynamic)> _onFavoritesUpdatedCallbacks = [];
  final List<Function(dynamic)> _onGenresListCallbacks = [];
  final List<Function(dynamic)> _onAuthorsListCallbacks = [];
  final List<Function(dynamic)> _onSubscriptionUpdatedCallbacks = [];
  final List<Function(dynamic)> _onSubscriptionActivatedCallbacks = [];
  final List<Function(dynamic)> _onSubscriptionExpiredCallbacks = [];
  final List<Function(dynamic)> _onCommentAddedCallbacks = [];

  bool get isConnected => _socket?.connected ?? false;
  IO.Socket? get socket => _socket;

  // Se connecter au serveur WebSocket
  Future<void> connect() async {
    if (_socket?.connected == true) {
      return;
    }

    final token = await _authService.getToken();
    if (token == null) {
      return;
    }

    final apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:5500';

    // Convertir l'API_URL en WebSocket URL appropriée
    String wsUrl = apiUrl;
    if (apiUrl.startsWith('https://')) {
      // Utiliser WSS pour HTTPS
      wsUrl = apiUrl.replaceFirst('https://', 'wss://');
    } else if (apiUrl.startsWith('http://')) {
      // Utiliser WS pour HTTP
      wsUrl = apiUrl.replaceFirst('http://', 'ws://');
    }

    try {
      _socket = IO.io(
        wsUrl,
        IO.OptionBuilder()
            .setTransports([
              'websocket',
              'polling',
            ]) // Try websocket first, then polling
            .disableAutoConnect()
            .setAuth({'token': token})
            .enableForceNew()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(5)
            .build(),
      );

      _socket!.connect();

      // Événements de connexion
      _socket!.onConnect((_) {
      });

      _socket!.onConnectError((error) {
      });

      _socket!.onDisconnect((_) {
      });

      _socket!.onError((error) {
      });

      // Événements personnalisés de base
      _socket!.on('pong', (data) {
      });

      _socket!.on('user:online', (data) {
      });

      _socket!.on('user:offline', (data) {
      });

      // IMPORTANT: Enregistrer les listeners pour les histoires ICI
      _socket!.on('story:new', (data) {
        // Appeler tous les callbacks enregistrés
        for (var callback in _onNewStoryCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      _socket!.on('chapter:new', (data) {
        // Appeler tous les callbacks enregistrés
        for (var callback in _onNewChapterCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      _socket!.on('notification:received', (data) {
        // Appeler tous les callbacks enregistrés
        for (var callback in _onNotificationCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      _socket!.on('story:updated', (data) {
        // Appeler tous les callbacks enregistrés
        for (var callback in _onStoryUpdatedCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      // Événements de favoris
      _socket!.on('favorite:added', (data) {
        // Appeler tous les callbacks enregistrés
        for (var callback in _onFavoriteAddedCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      _socket!.on('favorite:removed', (data) {
        // Appeler tous les callbacks enregistrés
        for (var callback in _onFavoriteRemovedCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });
      // Événements pour genres et auteurs
      _socket!.on('genres:list', (data) {
        for (var callback in _onGenresListCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      _socket!.on('authors:list', (data) {
        for (var callback in _onAuthorsListCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });
      _socket!.on('favorites:updated', (data) {
        // Appeler tous les callbacks enregistrés
        for (var callback in _onFavoritesUpdatedCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      // Événements pour les abonnements
      _socket!.on('subscription:updated', (data) {
        for (var callback in _onSubscriptionUpdatedCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      _socket!.on('subscription:activated', (data) {
        for (var callback in _onSubscriptionActivatedCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      _socket!.on('subscription:expired', (data) {
        for (var callback in _onSubscriptionExpiredCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });

      _socket!.on('comment:added', (data) {
        for (var callback in _onCommentAddedCallbacks) {
          try {
            callback(data);
          } catch (e) {
          }
        }
      });
    } catch (e) {
    }
  }

  // Se déconnecter
  void disconnect() {
    if (_socket?.connected == true) {
      _socket!.disconnect();
    }
  }

  // Envoyer un ping
  void sendPing() {
    if (_socket?.connected == true) {
      _socket!.emit('ping', {'timestamp': DateTime.now().toIso8601String()});
    }
  }

  // Écouter les notifications
  void onNotification(Function(dynamic) callback) {
    _onNotificationCallbacks.add(callback);
  }

  // Écouter les nouvelles histoires
  void onNewStory(Function(dynamic) callback) {
    _onNewStoryCallbacks.add(callback);
  }

  // Écouter les nouveaux chapitres
  void onNewChapter(Function(dynamic) callback) {
    _onNewChapterCallbacks.add(callback);
  }

  // Écouter les mises à jour d'histoires
  void onStoryUpdated(Function(dynamic) callback) {
    _onStoryUpdatedCallbacks.add(callback);
  }

  // Écouter l'ajout d'un favori
  void onFavoriteAdded(Function(dynamic) callback) {
    _onFavoriteAddedCallbacks.add(callback);
  }

  // Écouter la suppression d'un favori
  void onFavoriteRemoved(Function(dynamic) callback) {
    _onFavoriteRemovedCallbacks.add(callback);
  }

  // Écouter les mises à jour globales des favoris
  void onFavoritesUpdated(Function(dynamic) callback) {
    _onFavoritesUpdatedCallbacks.add(callback);
  }

  // Écouter la liste des genres
  void onGenresList(Function(dynamic) callback) {
    _onGenresListCallbacks.add(callback);
  }

  // Écouter la liste des auteurs
  void onAuthorsList(Function(dynamic) callback) {
    _onAuthorsListCallbacks.add(callback);
  }

  // Écouter les mises à jour d'abonnement
  void onSubscriptionUpdated(Function(dynamic) callback) {
    _onSubscriptionUpdatedCallbacks.add(callback);
  }

  // Écouter les nouveaux abonnements activés
  void onSubscriptionActivated(Function(dynamic) callback) {
    _onSubscriptionActivatedCallbacks.add(callback);
  }

  // Écouter les abonnements expirés
  void onSubscriptionExpired(Function(dynamic) callback) {
    _onSubscriptionExpiredCallbacks.add(callback);
  }

  // Écouter les nouveaux commentaires
  void onCommentAdded(Function(dynamic) callback) {
    _onCommentAddedCallbacks.add(callback);
  }

  // Demander la liste des genres
  void requestGenres() {
    if (_socket?.connected == true) {
      _socket!.emit('genres:request');
    }
  }

  // Demander la liste des auteurs
  void requestAuthors() {
    if (_socket?.connected == true) {
      _socket!.emit('authors:request');
    }
  }

  // Écouter les utilisateurs qui tapent
  void onUserTyping(Function(dynamic) callback) {
    _socket?.on('user:typing', callback);
  }

  // Envoyer une notification de typing
  void sendTypingStart({String? roomId}) {
    if (_socket?.connected == true) {
      _socket!.emit('typing:start', {'roomId': roomId});
    }
  }

  void sendTypingStop({String? roomId}) {
    _socket?.connected == true
        ? _socket!.emit('typing:stop', {'roomId': roomId})
        : null;
  }

  // Envoyer une notification à un utilisateur
  void sendNotificationToUser(
    int targetUserId,
    Map<String, dynamic> notification,
  ) {
    if (_socket?.connected == true) {
      _socket!.emit('send:notification', {
        'targetUserId': targetUserId,
        'notification': notification,
      });
    }
  }

  // Broadcaster une nouvelle histoire
  void broadcastStoryPublished(Map<String, dynamic> story) {
    if (_socket?.connected == true) {
      _socket!.emit('story:published', story);
    }
  }

  // Broadcaster un nouveau chapitre
  void broadcastChapterPublished(Map<String, dynamic> chapter) {
    if (_socket?.connected == true) {
      _socket!.emit('chapter:published', chapter);
    }
  }

  // Notifier la mise à jour du profil
  void notifyProfileUpdated(Map<String, dynamic> profileData) {
    if (_socket?.connected == true) {
      _socket!.emit('profile:updated', profileData);
    }
  }

  // Retirer tous les listeners
  void removeAllListeners() {
    _socket?.clearListeners();
  }

  // Retirer un listener spécifique
  void off(String event) {
    _socket?.off(event);
  }
}
