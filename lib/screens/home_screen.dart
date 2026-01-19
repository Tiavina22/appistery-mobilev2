import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/notification_provider.dart';
import '../services/story_service.dart';
import 'login_screen.dart';
import 'story_detail_screen.dart';
import 'author_profile_screen.dart';
import 'genre_stories_screen.dart';
import 'my_stories_screen.dart';
import 'user_profile_screen.dart';
import 'cgu_screen.dart';
import 'notifications_screen.dart';
import 'subscription_offers_screen.dart';
import 'change_password_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedGenre; // Pour tracker le genre sélectionné

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    Future.microtask(() async {
      if (mounted) {
        final storyProvider = Provider.of<StoryProvider>(
          context,
          listen: false,
        );

        // Configurer les listeners WebSocket en premier (non bloquant)
        _setupNotificationListeners();

        // Charger les histoires en priorité (contenu principal)
        await storyProvider.loadStories();

        // Charger genres et auteurs en parallèle (moins critique)
        Future.wait([
          storyProvider.loadGenres(),
          storyProvider.loadAuthors(),
          Provider.of<NotificationProvider>(
            context,
            listen: false,
          ).loadNotifications(),
        ]);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Charger plus d'histoires quand on est à 200px de la fin
      final storyProvider = Provider.of<StoryProvider>(context, listen: false);
      if (!storyProvider.isLoadingMore && storyProvider.hasMoreStories) {
        storyProvider.loadMoreStories();
      }
    }
  }

  void _setupNotificationListeners() {
    final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );

    // Écouter les nouvelles notifications
    wsProvider.on('notification:newWithBadge', (data) {
      print('🔔 Nouvelle notification reçue: $data');

      final notification = AppNotification(
        id: data['notification']['id'],
        user_id: 0, // Sera rempli par le serveur
        type: data['notification']['type'],
        title: data['notification']['title'],
        message: data['notification']['message'],
        actor_id: data['notification']['actor_id'],
        related_story_id: data['notification']['related_story_id'],
        related_chapter_id: data['notification']['related_chapter_id'],
        is_read: false,
        created_at: DateTime.parse(data['notification']['timestamp']),
      );

      // Ajouter la notification à la liste
      notificationProvider.addNotification(notification);

      // Afficher une snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['notification']['title']),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Voir',
              onPressed: () {
                Navigator.of(context).pushNamed('/notifications');
              },
            ),
          ),
        );
      }
    });

    // Écouter les notifications génériques
    wsProvider.on('notification:received', (data) {
      print('🔔 Notification générique reçue: $data');

      if (mounted) {
        // Recharger le compte de non-lues
        notificationProvider.loadUnreadCount();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
            // Icône notifications
            Consumer<NotificationProvider>(
              builder: (context, notificationProvider, _) {
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: Theme.of(context).iconTheme.color,
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed('/notifications');
                      },
                    ),
                    if (notificationProvider.unreadCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              notificationProvider.unreadCount > 99
                                  ? '99+'
                                  : notificationProvider.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
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
            // Load favorites when favorites tab is selected
            if (index == 2) {
              Provider.of<StoryProvider>(
                context,
                listen: false,
              ).loadFavorites();
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
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

        return SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._buildGenreSections(storyProvider),
              if (storyProvider.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!storyProvider.hasMoreStories &&
                  storyProvider.stories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'no_more_data'.tr(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Consumer<StoryProvider>(
      builder: (context, storyProvider, _) {
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de la page
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'my_favorites'.tr(),
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ) ??
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            // Grid des favoris
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.65,
                ),
                itemCount: storyProvider.favorites.length,
                itemBuilder: (context, index) {
                  final story = storyProvider.favorites[index];
                  return _buildStoryGridItem(story);
                },
              ),
            ),
          ],
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
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserProfileScreen(),
                    ),
                  );
                },
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
                      const SizedBox(height: 12),
                      if (authProvider.user != null)
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1DB954),
                                  width: 2,
                                ),
                                image: authProvider.user!['avatar'] != null &&
                                    authProvider.user!['avatar']!.isNotEmpty
                                    ? DecorationImage(
                                        image: MemoryImage(
                                          base64Decode(
                                            authProvider.user!['avatar'] ?? '',
                                          ),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: authProvider.user!['avatar'] == null ||
                                  authProvider.user!['avatar']!.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Color(0xFF1DB954),
                                      size: 28,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authProvider.user!['pseudo'] ??
                                        authProvider.user!['username'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    authProvider.user!['email'] ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Color(0xFF1DB954),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Logout Button
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isUserPremium = authProvider.isPremium;
    final isStoryPremium = story.isPremium;

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
                  if (mounted) {
                    Navigator.of(context).pushNamed('/subscription-offers');
                  }
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
      child: Stack(
        children: [
          Container(
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
          // Badge Premium
          if (isStoryPremium)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
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
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                    child: Icon(Icons.lock, color: Colors.amber, size: 32),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(Story story) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isUserPremium = authProvider.isPremium;
    final isStoryPremium = story.isPremium;

    return ListTile(
      leading: Stack(
        children: [
          story.coverImage != null
              ? SizedBox(
                  width: 50,
                  height: 70,
                  child: _buildImageFromString(story.coverImage!),
                )
              : const SizedBox(width: 50, child: Icon(Icons.image)),
          if (isStoryPremium)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Text('👑', style: TextStyle(fontSize: 12)),
              ),
            ),
          if (isStoryPremium && !isUserPremium)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: Icon(Icons.lock, color: Colors.amber, size: 20),
                ),
              ),
            ),
        ],
      ),
      title: Text(story.title),
      subtitle: Text(story.author),
      trailing: isStoryPremium && !isUserPremium
          ? const Icon(Icons.lock, color: Colors.amber)
          : null,
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
                  if (mounted) {
                    Navigator.of(context).pushNamed('/subscription-offers');
                  }
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
    );
  }

  Widget _buildStoryGridItem(Story story) {
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
                  if (mounted) {
                    Navigator.of(context).pushNamed('/subscription-offers');
                  }
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de couverture
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child:
                          story.coverImage != null &&
                              story.coverImage!.isNotEmpty
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
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
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
            // Infos de l'histoire
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Titre
                    Text(
                      story.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Auteur
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            story.author,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    // Récupérer le provider ET le navigator AVANT le dialog
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);

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

    if (confirmed == true) {
      print('🔴 _logout: Confirmation reçue, déconnexion...');
      await authProvider.logout();
      print('🔴 _logout: Déconnexion terminée, navigation vers login...');

      // Utiliser le navigator sauvegardé
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      print('✅ Navigation vers login effectuée');
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

            // My Reading Section
            _buildSectionTitle('my_reading'.tr()),
            _buildMyReadingSection(context),
            const SizedBox(height: 16),

            // Account Section
            _buildSectionTitle('account'.tr()),
            _buildAccountSection(context),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDisplaySection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

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
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildMyReadingSection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Column(
      children: [
        // My Stories
        _buildSettingsTile(
          icon: Icons.library_books,
          title: 'my_stories'.tr(),
          subtitle: 'view_read_stories'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyStoriesScreen()),
            );
          },
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Column(
      children: [
        // Profile Info
        if (authProvider.user != null)
          _buildSettingsTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.2),
                image:
                    authProvider.user!['avatar'] != null &&
                        authProvider.user!['avatar']!.isNotEmpty
                    ? DecorationImage(
                        image: MemoryImage(
                          base64Decode(authProvider.user!['avatar']),
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child:
                  authProvider.user!['avatar'] == null ||
                      authProvider.user!['avatar']!.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF1DB954))
                  : null,
            ),
            title: authProvider.user!['username'] ?? 'User',
            subtitle: authProvider.user!['email'] ?? 'No email',
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white : Colors.black,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserProfileScreen(),
                ),
              );
            },
          ),

        // Subscription Plans
        _buildSettingsTile(
          icon: Icons.workspace_premium,
          title: 'subscription_plans'.tr(),
          subtitle: 'manage_premium_subtitle'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SubscriptionOffersScreen(),
              ),
            );
          },
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),

        // Change Password
        _buildSettingsTile(
          icon: Icons.lock,
          title: 'change_password'.tr(),
          subtitle: 'update_password_subtitle'.tr(),
          onTap: () {
            // Navigate to change password screen
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ChangePasswordScreen(),
              ),
            );
          },
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white : Colors.black,
          ),
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

  Widget _buildAboutSection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CguScreen()),
            );
          },
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        // Contact Support
        _buildSettingsTile(
          icon: Icons.help,
          title: 'contact_support'.tr(),
          subtitle: 'get_help_support'.tr(),
          onTap: () {
            _openWhatsApp();
          },
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    IconData? icon,
    Widget? leading,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null)
                leading
              else
                Icon(
                  icon,
                  color: titleColor ?? (isDark ? Colors.white : Colors.black),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('confirm_logout'.tr()),
          content: Text('logout_confirmation_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                print('🔴 _confirmLogout: Déconnexion...');
                await authProvider.logout();
                print(
                  '🔴 _confirmLogout: Déconnexion terminée, navigation vers login...',
                );
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
                print('✅ Navigation vers login effectuée');
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

  Future<void> _openWhatsApp() async {
    final whatsappPhoneNumber = '+261345939753';
    final whatsappUrl =
        'https://wa.me/$whatsappPhoneNumber?text=Bonjour, je besoin d\'aide pour Appistery';

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp n\'est pas installé sur ce téléphone'),
            ),
          );
        }
      }
    } catch (e) {
      print('Erreur lors de l\'ouverture de WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }
}
