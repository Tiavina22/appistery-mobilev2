import 'package:flutter/material.dart';
import '../services/story_service.dart';
import '../services/websocket_service.dart';

class StoryProvider extends ChangeNotifier {
  final StoryService _storyService = StoryService();
  final WebSocketService _wsService = WebSocketService();

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
      print('📚 StoryProvider: Nouvelle histoire reçue via WebSocket');
      print('Data: $data');

      try {
        // Créer une Story à partir des données WebSocket
        final newStory = Story.fromJson(data);

        // Vérifier si l'histoire n'existe pas déjà
        final exists = _stories.any((s) => s.id == newStory.id);
        if (!exists) {
          _stories.insert(0, newStory); // Ajouter au début de la liste
          notifyListeners();
          print('✅ Histoire ajoutée à la liste');
        } else {
          print('ℹ️ Histoire déjà présente dans la liste');
        }
      } catch (e) {
        print('❌ Erreur lors de l\'ajout de la nouvelle histoire: $e');
      }
    });

    // Écouter les nouveaux chapitres
    _wsService.onNewChapter((data) {
      print('📖 StoryProvider: Nouveau chapitre reçu via WebSocket');
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
        print('❌ Erreur lors de la mise à jour des chapitres: $e');
      }
    });

    // Écouter les mises à jour d'histoires
    _wsService.onStoryUpdated((data) {
      print('🔄 StoryProvider: Histoire mise à jour via WebSocket');
      loadStories(); // Recharger toutes les histoires
    });

    // Écouter l'ajout d'un favori
    _wsService.onFavoriteAdded((data) {
      print('❤️ StoryProvider: Favori ajouté via WebSocket');
      print('Data: $data');

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
            notifyListeners();
            print('✅ Favori ajouté à la liste');
          }
        }
      } catch (e) {
        print('❌ Erreur lors de l\'ajout du favori: $e');
      }
    });

    // Écouter la suppression d'un favori
    _wsService.onFavoriteRemoved((data) {
      print('💔 StoryProvider: Favori supprimé via WebSocket');
      print('Data: $data');

      try {
        final storyId = data['story_id'] as int?;
        if (storyId != null) {
          // Retirer de la liste des favoris
          _favorites.removeWhere((s) => s.id == storyId);
          notifyListeners();
          print('✅ Favori supprimé de la liste');
        }
      } catch (e) {
        print('❌ Erreur lors de la suppression du favori: $e');
      }
    });

    // Écouter les mises à jour globales des favoris
    _wsService.onFavoritesUpdated((data) {
      print('🔄 StoryProvider: Favoris mis à jour via WebSocket');
      loadFavorites(); // Recharger tous les favoris
    });
  }

  Future<void> loadStories() async {
    print('📚 StoryProvider.loadStories: Début du chargement...');
    final startTime = DateTime.now();
    _isLoading = true;
    _error = null;
    _currentPage = 0;
    _hasMoreStories = true;
    _storiesByGenreCache = null; // Invalider le cache
    notifyListeners();

    try {
      _stories = await _storyService.getAllStoriesPaginated(
        limit: _pageSize,
        offset: 0,
      );
      final duration = DateTime.now().difference(startTime);
      print(
        '📚 StoryProvider.loadStories: ${_stories.length} histoires chargées en ${duration.inMilliseconds}ms',
      );
      _error = null;
      _hasMoreStories = _stories.length >= _pageSize;
      _currentPage = 1;
    } catch (e) {
      print('❌ StoryProvider.loadStories: Erreur - $e');
      _error = e.toString();
      _stories = [];
    }

    _isLoading = false;
    notifyListeners();
    print(
      '📚 StoryProvider.loadStories: Terminé (${_stories.length} histoires)',
    );
  }

  Future<void> loadMoreStories() async {
    if (_isLoadingMore || !_hasMoreStories) return;

    print('📚 StoryProvider.loadMoreStories: Chargement page $_currentPage...');
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
        print(
          '✅ ${newStories.length} histoires ajoutées (Total: ${_stories.length})',
        );
      } else {
        _hasMoreStories = false;
        print('🚫 Plus d\'histoires à charger');
      }
    } catch (e) {
      print('❌ StoryProvider.loadMoreStories: Erreur - $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _favorites = await _storyService.getFavorites();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _favorites = [];
    }

    _isLoading = false;
    notifyListeners();
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

  // Charger tous les genres
  Future<void> loadGenres() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _genres = await _storyService.getGenres();
      print('✅ ${_genres.length} genres loaded');
    } catch (e) {
      _error = e.toString();
      print('❌ Error loading genres: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Charger tous les auteurs
  Future<void> loadAuthors() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _authors = await _storyService.getAuthors();
      print('✅ ${_authors.length} authors loaded');
    } catch (e) {
      _error = e.toString();
      print('❌ Error loading authors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
