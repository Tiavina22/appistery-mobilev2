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
      print('📚 [MyStoriesScreen] Chargement des histoires lues');
      setState(() {
        _isLoading = true;
      });

      final stories = await _readingService.getUserReadStories();

      setState(() {
        _readStories = stories;
        _isLoading = false;
      });

      print('  ✅ ${stories.length} histoires chargées');
    } catch (error) {
      print('  ❌ Erreur: $error');
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
      appBar: AppBar(
        title: Text('my_stories'.tr()),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)),
            )
          : _readStories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_books, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'no_stories_read'.tr(),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'explore_stories'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Filter tabs
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab(
                          label: 'all_stories'.tr(),
                          filter: 'all',
                          count: _readStories.length,
                        ),
                        _buildFilterTab(
                          label: 'reading'.tr(),
                          filter: 'reading',
                          count: _readStories
                              .where((s) => s['is_completed'] != true)
                              .length,
                        ),
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
                // Stories list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadReadStories,
                    child: ListView.separated(
                      itemCount: _filteredStories.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.3,
                        color: Colors.grey[300],
                        indent: 0,
                      ),
                      itemBuilder: (context, index) {
                        final story = _filteredStories[index];
                        return _buildStoryCard(context, story);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required String filter,
    required int count,
  }) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF1DB954) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black)
                    : Colors.grey[600],
              ),
            ),
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
            'dd MMM yyyy',
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

    // Extraire le synopsis
    String synopsis = '';
    if (story['synopsis'] is String) {
      synopsis = story['synopsis'];
    } else if (story['synopsis'] is Map) {
      final synopsisMap = story['synopsis'] as Map;
      synopsis =
          synopsisMap['gasy'] ?? synopsisMap['fr'] ?? synopsisMap['en'] ?? '';
    }

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
        color: Colors.transparent,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image circulaire (style Twitter/X)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: ClipOval(child: _buildCoverImage(story, size: 48)),
            ),
            const SizedBox(width: 12),
            // Story content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row (Title + Status + Time)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Status indicator
                      if (isCompleted)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green[600],
                        )
                      else
                        Icon(
                          Icons.auto_stories,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                      const SizedBox(width: 4),
                      Text(
                        '·',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate ?? 'Récent',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  if (synopsis.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    // Synopsis preview
                    Text(
                      synopsis,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
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

  Widget _buildCoverImage(Map<String, dynamic> story, {double size = 48}) {
    final coverUrl = story['cover_url'] ?? story['cover_image'];

    if (coverUrl == null || coverUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey[300],
        child: Icon(Icons.book, color: Colors.grey[600], size: size * 0.5),
      );
    }

    // Vérifier si c'est une image base64
    if (coverUrl.startsWith('data:image')) {
      try {
        final base64String = coverUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              color: Colors.grey[300],
              child: Icon(
                Icons.book,
                color: Colors.grey[600],
                size: size * 0.5,
              ),
            );
          },
        );
      } catch (e) {
        return Container(
          width: size,
          height: size,
          color: Colors.grey[300],
          child: Icon(Icons.book, color: Colors.grey[600], size: size * 0.5),
        );
      }
    }

    // Sinon, c'est une URL normale
    return Image.network(
      coverUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          color: Colors.grey[300],
          child: Icon(Icons.book, color: Colors.grey[600], size: size * 0.5),
        );
      },
    );
  }
}
