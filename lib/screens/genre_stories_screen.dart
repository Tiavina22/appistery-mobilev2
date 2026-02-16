import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/story_provider.dart';
import '../services/story_service.dart';
import 'story_detail_screen.dart';

class GenreStoriesScreen extends StatefulWidget {
  final int genreId;
  final String genreTitle;

  const GenreStoriesScreen({
    super.key,
    required this.genreId,
    required this.genreTitle,
  });

  @override
  State<GenreStoriesScreen> createState() => _GenreStoriesScreenState();
}

class _GenreStoriesScreenState extends State<GenreStoriesScreen> {
  final StoryService _storyService = StoryService();
  List<Story> _stories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStoriesByGenre();
  }

  Future<void> _loadStoriesByGenre() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Charger toutes les histoires et les filtrer par genre
      final allStories = await _storyService.getAllStories();
      final filteredStories = allStories
          .where(
            (story) =>
                story.genre.toLowerCase() == widget.genreTitle.toLowerCase(),
          )
          .toList();

      setState(() {
        _stories = filteredStories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.genreTitle),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(_error ?? 'Error loading stories'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStoriesByGenre,
              icon: const Icon(Icons.refresh),
              label: Text('retry'.tr()),
            ),
          ],
        ),
      );
    }

    if (_stories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books, size: 60, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text('no_data'.tr()),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: _stories.length,
      itemBuilder: (context, index) {
        final story = _stories[index];
        return _buildStoryGridItem(story);
      },
    );
  }

  Widget _buildStoryGridItem(Story story) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(story: story),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade900,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: story.coverImage != null && story.coverImage!.isNotEmpty
              ? _buildImageFromString(story.coverImage!)
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade900,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 60,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildImageFromString(String imageString) {
    // Vérifier si c'est une URL relative (commence par /uploads/)
    if (imageString.startsWith('/uploads/')) {
      final apiUrl = const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5500');
      final imageUrl = '$apiUrl$imageString';
      
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          );
        },
      );
    }
    
    if (imageString.startsWith('data:image')) {
      // Base64 image
      final base64String = imageString.split(',').last;
      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          );
        },
      );
    } else {
      // Network image or URL
      return Image.network(
        imageString,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          );
        },
      );
    }
  }
}
