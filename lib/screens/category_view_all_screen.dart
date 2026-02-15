import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/story_service.dart';
import '../services/category_intelligence_service.dart';
import 'story_detail_screen.dart';

class CategoryViewAllScreen extends StatelessWidget {
  final String genreName;
  final String? intelligentTitle;
  final List<Story> stories;

  const CategoryViewAllScreen({
    super.key,
    required this.genreName,
    this.intelligentTitle,
    required this.stories,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Utiliser le titre intelligent si fourni, sinon générer un nouveau ou utiliser genreName
    final displayTitle = intelligentTitle ?? 
                        CategoryIntelligenceService().generateCategoryTitle(
                          genreName,
                          language: context.locale.languageCode,
                          currentTime: DateTime.now(),
                        );

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          displayTitle,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: stories.isEmpty
          ? Center(
              child: Text(
                'no_data'.tr(),
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: stories.length,
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    return _buildStoryGridItem(context, story);
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildStoryGridItem(BuildContext context, Story story) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isUserPremium = authProvider.isPremium;
    final isStoryPremium = story.isPremium;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        // Si l'histoire est premium et l'utilisateur n'est pas premium
        if (isStoryPremium && !isUserPremium) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('premium_story_message'.tr()),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'subscribe'.tr(),
                onPressed: () {
                  Navigator.of(context).pushNamed('/subscription-offers');
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(story: story),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Image de couverture
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: story.coverImage != null && story.coverImage!.isNotEmpty
                    ? _buildImageFromString(story.coverImage!)
                    : Container(
                        color: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade500,
                            size: 40,
                          ),
                        ),
                      ),
              ),
            ),
            // Badge Premium
            if (isStoryPremium)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Overlay bloquant pour histoires premium si non-premium
            if (isStoryPremium && !isUserPremium)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(
                      child: Icon(
                        Icons.lock,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFromString(String imageData) {
    try {
      // Check if it's a base64 string
      if (imageData.startsWith('data:image') || !imageData.startsWith('http')) {
        // It's likely base64
        String base64String = imageData;

        // Remove data URI prefix if present (e.g., 'data:image/png;base64,')
        if (imageData.startsWith('data:image')) {
          base64String = imageData.split(',').last;
        }

        return Image.memory(
          const Base64Decoder().convert(base64String),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade800,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        );
      } else {
        // It's a URL
        return Image.network(
          imageData,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade800,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      return Container(
        color: Colors.grey.shade800,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }
}
