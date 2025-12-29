import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import '../services/story_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedGenre; // Pour tracker le genre sélectionné

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        Provider.of<StoryProvider>(context, listen: false).loadStories();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black87,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final avatarData = authProvider.user?['avatar'] as String?;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: avatarData != null && avatarData.isNotEmpty
                        ? ClipOval(child: _buildImageFromString(avatarData))
                        : const Icon(Icons.account_circle, color: Colors.white),
                  ),
                );
              },
            ),
          ),
          title: Text(
            'app_name'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (String value) {
                if (value == 'logout') {
                  _logout(context);
                } else if (value == 'settings') {
                  setState(() => _selectedIndex = 3);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings),
                      const SizedBox(width: 10),
                      Text('settings'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 10),
                      Text(
                        'logout'.tr(),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (int index) {
            setState(() => _selectedIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: const Color(0xFF1DB954),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: 'home'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.explore_outlined),
              activeIcon: const Icon(Icons.explore),
              label: 'search'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.favorite_border),
              activeIcon: const Icon(Icons.favorite),
              label: 'favorites'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: 'settings'.tr(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeTab(),
        _buildSearchTab(),
        _buildFavoritesTab(),
        _buildSettingsTab(),
      ],
    );
  }

  Widget _buildHomeTab() {
    return Consumer<StoryProvider>(
      builder: (context, storyProvider, _) {
        if (storyProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (storyProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 8),
                Text(storyProvider.error ?? ''),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => storyProvider.loadStories(),
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        if (storyProvider.stories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books,
                  size: 60,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 16),
                Text('no_data'.tr()),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildGenreSections(storyProvider),
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Consumer<StoryProvider>(
      builder: (context, storyProvider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  storyProvider.searchStories(value);
                },
                decoration: InputDecoration(
                  hintText: 'search_stories'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _searchController.text.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 60,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 16),
                          Text('search_placeholder'.tr()),
                        ],
                      ),
                    )
                  : storyProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : storyProvider.searchResults.isEmpty
                  ? Center(child: Text('no_results'.tr()))
                  : ListView.builder(
                      itemCount: storyProvider.searchResults.length,
                      itemBuilder: (context, index) {
                        final story = storyProvider.searchResults[index];
                        return _buildSearchResultTile(story);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return Consumer<StoryProvider>(
      builder: (context, storyProvider, _) {
        if (storyProvider.isLoading && storyProvider.favorites.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (storyProvider.favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 60,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 16),
                Text('no_favorites'.tr()),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _selectedIndex = 0);
                  },
                  icon: const Icon(Icons.explore),
                  label: Text('discover'.tr()),
                ),
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
          itemCount: storyProvider.favorites.length,
          itemBuilder: (context, index) {
            final story = storyProvider.favorites[index];
            return _buildStoryGridItem(story);
          },
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'theme'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text('light_mode'.tr()),
                      leading: const Icon(Icons.light_mode),
                      trailing: Radio<ThemeMode>(
                        value: ThemeMode.light,
                        groupValue: themeProvider.themeMode,
                        onChanged: (ThemeMode? value) {
                          if (value != null) {
                            themeProvider.setTheme(value);
                          }
                        },
                      ),
                    ),
                    ListTile(
                      title: Text('dark_mode'.tr()),
                      leading: const Icon(Icons.dark_mode),
                      trailing: Radio<ThemeMode>(
                        value: ThemeMode.dark,
                        groupValue: themeProvider.themeMode,
                        onChanged: (ThemeMode? value) {
                          if (value != null) {
                            themeProvider.setTheme(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Language Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'language'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('Français'),
                      leading: const Text('🇫🇷'),
                      trailing: Radio<Locale>(
                        value: const Locale('fr'),
                        groupValue: context.locale,
                        onChanged: (Locale? value) {
                          if (value != null) {
                            context.setLocale(value);
                          }
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('English'),
                      leading: const Text('🇬🇧'),
                      trailing: Radio<Locale>(
                        value: const Locale('en'),
                        groupValue: context.locale,
                        onChanged: (Locale? value) {
                          if (value != null) {
                            context.setLocale(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Account Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'account'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (authProvider.user != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email: ${authProvider.user!['email'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Username: ${authProvider.user!['username'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout),
                      label: Text('logout'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
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

  // Construire dynamiquement les sections par genre
  List<Widget> _buildGenreSections(StoryProvider storyProvider) {
    final storiesByGenre = storyProvider.getStoriesByGenre();
    final sections = <Widget>[];

    // Si un genre est sélectionné, afficher seulement ce genre
    if (_selectedGenre != null && storiesByGenre.containsKey(_selectedGenre)) {
      final stories = storiesByGenre[_selectedGenre]!;
      if (stories.isNotEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedGenre!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: stories.length,
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    return _buildStoryGridItem(story);
                  },
                ),
              ],
            ),
          ),
        ];
      }
    }

    // Sinon afficher tous les genres
    storiesByGenre.forEach((genre, stories) {
      if (stories.isNotEmpty) {
        sections.add(
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Genre Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      genre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedGenre = genre);
                      },
                      child: const Text('See All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stories in horizontal list
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.length,
                    itemBuilder: (context, index) {
                      final story = stories[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: _buildStoryCard(story),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return sections.isNotEmpty
        ? sections
        : [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('no_data'.tr()),
              ),
            ),
          ];
  }

  Widget _buildStoryCard(Story story) {
    return GestureDetector(
      onTap: () {
        // Navigate to story details
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade800,
        ),
        child: Stack(
          children: [
            // Background image with base64 or URL support
            if (story.coverImage != null && story.coverImage!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageFromString(story.coverImage!),
              )
            else
              Container(
                width: 140,
                color: Colors.grey.shade800,
                child: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
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

  Widget _buildSearchResultTile(Story story) {
    return ListTile(
      leading: story.coverImage != null
          ? SizedBox(
              width: 50,
              height: 70,
              child: _buildImageFromString(story.coverImage!),
            )
          : const SizedBox(width: 50, child: Icon(Icons.image)),
      title: Text(story.title),
      subtitle: Text(story.author),
      onTap: () {
        // Navigate to story details
      },
    );
  }

  Widget _buildStoryGridItem(Story story) {
    return GestureDetector(
      onTap: () {
        // Navigate to story details
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade800,
        ),
        child: Stack(
          children: [
            if (story.coverImage != null && story.coverImage!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageFromString(story.coverImage!),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade800,
                ),
                child: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.book, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${story.chapters} chapters',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
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

  // Helper method to detect and build image from base64 or URL
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
          width: 140,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG: Error decoding base64 image: $error');
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
          width: 140,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG: Error loading network image: $error');
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
      print('DEBUG: Exception in _buildImageFromString: $e');
      return Container(
        color: Colors.grey.shade800,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_logout'.tr()),
        content: Text('logout_warning'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('logout'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
