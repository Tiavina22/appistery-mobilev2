import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, reading, completed

  @override
  void initState() {
    super.initState();
    _loadReadStories();
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
            // Filter tabs with iOS pill style
            if (!_isLoading && _readStories.isNotEmpty) ...[
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
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
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
                          backgroundColor: const Color(0xFF1DB954),
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
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.65,
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
    final completedAt = story['completed_at'];
    final formattedDate = completedAt != null
        ? DateFormat(
            'dd MMM',
            'fr_FR',
          ).format(DateTime.parse(completedAt.toString()))
        : null;

    // Extraire le titre depuis le JSON
    String title = 'Sans titre';
    if (story['title'] is String) {
      title = story['title'];
    } else if (story['title'] is Map) {
      final titleMap = story['title'] as Map;
      title =
          titleMap['gasy'] ?? titleMap['fr'] ?? titleMap['en'] ?? 'Sans titre';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        // Convert story map to Story object
        final storyObj = Story.fromJson(story);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(story: storyObj),
          ),
        );
        // Refresh list on return
        _loadReadStories();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _buildCoverImage(story),
                  ),
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
                        color: isCompleted
                            ? Colors.green.withOpacity(0.9)
                            : Colors.blue.withOpacity(0.9),
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
            // Title and date
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (formattedDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
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
