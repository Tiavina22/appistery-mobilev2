import 'package:flutter/material.dart';
import '../services/story_service.dart';

class StoryProvider extends ChangeNotifier {
  final StoryService _storyService = StoryService();

  List<Story> _stories = [];
  List<Story> _favorites = [];
  List<Story> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Story> get stories => _stories;
  List<Story> get favorites => _favorites;
  List<Story> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadStories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stories = await _storyService.getAllStories();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _stories = [];
    }

    _isLoading = false;
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
    final Map<String, List<Story>> grouped = {};

    for (final story in _stories) {
      if (!grouped.containsKey(story.genre)) {
        grouped[story.genre] = [];
      }
      grouped[story.genre]!.add(story);
    }

    return grouped;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
