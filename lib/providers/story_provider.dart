import 'package:flutter/material.dart';
import '../services/story_service.dart';
import '../services/websocket_service.dart';
import '../services/cache_service.dart';

class StoryProvider extends ChangeNotifier {
  final StoryService _storyService = StoryService();
  final WebSocketService _wsService = WebSocketService();
  final CacheService _cacheService = CacheService();

  List<Story> _stories = [];
  List<Story> _favorites = [];
  List<Story> _searchResults = [];
  List<Map<String, dynamic>> _genres = [];
  List<Author> _authors = [];
  bool _isLoading =
      true; // Commencer à true pour éviter l'affichage "no_data" avant le chargement
  bool _isLoadingMore = false;
  bool _hasMoreStories = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  String? _error;
  Map<String, List<Story>>? _storiesByGenreCache;

  // Getters
  List<Story> get stories => _stories;
  List<Story> get favorites => _favorites;
  List<Story> get searchResults => _searchResults;
  List<Map<String, dynamic>> get genres => _genres;
  List<Author> get authors => _authors;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreStories => _hasMoreStories;
  String? get error => _error;

  StoryProvider() {
    _initializeWebSocketListeners();
  }

  // Initialiser les listeners WebSocket
  void _initializeWebSocketListeners() {
    // Écouter les nouvelles histoires en temps réel
    _wsService.onNewStory((data) {

      try {
        // Créer une Story à partir des données WebSocket
        final newStory = Story.fromJson(data);

        // Vérifier si l'histoire n'existe pas déjà
        final exists = _stories.any((s) => s.id == newStory.id);
        if (!exists) {
          _stories.insert(0, newStory); // Ajouter au début de la liste
          
          // Invalider le cache pour forcer un rafraîchissement lors du prochain chargement
          _cacheService.invalidateStoriesCache();
          
          // Mettre à jour le cache avec les nouvelles données
          _cacheService.cacheStories(_stories);
          
          _storiesByGenreCache = null; // Invalider le cache par genre
          notifyListeners();
        } else {
        }
      } catch (e) {
      }
    });

    // Écouter les nouveaux chapitres
    _wsService.onNewChapter((data) {
      // Mettre à jour le nombre de chapitres de l'histoire concernée
      try {
        final storyId = data['story_id'] as int?;
        if (storyId != null) {
          final storyIndex = _stories.indexWhere((s) => s.id == storyId);
          if (storyIndex != -1) {
            // Recharger les stories pour avoir les données à jour
            loadStories();
          }
        }
      } catch (e) {
      }
    });

    // Écouter les mises à jour d'histoires
    _wsService.onStoryUpdated((data) {
      loadStories(); // Recharger toutes les histoires
    });

    // Écouter l'ajout d'un favori
    _wsService.onFavoriteAdded((data) {

      try {
        final storyId = data['story_id'] as int?;
        if (storyId != null) {
          // Ajouter à la liste des favoris
          final story = _stories.firstWhere(
            (s) => s.id == storyId,
            orElse: () => Story(
              id: storyId,
              title: data['title'] ?? 'Unknown',
              description: data['description'] ?? '',
              author: data['author_name'] ?? 'Unknown',
              genre: data['genre'] ?? '',
              coverImage: data['cover_image'],
              isFavorite: true,
              chapters: 0,
            ),
          );

          // Marquer comme favori
          if (!_favorites.any((s) => s.id == storyId)) {
            _favorites.add(story);
            
            // Invalider et mettre à jour le cache des favoris
            _cacheService.invalidateFavoritesCache();
            _cacheService.cacheFavorites(_favorites);
            
            notifyListeners();
          }
        }
      } catch (e) {
      }
    });

    // Écouter la suppression d'un favori
    _wsService.onFavoriteRemoved((data) {
      try {
        final storyId = data['story_id'] as int?;
        if (storyId != null) {
          // Retirer de la liste des favoris
          _favorites.removeWhere((s) => s.id == storyId);
          
          // Invalider et mettre à jour le cache des favoris
          _cacheService.invalidateFavoritesCache();
          _cacheService.cacheFavorites(_favorites);
          
          notifyListeners();
        }
      } catch (e) {
      }
    });

    // Écouter les mises à jour globales des favoris
    _wsService.onFavoritesUpdated((data) {
      loadFavorites(); // Recharger tous les favoris
    });

    // Écouter la liste des genres
    _wsService.onGenresList((data) {
      
      try {
        if (data is List) {
          _genres = List<Map<String, dynamic>>.from(
            data.map((genre) => Map<String, dynamic>.from(genre))
          );
          _isLoading = false;
          notifyListeners();
        }
      } catch (e) {
        _error = 'Erreur lors du traitement des genres';
        _isLoading = false;
        notifyListeners();
      }
    });

    // Écouter la liste des auteurs
    _wsService.onAuthorsList((data) {
      try {
        if (data is List) {
          _authors = data
            .map((author) => Author.fromJson(Map<String, dynamic>.from(author)))
            .toList();
          _isLoading = false;
          notifyListeners();
        }
      } catch (e) {
        _error = 'Erreur lors du traitement des auteurs';
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> loadStories() async {
    final startTime = DateTime.now();
    _isLoading = true;
    _error = null;
    _currentPage = 0;
    _hasMoreStories = true;
    _storiesByGenreCache = null; // Invalider le cache
    notifyListeners();

    try {
      // 1. Charger depuis le cache d'abord (ultra-rapide)
      final cachedStories = await _cacheService.getCachedStories();
      if (cachedStories != null && cachedStories.isNotEmpty) {
        _stories = cachedStories;
        _isLoading = false;
        _hasMoreStories = cachedStories.length >= _pageSize;
        _currentPage = 1;
        notifyListeners();
        
        // 2. Charger depuis le serveur en arrière-plan pour rafraîchir
        _refreshStoriesInBackground();
        return;
      }
      
      // 3. Si pas de cache, charger depuis le serveur
      _stories = await _storyService.getAllStoriesPaginated(
        limit: _pageSize,
        offset: 0,
      );
      
      // 4. Sauvegarder dans le cache
      await _cacheService.cacheStories(_stories);
      
      final duration = DateTime.now().difference(startTime);
      _error = null;
      _hasMoreStories = _stories.length >= _pageSize;
      _currentPage = 1;
    } catch (e) {
      _error = e.toString();
      _stories = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Rafraîchir les stories en arrière-plan
  Future<void> _refreshStoriesInBackground() async {
    try {
      final freshStories = await _storyService.getAllStoriesPaginated(
        limit: _pageSize,
        offset: 0,
      );
      
      if (freshStories.isNotEmpty) {
        _stories = freshStories;
        await _cacheService.cacheStories(_stories);
        _hasMoreStories = freshStories.length >= _pageSize;
        _currentPage = 1;
        notifyListeners();
      }
    } catch (e) {
      // Silencieusement échouer - on a déjà les données du cache
    }
  }

  Future<void> loadMoreStories() async {
    if (_isLoadingMore || !_hasMoreStories) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final offset = _currentPage * _pageSize;
      final newStories = await _storyService.getAllStoriesPaginated(
        limit: _pageSize,
        offset: offset,
      );

      if (newStories.isNotEmpty) {
        _stories.addAll(newStories);
        _storiesByGenreCache = null; // Invalider le cache
        _currentPage++;
        _hasMoreStories = newStories.length >= _pageSize;
        
        // Mettre à jour le cache avec toutes les stories
        await _cacheService.cacheStories(_stories);
      } else {
        _hasMoreStories = false;
      }
    } catch (e) {
      // Silencieusement échouer
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Charger depuis le cache d'abord
      final cachedFavorites = await _cacheService.getCachedFavorites();
      if (cachedFavorites != null) {
        _favorites = cachedFavorites;
        _isLoading = false;
        notifyListeners();
        
        // 2. Rafraîchir en arrière-plan
        _refreshFavoritesInBackground();
        return;
      }
      
      // 3. Si pas de cache, charger depuis le serveur
      _favorites = await _storyService.getFavorites();
      await _cacheService.cacheFavorites(_favorites);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _favorites = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshFavoritesInBackground() async {
    try {
      final freshFavorites = await _storyService.getFavorites();
      _favorites = freshFavorites;
      await _cacheService.cacheFavorites(_favorites);
      notifyListeners();
    } catch (e) {
      // Silencieusement échouer
    }
  }

  Future<void> searchStories(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _storyService.searchStories(query);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _searchResults = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleFavorite(int storyId) async {
    try {
      final story = _stories.firstWhere((s) => s.id == storyId);
      if (story.isFavorite) {
        await _storyService.removeFavorite(storyId);
      } else {
        await _storyService.addFavorite(storyId);
      }

      // Reload favorites
      await loadFavorites();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Grouper les histoires par genre
  Map<String, List<Story>> getStoriesByGenre() {
    // Retourner le cache si disponible
    if (_storiesByGenreCache != null) {
      return _storiesByGenreCache!;
    }

    final Map<String, List<Story>> grouped = {};

    for (final story in _stories) {
      if (!grouped.containsKey(story.genre)) {
        grouped[story.genre] = [];
      }
      grouped[story.genre]!.add(story);
    }

    _storiesByGenreCache = grouped; // Mettre en cache
    return grouped;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Charger tous les genres via cache puis WebSocket/HTTP
  Future<void> loadGenres() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Charger depuis le cache d'abord
      final cachedGenres = await _cacheService.getCachedGenres();
      if (cachedGenres != null && cachedGenres.isNotEmpty) {
        _genres = cachedGenres;
        _isLoading = false;
        notifyListeners();
        
        // 2. Rafraîchir en arrière-plan
        _refreshGenresInBackground();
        return;
      }

      // 3. Demander les genres via WebSocket
      _wsService.requestGenres();
      
      // 4. Attendre 2 secondes max pour la réponse WebSocket
      await Future.delayed(const Duration(seconds: 2));
      
      // 5. Si toujours vide après 2s, utiliser HTTP en fallback
      if (_genres.isEmpty) {
        _genres = await _storyService.getGenres();
        await _cacheService.cacheGenres(_genres);
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshGenresInBackground() async {
    try {
      final freshGenres = await _storyService.getGenres();
      if (freshGenres.isNotEmpty) {
        _genres = freshGenres;
        await _cacheService.cacheGenres(_genres);
        notifyListeners();
      }
    } catch (e) {
      // Silencieusement échouer
    }
  }

  // Charger tous les auteurs via cache puis WebSocket/HTTP
  Future<void> loadAuthors() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Charger depuis le cache d'abord
      final cachedAuthors = await _cacheService.getCachedAuthors();
      if (cachedAuthors != null && cachedAuthors.isNotEmpty) {
        _authors = cachedAuthors;
        _isLoading = false;
        notifyListeners();
        
        // 2. Rafraîchir en arrière-plan
        _refreshAuthorsInBackground();
        return;
      }

      // 3. Demander les auteurs via WebSocket
      _wsService.requestAuthors();
      
      // 4. Attendre 2 secondes max pour la réponse WebSocket
      await Future.delayed(const Duration(seconds: 2));
      
      // 5. Si toujours vide après 2s, utiliser HTTP en fallback
      if (_authors.isEmpty) {
        _authors = await _storyService.getAuthors();
        await _cacheService.cacheAuthors(_authors);
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshAuthorsInBackground() async {
    try {
      final freshAuthors = await _storyService.getAuthors();
      if (freshAuthors.isNotEmpty) {
        _authors = freshAuthors;
        await _cacheService.cacheAuthors(_authors);
        notifyListeners();
      }
    } catch (e) {
      // Silencieusement échouer
    }
  }
}
