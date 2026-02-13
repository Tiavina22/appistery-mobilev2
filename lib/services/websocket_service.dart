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

  bool get isConnected => _socket?.connected ?? false;
  IO.Socket? get socket => _socket;

  // Se connecter au serveur WebSocket
  Future<void> connect() async {
    if (_socket?.connected == true) {
      print('WebSocket: Already connected');
      return;
    }

    final token = await _authService.getToken();
    if (token == null) {
      print('WebSocket: No token available');
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

    print('📡 WebSocket: Connecting to $wsUrl');

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
        print('✅ WebSocket: Connected to server');
      });

      _socket!.onConnectError((error) {
        print('❌ WebSocket: Connection error: $error');
      });

      _socket!.onDisconnect((_) {
        print('❌ WebSocket: Disconnected from server');
      });

      _socket!.onError((error) {
        print('❌ WebSocket: Error: $error');
      });

      // Événements personnalisés de base
      _socket!.on('pong', (data) {
        print('✅ WebSocket: Pong received: $data');
      });

      _socket!.on('user:online', (data) {
        print('✅ WebSocket: User online: $data');
      });

      _socket!.on('user:offline', (data) {
        print('✅ WebSocket: User offline: $data');
      });

      // IMPORTANT: Enregistrer les listeners pour les histoires ICI
      _socket!.on('story:new', (data) {
        print('🔥🔥🔥 WebSocket: EVENT story:new reçu!');
        print('🔥🔥🔥 Data: $data');
        // Appeler tous les callbacks enregistrés
        for (var callback in _onNewStoryCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('❌ Erreur dans callback story:new: $e');
          }
        }
      });

      _socket!.on('chapter:new', (data) {
        print('🔥🔥🔥 WebSocket: EVENT chapter:new reçu!');
        print('🔥🔥🔥 Data: $data');
        // Appeler tous les callbacks enregistrés
        for (var callback in _onNewChapterCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('❌ Erreur dans callback chapter:new: $e');
          }
        }
      });

      _socket!.on('notification:received', (data) {
        print('🔥🔥🔥 WebSocket: EVENT notification:received reçu!');
        print('🔥🔥🔥 Data: $data');
        // Appeler tous les callbacks enregistrés
        for (var callback in _onNotificationCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('❌ Erreur dans callback notification:received: $e');
          }
        }
      });

      _socket!.on('story:updated', (data) {
        print('🔥🔥🔥 WebSocket: EVENT story:updated reçu!');
        print('🔥🔥🔥 Data: $data');
        // Appeler tous les callbacks enregistrés
        for (var callback in _onStoryUpdatedCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('❌ Erreur dans callback story:updated: $e');
          }
        }
      });

      // Événements de favoris
      _socket!.on('favorite:added', (data) {
        print('WebSocket: EVENT favorite:added reçu!');
        print('WebSocket: Data: $data');
        // Appeler tous les callbacks enregistrés
        for (var callback in _onFavoriteAddedCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('Erreur dans callback favorite:added: $e');
          }
        }
      });

      _socket!.on('favorite:removed', (data) {
        print('WebSocket: EVENT favorite:removed reçu!');
        print('WebSocket: Data: $data');
        // Appeler tous les callbacks enregistrés
        for (var callback in _onFavoriteRemovedCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('Erreur dans callback favorite:removed: $e');
          }
        }
      });
      // Événements pour genres et auteurs
      _socket!.on('genres:list', (data) {
        print('🔥 WebSocket: EVENT genres:list reçu!');
        print('🔥 Data: $data');
        for (var callback in _onGenresListCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('❌ Erreur dans callback genres:list: $e');
          }
        }
      });

      _socket!.on('authors:list', (data) {
        print('🔥 WebSocket: EVENT authors:list reçu!');
        print('🔥 Data: $data');
        for (var callback in _onAuthorsListCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('❌ Erreur dans callback authors:list: $e');
          }
        }
      });
      _socket!.on('favorites:updated', (data) {
        print('WebSocket: EVENT favorites:updated reçu!');
        print('WebSocket: Data: $data');
        // Appeler tous les callbacks enregistrés
        for (var callback in _onFavoritesUpdatedCallbacks) {
          try {
            callback(data);
          } catch (e) {
            print('Erreur dans callback favorites:updated: $e');
          }
        }
      });
    } catch (e) {
      print('WebSocket: Error initializing: $e');
    }
  }

  // Se déconnecter
  void disconnect() {
    if (_socket?.connected == true) {
      _socket!.disconnect();
      print('WebSocket: Disconnected');
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
    print('WebSocket: Enregistrement callback notification');
    _onNotificationCallbacks.add(callback);
  }

  // Écouter les nouvelles histoires
  void onNewStory(Function(dynamic) callback) {
    print('WebSocket: Enregistrement callback story:new');
    _onNewStoryCallbacks.add(callback);
  }

  // Écouter les nouveaux chapitres
  void onNewChapter(Function(dynamic) callback) {
    print('WebSocket: Enregistrement callback chapter:new');
    _onNewChapterCallbacks.add(callback);
  }

  // Écouter les mises à jour d'histoires
  void onStoryUpdated(Function(dynamic) callback) {
    print('WebSocket: Enregistrement callback story:updated');
    _onStoryUpdatedCallbacks.add(callback);
  }

  // Écouter l'ajout d'un favori
  void onFavoriteAdded(Function(dynamic) callback) {
    print('WebSocket: Enregistrement callback favorite:added');
    _onFavoriteAddedCallbacks.add(callback);
  }

  // Écouter la suppression d'un favori
  void onFavoriteRemoved(Function(dynamic) callback) {
    print('WebSocket: Enregistrement callback favorite:removed');
    _onFavoriteRemovedCallbacks.add(callback);
  }

  // Écouter les mises à jour globales des favoris
  void onFavoritesUpdated(Function(dynamic) callback) {
    print('WebSocket: Enregistrement callback favorites:updated');
    _onFavoritesUpdatedCallbacks.add(callback);
  }

  // Écouter la liste des genres
  void onGenresList(Function(dynamic) callback) {
    print('WebSocket: Enregistrement callback genres:list');
    _onGenresListCallbacks.add(callback);
  }

  // Écouter la liste des auteurs
  void onAuthorsList(Function(dynamic) callback) {
    print('WebSocket: Enregistrement callback authors:list');
    _onAuthorsListCallbacks.add(callback);
  }

  // Demander la liste des genres
  void requestGenres() {
    if (_socket?.connected == true) {
      print('📡 WebSocket: Demande de la liste des genres');
      _socket!.emit('genres:request');
    }
  }

  // Demander la liste des auteurs
  void requestAuthors() {
    if (_socket?.connected == true) {
      print('📡 WebSocket: Demande de la liste des auteurs');
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
