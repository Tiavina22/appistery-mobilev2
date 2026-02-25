import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/reading_service.dart';
import '../services/story_service.dart';
import 'story_detail_screen.dart';

class MyStoriesScreen extends StatefulWidget {
  const MyStoriesScreen({super.key});

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen> {
  final ReadingService _readingService = ReadingService();
  List<Map<String, dynamic>> _readStories = [];
  bool _isLoading = false; // Commencer à false
  String _selectedFilter = 'all'; // all, reading, completed

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Charger le cache de manière synchrone d'abord
    final cachedStories = await _getCachedReadStories();
    if (cachedStories != null && cachedStories.isNotEmpty) {
      setState(() {
        _readStories = cachedStories;
      });
      // Rafraîchir en arrière-plan
      _refreshStoriesInBackground();
    } else {
      // Pas de cache, charger depuis le serveur
      _loadReadStories();
    }
  }

  Future<void> _loadReadStories() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final stories = await _readingService.getUserReadStories();

      setState(() {
        _readStories = stories;
        _isLoading = false;
      });
      
      await _cacheReadStories(stories);
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $error')),
        );
      }
    }
  }

  Future<void> _refreshStoriesInBackground() async {
    try {
      final stories = await _readingService.getUserReadStories();
      setState(() {
        _readStories = stories;
      });
      await _cacheReadStories(stories);
    } catch (e) {
      // Silencieusement échouer
    }
  }

  Future<void> _cacheReadStories(List<Map<String, dynamic>> stories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_read_stories', jsonEncode(stories));
      await prefs.setInt(
        'cached_read_stories_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Silencieusement échouer
    }
  }

  Future<List<Map<String, dynamic>>?> _getCachedReadStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('cached_read_stories_timestamp');
      
      if (timestamp == null) return null;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > Duration(minutes: 10).inMilliseconds) {
        return null;
      }
      
      final storiesJson = prefs.getString('cached_read_stories');
      if (storiesJson == null) return null;
      
      final List<dynamic> decoded = jsonDecode(storiesJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _filteredStories {
    if (_selectedFilter == 'completed') {
      return _readStories
          .where((story) => story['is_completed'] == true)
          .toList();
    } else if (_selectedFilter == 'reading') {
      return _readStories
          .where((story) => story['is_completed'] != true)
          .toList();
    }
    return _readStories;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF000000)
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large title with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'my_stories'.tr(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Filter tabs with iOS pill style - Keep visible once stories are loaded
            if (_readStories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterTab(
                        label: 'all_stories'.tr(),
                        filter: 'all',
                        count: _readStories.length,
                      ),
                      const SizedBox(width: 12),
                      _buildFilterTab(
                        label: 'reading'.tr(),
                        filter: 'reading',
                        count: _readStories
                            .where((s) => s['is_completed'] != true)
                            .length,
                      ),
                      const SizedBox(width: 12),
                      _buildFilterTab(
                        label: 'completed'.tr(),
                        filter: 'completed',
                        count: _readStories
                            .where((s) => s['is_completed'] == true)
                            .length,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Content
            if (_isLoading && _readStories.isEmpty)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFA586A)),
                  ),
                ),
              )
            else if (_readStories.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'no_stories_read'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'Commencez à lire pour voir vos histoires ici',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFA586A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'explore_stories'.tr(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredStories.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_list_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Aucune histoire',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aucune histoire dans cette catégorie',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadReadStories,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                    itemCount: _filteredStories.length,
                    itemBuilder: (context, index) {
                      final story = _filteredStories[index];
                      return _buildStoryCard(context, story);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required String filter,
    required int count,
  }) {
    final isSelected = _selectedFilter == filter;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.black54 : Colors.white70)
                      : Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, Map<String, dynamic> story) {
    final isCompleted = story['is_completed'] == true;

    return GestureDetector(
      onTap: () async {
        // Load complete story data including author and avatar
        try {
          final storyService = StoryService();
          final completeStory = await storyService.getStoryById(story['id']);
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoryDetailScreen(story: completeStory),
              ),
            );
            // Refresh list on return
            _loadReadStories();
          }
        } catch (e) {
          // Fallback: use available data
          final storyObj = Story.fromJson(story);
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoryDetailScreen(story: storyObj),
              ),
            );
            // Refresh list on return
            _loadReadStories();
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image
            _buildCoverImage(story),
            // Status badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFA586A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : Icons.auto_stories,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCompleted ? 'Terminé' : 'En cours',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(Map<String, dynamic> story) {
    final coverUrl = story['cover_url'] ?? story['cover_image'];

    if (coverUrl == null || coverUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[300],
        child: Icon(Icons.book, color: Colors.grey[600], size: 48),
      );
    }

    // Vérifier si c'est une URL relative (commence par /uploads/)
    if (coverUrl.startsWith('/uploads/')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
      final imageUrl = '$apiUrl$coverUrl';
      
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[300],
            child: Icon(Icons.book, color: Colors.grey[600], size: 48),
          );
        },
      );
    }

    // Vérifier si c'est une image base64
    if (coverUrl.startsWith('data:image')) {
      try {
        final base64String = coverUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[300],
              child: Icon(Icons.book, color: Colors.grey[600], size: 48),
            );
          },
        );
      } catch (e) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[300],
          child: Icon(Icons.book, color: Colors.grey[600], size: 48),
        );
      }
    }

    // Sinon, c'est une URL normale
    return Image.network(
      coverUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[300],
          child: Icon(Icons.book, color: Colors.grey[600], size: 48),
        );
      },
    );
  }
}
