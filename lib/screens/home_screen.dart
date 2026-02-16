import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/notification_provider.dart';
import '../services/story_service.dart';
import '../services/category_intelligence_service.dart';
import 'login_screen.dart';
import 'story_detail_screen.dart';
import 'author_profile_screen.dart';
import 'genre_stories_screen.dart';
import 'my_stories_screen.dart';
import 'user_profile_screen.dart';
import 'cgu_screen.dart';
import 'subscription_offers_screen.dart';
import 'change_password_screen.dart';
import 'category_view_all_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CategoryIntelligenceService _aiService = CategoryIntelligenceService();

  // Map de traduction des genres
  final Map<String, Map<String, String>> _genreTranslations = {
    'Romance': {'fr': 'Romance', 'en': 'Romance'},
    'Romantic': {'fr': 'Romantique', 'en': 'Romantic'},
    'Horror': {'fr': 'Horreur', 'en': 'Horror'},
    'Horreur': {'fr': 'Horreur', 'en': 'Horror'},
    'Thriller': {'fr': 'Thriller', 'en': 'Thriller'},
    'Suspense': {'fr': 'Suspense', 'en': 'Suspense'},
    'Fantasy': {'fr': 'Fantaisie', 'en': 'Fantasy'},
    'Fantaisie': {'fr': 'Fantaisie', 'en': 'Fantasy'},
    'Science Fiction': {'fr': 'Science Fiction', 'en': 'Science Fiction'},
    'Sci-Fi': {'fr': 'Science Fiction', 'en': 'Sci-Fi'},
    'Drame': {'fr': 'Drame', 'en': 'Drama'},
    'Drama': {'fr': 'Drame', 'en': 'Drama'},
    'Comédie': {'fr': 'Comédie', 'en': 'Comedy'},
    'Comedy': {'fr': 'Comédie', 'en': 'Comedy'},
    'Aventure': {'fr': 'Aventure', 'en': 'Adventure'},
    'Adventure': {'fr': 'Aventure', 'en': 'Adventure'},
    'Action': {'fr': 'Action', 'en': 'Action'},
    'Mystère': {'fr': 'Mystère', 'en': 'Mystery'},
    'Mystery': {'fr': 'Mystère', 'en': 'Mystery'},
    'Historique': {'fr': 'Historique', 'en': 'Historical'},
    'Historical': {'fr': 'Historique', 'en': 'Historical'},
  };

  // Fonction helper pour traduire le genre
  String _translateGenre(String genre) {
    final lang = context.locale.languageCode;
    return _genreTranslations[genre]?[lang] ?? genre;
  }

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
                      // Naviguer vers la page profil utilisateur
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserProfileScreen(),
                        ),
                      );
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
              // Section Hero Netflix - Dernière histoire
              if (storyProvider.stories.isNotEmpty)
                _buildHeroSection(storyProvider.stories.first),
              const SizedBox(height: 24),
              // Section Nouveautés
              if (storyProvider.stories.isNotEmpty)
                _buildNewReleasesSection(storyProvider),
              const SizedBox(height: 12),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<StoryProvider>(
      builder: (context, storyProvider, _) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Search TextField - iOS style
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade900
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      storyProvider.searchStories(value);
                    },
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'search_stories'.tr(),
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: isDarkMode
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                storyProvider.searchStories('');
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // Si recherche vide, afficher les genres et auteurs
              if (_searchController.text.isEmpty) ...[
                const SizedBox(height: 8),
                // Section Auteurs
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Featured creators',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDarkMode ? Colors.white : Colors.black,
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
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Browse all',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),

                // Genres Grid (Apple style)
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
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.0,
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
                    padding: EdgeInsets.symmetric(vertical: 60.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (storyProvider.searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 80,
                            color: isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'no_results'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'try_other_keywords'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      '${storyProvider.searchResults.length} ${storyProvider.searchResults.length > 1 ? 'results'.tr() : 'result'.tr()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: storyProvider.searchResults.length,
                      itemBuilder: (context, index) {
                        final story = storyProvider.searchResults[index];
                        return _buildStoryGridItem(story);
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  // Genre Card (Apple style - elegant and uniform)
  Widget _buildGenreCard(Map<String, dynamic> genre, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Pattern background très subtil
              Positioned.fill(
                child: CustomPaint(
                  painter: _GenrePatternPainter(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                  ),
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône en haut à droite
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 20,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ),
                    // Titre en bas
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          genre['title'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Explorer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Author Card - Compact design
  Widget _buildAuthorCard(Author author) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
      child: Container(
        width: 90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  width: 2,
                ),
              ),
              child: author.avatar != null && author.avatar!.isNotEmpty
                  ? ClipOval(child: _buildAvatarImage(author.avatar!))
                  : Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade500,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              author.pseudo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<StoryProvider>(
      builder: (context, storyProvider, _) {
        if (storyProvider.isLoading && storyProvider.favorites.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (storyProvider.favorites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 80,
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'no_favorites'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vos histoires préférées apparaîtront ici',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _selectedIndex = 1); // Index 1 = Search tab
                    },
                    icon: const Icon(Icons.explore_rounded),
                    label: Text('discover'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de la page - Apple style
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                'my_favorites'.tr(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            // Grid des favoris - Apple Grid System
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.68,
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
                            _buildUserAvatarLarge(
                              authProvider.user!['avatar'],
                              isDarkMode: isDarkMode,
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
  // Section Hero Netflix Style
  Widget _buildHeroSection(Story story) {
    final isStoryPremium = story.isPremium;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        // Permettre l'accès au synopsis pour toutes les histoires
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(story: story),
          ),
        );
      },
      child: Container(
        height: 500,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black : Colors.grey.shade900,
        ),
        child: Stack(
          children: [
            // Image de fond avec gradient
            if (story.coverImage != null && story.coverImage!.isNotEmpty)
              Positioned.fill(
                child: Stack(
                  children: [
                    _buildHeroImageFromString(story.coverImage!),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0.95),
                          ],
                          stops: const [0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Badge "Nouveauté" style Netflix (si l'histoire a moins de 7 jours)
            if (story.createdAt != null && 
                DateTime.now().difference(story.createdAt!).inDays < 7)
              Positioned(
                top: 20,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914), // Rouge Netflix
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.locale.languageCode == 'fr' 
                            ? 'NOUVEAUTÉ' 
                            : 'NEW',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Contenu en bas
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge Premium
                    if (isStoryPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Titre
                    Text(
                      story.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Genre et auteur
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _translateGenre(story.genre),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.person_outline,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            story.author,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description
                    Text(
                      story.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),

                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Permettre l'accès au synopsis
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      StoryDetailScreen(story: story),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow, size: 28),
                            label: Text(
                              context.locale.languageCode == 'fr'
                                  ? 'Lire maintenant'
                                  : 'Read now',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      StoryDetailScreen(story: story),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 28,
                            ),
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

  // Section Nouveautés - 5 dernières histoires
  Widget _buildNewReleasesSection(StoryProvider storyProvider) {
    // Filtrer les histoires avec une date de création et trier par date décroissante
    final recentStories = storyProvider.stories
        .where((story) => story.createdAt != null)
        .toList()
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    
    // Prendre les 5 plus récentes
    final newReleases = recentStories.take(5).toList();
    
    if (newReleases.isEmpty) {
      return const SizedBox.shrink();
    }

    // Générer un titre intelligent multilingue
    final title = context.locale.languageCode == 'fr'
        ? 'Nouveautés de la semaine'
        : 'New this week';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title avec badge NEW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914), // Rouge Netflix
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.fiber_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Grille horizontale scrollable - mêmes dimensions que les cards des sections genres
          Builder(
            builder: (context) {
              // Calculer la taille identique aux cards du GridView (crossAxisCount: 3, ratio: 0.68)
              final screenWidth = MediaQuery.of(context).size.width;
              final cardWidth = (screenWidth - 32 - 20) / 3; // padding 16*2 + spacing 10*2
              final cardHeight = cardWidth / 0.68;
              return SizedBox(
                height: cardHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: newReleases.length,
                  itemBuilder: (context, index) {
                    final story = newReleases[index];
                    return Container(
                      width: cardWidth,
                      margin: EdgeInsets.only(
                        right: index < newReleases.length - 1 ? 10 : 0,
                      ),
                      child: _buildStoryGridItem(story),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGenreSections(StoryProvider storyProvider) {
    final storiesByGenre = storyProvider.getStoriesByGenre();
    final sections = <Widget>[];

    // Afficher tous les genres avec Apple Grid System
    storiesByGenre.forEach((genre, stories) {
      if (stories.isNotEmpty) {
        // Générer un titre intelligent avec notre IA maison
        final intelligentTitle = _aiService.generateCategoryTitle(
          genre,
          language: context.locale.languageCode,
          currentTime: DateTime.now(),
        );
        
        sections.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Genre Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      intelligentTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryViewAllScreen(
                              genreName: genre,
                              intelligentTitle: intelligentTitle,
                              stories: stories,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        context.locale.languageCode == 'fr'
                            ? 'Voir tout'
                            : 'View all',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Apple Grid System: Grille de 3 colonnes
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: stories.length > 6 ? 6 : stories.length,
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    return _buildStoryGridItem(story);
                  },
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
    final isStoryPremium = story.isPremium;

    return GestureDetector(
      onTap: () {
        // Permettre l'accès au synopsis pour toutes les histoires
        // Le blocage des chapitres se fera dans StoryDetailScreen
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
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(Story story) {
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
        ],
      ),
      title: Text(story.title),
      subtitle: Text(story.author),
      onTap: () {
        // Permettre l'accès au synopsis pour toutes les histoires
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
    final isStoryPremium = story.isPremium;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        // Permettre l'accès au synopsis
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
          ],
        ),
      ),
    );
  }

  // Helper method for hero images (full width)
  Widget _buildHeroImageFromString(String imageData) {
    try {
      // Vérifier si c'est une URL relative (commence par /uploads/)
      if (imageData.startsWith('/uploads/')) {
        final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
        final imageUrl = '$apiUrl$imageData';
        
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade800,
              child: const Icon(Icons.broken_image, color: Colors.grey, size: 60),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            );
          },
        );
      }
      
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
              child: const Icon(Icons.broken_image, color: Colors.grey, size: 60),
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
              child: const Icon(Icons.broken_image, color: Colors.grey, size: 60),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      return Container(
        color: Colors.grey.shade800,
        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 60),
      );
    }
  }

  // Helper method to detect and build image from base64 or URL
  Widget _buildImageFromString(String imageData) {
    try {
      // Vérifier si c'est une URL relative (commence par /uploads/)
      if (imageData.startsWith('/uploads/')) {
        final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
        final imageUrl = '$apiUrl$imageData';
        
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: 140,
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
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
  }

  // Helper method for avatar images (smaller, circular)
  Widget _buildAvatarImage(String imageData) {
    try {
      // Vérifier si c'est une URL relative (commence par /uploads/)
      if (imageData.startsWith('/uploads/')) {
        final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
        final imageUrl = '$apiUrl$imageData';
        
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: 32,
          height: 32,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 24,
            );
          },
        );
      }
      
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
            return const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 24,
            );
          },
        );
      } else {
        // It's a full URL
        return Image.network(
          imageData,
          fit: BoxFit.cover,
          width: 32,
          height: 32,
          errorBuilder: (context, error, stackTrace) {
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
      return const Icon(Icons.account_circle, color: Colors.white, size: 24);
    }
  }

  // Helper pour construire l'avatar utilisateur (supporte URL et base64)
  Widget _buildUserAvatar(String? avatarData, {required bool isDarkMode}) {
    if (avatarData == null || avatarData.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.2),
        ),
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF1DB954),
          size: 24,
        ),
      );
    }

    // Vérifier si c'est une URL relative (commence par /uploads/)
    if (avatarData.startsWith('/uploads/')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
      final imageUrl = '$apiUrl$avatarData';
      
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.2),
        ),
        child: ClipOval(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.person_rounded,
                color: Color(0xFF1DB954),
                size: 24,
              );
            },
          ),
        ),
      );
    }

    // Sinon c'est du base64 ou une URL complète
    try {
      if (avatarData.startsWith('http://') || avatarData.startsWith('https://')) {
        // URL complète
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withOpacity(0.2),
          ),
          child: ClipOval(
            child: Image.network(
              avatarData,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF1DB954),
                  size: 24,
                );
              },
            ),
          ),
        );
      } else {
        // Base64
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withOpacity(0.2),
            image: DecorationImage(
              image: MemoryImage(
                base64Decode(avatarData),
              ),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    } catch (e) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.2),
        ),
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF1DB954),
          size: 24,
        ),
      );
    }
  }

  // Helper pour construire un avatar utilisateur plus grand (56x56)
  Widget _buildUserAvatarLarge(String? avatarData, {required bool isDarkMode}) {
    if (avatarData == null || avatarData.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF1DB954),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.person,
          color: Color(0xFF1DB954),
          size: 28,
        ),
      );
    }

    // Vérifier si c'est une URL relative (commence par /uploads/)
    if (avatarData.startsWith('/uploads/')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
      final imageUrl = '$apiUrl$avatarData';
      
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF1DB954),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.person,
                color: Color(0xFF1DB954),
                size: 28,
              );
            },
          ),
        ),
      );
    }

    // Sinon c'est du base64 ou une URL complète
    try {
      if (avatarData.startsWith('http://') || avatarData.startsWith('https://')) {
        // URL complète
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF1DB954),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: Image.network(
              avatarData,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person,
                  color: Color(0xFF1DB954),
                  size: 28,
                );
              },
            ),
          ),
        );
      } else {
        // Base64
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF1DB954),
              width: 2,
            ),
            image: DecorationImage(
              image: MemoryImage(
                base64Decode(avatarData),
              ),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    } catch (e) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF1DB954),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.person,
          color: Color(0xFF1DB954),
          size: 28,
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Récupérer le provider ET le navigator AVANT le dialog
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
              
              // Icône
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Titre
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'confirm_logout'.tr(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'logout_warning'.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode 
                      ? Colors.grey.shade400 
                      : Colors.grey.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Divider
              Divider(
                height: 1,
                thickness: 0.5,
                color: isDarkMode 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade300,
              ),
              
              // Boutons
              Column(
                children: [
                  // Bouton Déconnexion
                  InkWell(
                    onTap: () => Navigator.pop(context, true),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'logout'.tr(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDarkMode 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade300,
                  ),
                  
                  // Bouton Annuler
                  InkWell(
                    onTap: () => Navigator.pop(context, false),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'cancel'.tr(),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await authProvider.logout();

      // Utiliser le navigator sauvegardé
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildSettingsTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grand titre Apple style
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(
              'Paramètres',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Display Section
          _buildSectionTitle('display'.tr()),
          _buildDisplaySection(context),
          const SizedBox(height: 24),

          // My Reading Section
          _buildSectionTitle('my_reading'.tr()),
          _buildMyReadingSection(context),
          const SizedBox(height: 24),

          // Account Section
          _buildSectionTitle('account'.tr()),
          _buildAccountSection(context),
          const SizedBox(height: 24),

          // About Section
          _buildSectionTitle('about'.tr()),
          _buildAboutSection(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDarkMode
              ? Colors.grey.shade500
              : Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDisplaySection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark 
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Theme Toggle
            _buildSettingsTile(
              icon: Icons.brightness_6_rounded,
              title: 'theme'.tr(),
              subtitle: themeProvider.themeMode == ThemeMode.dark
                  ? 'dark_mode'.tr()
                  : 'light_mode'.tr(),
              trailing: Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (bool value) {
                    themeProvider.setTheme(value ? ThemeMode.dark : ThemeMode.light);
                  },
                  activeColor: const Color(0xFF1DB954),
                  activeTrackColor: const Color(0xFF1DB954).withOpacity(0.5),
                ),
              ),
              isFirst: true,
            ),

            // Language Selection
            _buildSettingsTile(
              icon: Icons.language_rounded,
              title: 'language'.tr(),
              subtitle: _getLanguageLabel(context.locale),
              onTap: () => _showLanguageDialog(context),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 20,
              ),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyReadingSection(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildSettingsTile(
          icon: Icons.library_books_rounded,
          title: 'my_stories'.tr(),
          subtitle: 'view_read_stories'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyStoriesScreen()),
            );
          },
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            size: 20,
          ),
          isFirst: true,
          isLast: true,
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Profile Info
            if (authProvider.user != null)
              _buildSettingsTile(
                leading: _buildUserAvatar(
                  authProvider.user!['avatar'],
                  isDarkMode: isDarkMode,
                ),
                title: authProvider.user!['username'] ?? 'User',
                subtitle: authProvider.user!['email'] ?? 'No email',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  size: 20,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserProfileScreen(),
                    ),
                  );
                },
                isFirst: true,
              ),

            // Subscription Plans
            _buildSettingsTile(
              icon: Icons.workspace_premium_rounded,
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
                Icons.chevron_right_rounded,
                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 20,
              ),
            ),

            // Change Password
            _buildSettingsTile(
              icon: Icons.lock_rounded,
              title: 'change_password'.tr(),
              subtitle: 'update_password_subtitle'.tr(),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 20,
              ),
            ),

            // Logout
            _buildSettingsTile(
              icon: Icons.logout_rounded,
              title: 'logout'.tr(),
              subtitle: 'logout_subtitle'.tr(),
              onTap: () => _confirmLogout(context),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: Colors.red.withOpacity(0.5),
                size: 20,
              ),
              titleColor: Colors.red,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Version
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'version'.tr(),
              subtitle: 'v1.0.0',
              onTap: _showAboutBottomSheet,
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 20,
              ),
              isFirst: true,
            ),

            // Terms of Service
            _buildSettingsTile(
              icon: Icons.assignment_outlined,
              title: 'terms_of_service'.tr(),
              subtitle: 'read_our_terms'.tr(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CguScreen()),
                );
              },
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 20,
              ),
            ),
            
            // Contact Support
            _buildSettingsTile(
              icon: Icons.help_outline_rounded,
              title: 'contact_support'.tr(),
              subtitle: 'get_help_support'.tr(),
              onTap: () {
                _openWhatsApp();
              },
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 20,
              ),
              isLast: true,
            ),
          ],
        ),
      ),
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
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(12) : Radius.zero,
          bottom: isLast ? const Radius.circular(12) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: !isLast
                ? Border(
                    bottom: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              if (leading != null)
                leading
              else if (icon != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: titleColor?.withOpacity(0.1) ??
                        (isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: titleColor ??
                        (isDarkMode ? Colors.white : Colors.black87),
                    size: 20,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentLocale = context.locale;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                
                // Icône
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF1DB954),
                    size: 32,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Titre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'select_language'.tr(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Choisissez votre langue préférée',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode 
                        ? Colors.grey.shade400 
                        : Colors.grey.shade600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Divider
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDarkMode 
                    ? Colors.grey.shade800 
                    : Colors.grey.shade300,
                ),
                
                // Options de langue
                Column(
                  children: [
                    // Français
                    InkWell(
                      onTap: () {
                        context.setLocale(const Locale('fr'));
                        Navigator.pop(dialogContext);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        child: Row(
                          children: [
                            const Text(
                              '🇫🇷',
                              style: TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Français',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: currentLocale.languageCode == 'fr'
                                    ? const Color(0xFF1DB954)
                                    : (isDarkMode ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                            if (currentLocale.languageCode == 'fr')
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF1DB954),
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDarkMode 
                        ? Colors.grey.shade800 
                        : Colors.grey.shade300,
                    ),
                    
                    // English
                    InkWell(
                      onTap: () {
                        context.setLocale(const Locale('en'));
                        Navigator.pop(dialogContext);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        child: Row(
                          children: [
                            const Text(
                              '🇬🇧',
                              style: TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'English',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: currentLocale.languageCode == 'en'
                                    ? const Color(0xFF1DB954)
                                    : (isDarkMode ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                            if (currentLocale.languageCode == 'en')
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF1DB954),
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDarkMode 
                        ? Colors.grey.shade800 
                        : Colors.grey.shade300,
                    ),
                    
                    // Bouton Annuler
                    InkWell(
                      onTap: () => Navigator.pop(dialogContext),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'cancel'.tr(),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                
                // Icône
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Titre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'confirm_logout'.tr(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'logout_warning'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode 
                        ? Colors.grey.shade400 
                        : Colors.grey.shade600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Divider
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDarkMode 
                    ? Colors.grey.shade800 
                    : Colors.grey.shade300,
                ),
                
                // Boutons
                Column(
                  children: [
                    // Bouton Déconnexion
                    InkWell(
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await authProvider.logout();
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'logout'.tr(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDarkMode 
                        ? Colors.grey.shade800 
                        : Colors.grey.shade300,
                    ),
                    
                    // Bouton Annuler
                    InkWell(
                      onTap: () => Navigator.pop(dialogContext),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'cancel'.tr(),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  // Afficher le bottom sheet "À propos de l'application"
  void _showAboutBottomSheet() {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo de l'application
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/logo/logo-appistery-no.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 24),

                // Nom de l'application
                Text(
                  'Appistery',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  'app_description'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 24),

                // Version
                Text(
                  'Version 1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),

                const SizedBox(height: 32),

                // Bouton fermer
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'close'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom painter pour le pattern de fond des cartes de genres
class _GenrePatternPainter extends CustomPainter {
  final Color color;

  _GenrePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Dessiner des cercles décoratifs
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      30,
      paint,
    );
    
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.7),
      20,
      paint,
    );
    
    // Dessiner quelques lignes décoratives
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawLine(
      Offset(size.width * 0.6, size.height * 0.8),
      Offset(size.width * 0.9, size.height * 0.9),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
