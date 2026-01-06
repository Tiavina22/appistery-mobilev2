import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import '../providers/websocket_provider.dart';
import '../services/story_service.dart';
import 'login_screen.dart';
import 'story_detail_screen.dart';
import 'author_profile_screen.dart';
import 'genre_stories_screen.dart';

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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 60,
          title: Image.asset('assets/logo/logo-appistery-no.png', height: 28),
          actions: [
            // Indicateur WebSocket
            Consumer<WebSocketProvider>(
              builder: (context, wsProvider, _) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: wsProvider.isConnected
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: wsProvider.isConnected
                              ? Colors.green
                              : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        wsProvider.isConnected ? 'En ligne' : 'Hors ligne',
                        style: TextStyle(
                          color: wsProvider.isConnected
                              ? Colors.green
                              : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Icône notifications
            IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: 26,
              ),
              onPressed: () {
                // TODO: Notifications
              },
            ),
            const SizedBox(width: 8),
            // Avatar
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  final avatarData = authProvider.user?['avatar'] as String?;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: avatarData != null && avatarData.isNotEmpty
                          ? ClipOval(child: _buildAvatarImage(avatarData))
                          : const Icon(
                              Icons.account_circle,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (int index) {
            setState(() => _selectedIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF1DB954),
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

  Widget _buildNavItem(String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[400],
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
        // Load genres and authors on first build
        if (storyProvider.genres.isEmpty) {
          storyProvider.loadGenres();
          storyProvider.loadAuthors();
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search TextField
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

              // Si recherche vide, afficher les genres et auteurs
              if (_searchController.text.isEmpty) ...[
                // Section Auteurs
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Text(
                    'Featured creators',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Authors List (Horizontal Scroll)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: storyProvider.authors.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(
                              storyProvider.authors.length,
                              (index) {
                                final author = storyProvider.authors[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildAuthorCard(author),
                                );
                              },
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 24),

                // Section Genres
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Text(
                    'Browse all',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Genres Grid (Spotify style)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: storyProvider.genres.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(),
                        )
                      : GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.5,
                              ),
                          itemCount: storyProvider.genres.length,
                          itemBuilder: (context, index) {
                            final genre = storyProvider.genres[index];
                            return _buildGenreCard(genre, context);
                          },
                        ),
                ),

                const SizedBox(height: 24),
              ] else ...[
                // Résultats de recherche
                if (storyProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (storyProvider.searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: Text('no_results'.tr())),
                  )
                else
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: storyProvider.searchResults.length,
                    itemBuilder: (context, index) {
                      final story = storyProvider.searchResults[index];
                      return _buildSearchResultTile(story);
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Genre Card (Spotify style - colorful background)
  Widget _buildGenreCard(Map<String, dynamic> genre, BuildContext context) {
    final colors = [
      const Color(0xFF1DB954), // Green
      const Color(0xFFE61828), // Red
      const Color(0xFF007FD5), // Blue
      const Color(0xFFA239CA), // Purple
      const Color(0xFFF39C12), // Orange
      const Color(0xFF1ABC9C), // Teal
    ];

    final randomColor = colors[(genre['id'] as int) % colors.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenreStoriesScreen(
              genreId: genre['id'] ?? 0,
              genreTitle: genre['title'] ?? 'Unknown',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: randomColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                genre['title'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Author Card
  Widget _buildAuthorCard(Author author) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthorProfileScreen(
              authorId: author.id,
              authorName: author.pseudo,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withOpacity(0.3),
            ),
            child: author.avatar != null && author.avatar!.isNotEmpty
                ? ClipOval(child: _buildAvatarImage(author.avatar!))
                : Icon(Icons.person, size: 60, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              author.pseudo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

  // Settings tab is now in a separate SettingsScreen
  // This method is kept for reference but is no longer used
  /*
  Widget _buildSettingsTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme & Language Settings in one card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Theme
                    Text(
                      'theme'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF181818)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                themeProvider.themeMode == ThemeMode.dark
                                    ? Icons.dark_mode
                                    : Icons.light_mode,
                                color: const Color(0xFF1DB954),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                themeProvider.themeMode == ThemeMode.dark
                                    ? 'dark_mode'.tr()
                                    : 'light_mode'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: themeProvider.themeMode == ThemeMode.dark,
                              onChanged: (bool value) {
                                themeProvider.setTheme(
                                  value ? ThemeMode.dark : ThemeMode.light,
                                );
                              },
                              activeColor: const Color(0xFF1DB954),
                              activeTrackColor: const Color(
                                0xFF1DB954,
                              ).withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Language
                    Text(
                      'language'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF181818)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: DropdownButton<Locale>(
                        value: context.locale,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF181818)
                            : Colors.grey[100],
                        items: const [
                          DropdownMenuItem(
                            value: Locale('fr'),
                            child: Row(
                              children: [
                                Text('🇫🇷', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 10),
                                Text(
                                  'Français',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: Locale('en'),
                            child: Row(
                              children: [
                                Text('🇬🇧', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 10),
                                Text('English', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
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
            const SizedBox(height: 12),
            // Account Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'account'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (authProvider.user != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email: ${authProvider.user!['email'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Username: ${authProvider.user!['username'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text('logout'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
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
  */

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
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
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
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
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
                  height: 180,
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(story: story),
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade900,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: story.coverImage != null && story.coverImage!.isNotEmpty
              ? _buildImageFromString(story.coverImage!)
              : Container(
                  width: 140,
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(story: story),
          ),
        );
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

  // Helper method for avatar images (smaller, circular)
  Widget _buildAvatarImage(String imageData) {
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
          width: 32,
          height: 32,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG Avatar: Error decoding base64 image: $error');
            return const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 24,
            );
          },
        );
      } else {
        // It's a URL
        return Image.network(
          imageData,
          fit: BoxFit.cover,
          width: 32,
          height: 32,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG Avatar: Error loading network image: $error');
            return const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 24,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            );
          },
        );
      }
    } catch (e) {
      print('DEBUG Avatar: Exception in _buildAvatarImage: $e');
      return const Icon(Icons.account_circle, color: Colors.white, size: 24);
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

  Widget _buildSettingsTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display Section
            _buildSectionTitle('display'.tr()),
            _buildDisplaySection(context),
            const SizedBox(height: 16),

            // Account Section
            _buildSectionTitle('account'.tr()),
            _buildAccountSection(context),
            const SizedBox(height: 16),

            // Notifications Section
            _buildSectionTitle('notifications'.tr()),
            _buildNotificationsSection(context),
            const SizedBox(height: 16),

            // Privacy & Security Section
            _buildSectionTitle('privacy_security'.tr()),
            _buildPrivacySection(context),
            const SizedBox(height: 16),

            // About Section
            _buildSectionTitle('about'.tr()),
            _buildAboutSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1DB954),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDisplaySection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        // Theme Toggle
        _buildSettingsTile(
          icon: Icons.brightness_4,
          title: 'theme'.tr(),
          subtitle: themeProvider.themeMode == ThemeMode.dark
              ? 'dark_mode'.tr()
              : 'light_mode'.tr(),
          trailing: Switch(
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (bool value) {
              themeProvider.setTheme(value ? ThemeMode.dark : ThemeMode.light);
            },
            activeColor: const Color(0xFF1DB954),
          ),
        ),

        // Language Selection
        _buildSettingsTile(
          icon: Icons.language,
          title: 'language'.tr(),
          subtitle: _getLanguageLabel(context.locale),
          onTap: () => _showLanguageDialog(context),
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Column(
      children: [
        // Profile Info
        if (authProvider.user != null)
          _buildSettingsTile(
            icon: Icons.person,
            title: authProvider.user!['username'] ?? 'User',
            subtitle: authProvider.user!['email'] ?? 'No email',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to profile edit
            },
          ),

        // Change Password
        _buildSettingsTile(
          icon: Icons.lock,
          title: 'change_password'.tr(),
          subtitle: 'update_password_subtitle'.tr(),
          onTap: () {
            // Navigate to change password screen
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        // Logout
        _buildSettingsTile(
          icon: Icons.logout,
          title: 'logout'.tr(),
          subtitle: 'logout_subtitle'.tr(),
          onTap: () => _confirmLogout(context),
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.red.withOpacity(0.7),
          ),
          titleColor: Colors.red,
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return Column(
      children: [
        // Push Notifications
        _buildSettingsTile(
          icon: Icons.notifications,
          title: 'push_notifications'.tr(),
          subtitle: 'enable_notifications'.tr(),
          trailing: Switch(
            value: true,
            onChanged: (bool value) {
              // Handle notification toggle
            },
            activeColor: const Color(0xFF1DB954),
          ),
        ),

        // Email Notifications
        _buildSettingsTile(
          icon: Icons.mail,
          title: 'email_notifications'.tr(),
          subtitle: 'email_notification_subtitle'.tr(),
          trailing: Switch(
            value: true,
            onChanged: (bool value) {
              // Handle email notification toggle
            },
            activeColor: const Color(0xFF1DB954),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return Column(
      children: [
        // Private Account
        _buildSettingsTile(
          icon: Icons.privacy_tip,
          title: 'private_account'.tr(),
          subtitle: 'private_account_subtitle'.tr(),
          trailing: Switch(
            value: false,
            onChanged: (bool value) {
              // Handle private account toggle
            },
            activeColor: const Color(0xFF1DB954),
          ),
        ),

        // Block Users
        _buildSettingsTile(
          icon: Icons.block,
          title: 'blocked_users'.tr(),
          subtitle: 'manage_blocked_users'.tr(),
          onTap: () {
            // Navigate to blocked users
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        // Privacy Policy
        _buildSettingsTile(
          icon: Icons.description,
          title: 'privacy_policy'.tr(),
          subtitle: 'read_our_privacy_policy'.tr(),
          onTap: () {
            // Open privacy policy
          },
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      children: [
        // Version
        _buildSettingsTile(
          icon: Icons.info,
          title: 'version'.tr(),
          subtitle: 'v1.0.0',
          trailing: const SizedBox.shrink(),
        ),

        // Terms of Service
        _buildSettingsTile(
          icon: Icons.assignment,
          title: 'terms_of_service'.tr(),
          subtitle: 'read_our_terms'.tr(),
          onTap: () {
            // Open terms
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        // Contact Support
        _buildSettingsTile(
          icon: Icons.help,
          title: 'contact_support'.tr(),
          subtitle: 'get_help_support'.tr(),
          onTap: () {
            // Open support
          },
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: titleColor ?? const Color(0xFF1DB954),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageLabel(Locale locale) {
    if (locale.languageCode == 'fr') {
      return 'Français';
    } else if (locale.languageCode == 'en') {
      return 'English';
    }
    return 'Unknown';
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('select_language'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('🇫🇷 Français'),
                onTap: () {
                  context.setLocale(const Locale('fr'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('🇬🇧 English'),
                onTap: () {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('confirm_logout'.tr()),
          content: Text('logout_confirmation_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logout(context);
              },
              child: Text(
                'logout'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
