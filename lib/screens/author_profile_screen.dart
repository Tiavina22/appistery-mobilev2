import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';
import '../services/author_service.dart';
import '../services/story_service.dart';
import 'story_detail_screen.dart';

class AuthorProfileScreen extends StatefulWidget {
  final int authorId;
  final String authorName;

  const AuthorProfileScreen({
    super.key,
    required this.authorId,
    required this.authorName,
  });

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthorService _authorService = AuthorService();
  late TabController _tabController;

  bool _isFollowing = false;
  int _followersCount = 0;
  Map<String, dynamic>? _authorProfile;
  List<Story> _authorStories = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAuthorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthorData() async {

    try {
      // Charger en parallèle
      final results = await Future.wait([
        _authorService.getAuthorProfile(widget.authorId),
        _authorService.isFollowing(widget.authorId),
        _authorService.getFollowersCount(widget.authorId),
        _authorService.getAuthorStories(widget.authorId),
        _authorService.getAuthorStats(widget.authorId),
      ]);

      final authorProfile = results[0] as Map<String, dynamic>;
      setState(() {
        _authorProfile = authorProfile;
        _isFollowing = results[1] as bool;
        _followersCount = results[2] as int;
        _authorStories = (results[3] as List).map((json) {
          final storyJson = Map<String, dynamic>.from(json as Map);
          // Inject author data so story_detail_screen can show name & avatar
          if (storyJson['author'] == null || storyJson['author'] is! Map) {
            storyJson['author'] = {
              'id': authorProfile['id'] ?? widget.authorId,
              'pseudo': authorProfile['pseudo'] ?? widget.authorName,
              'avatar': authorProfile['avatar'],
              'biography': authorProfile['biography'],
              'followers_count': _followersCount,
            };
          }
          return Story.fromJson(storyJson);
        }).toList();
        _stats = results[4] as Map<String, dynamic>;
      });
    } catch (e) {
    }
  }

  Future<void> _toggleFollow() async {
    try {
      if (_isFollowing) {
        await _authorService.unfollowAuthor(widget.authorId);
        setState(() {
          _isFollowing = false;
          _followersCount--;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Désabonné avec succès')),
          );
        }
      } else {
        await _authorService.followAuthor(widget.authorId);
        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Abonné avec succès')));
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textColorSecondary = isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 0,
                    pinned: true,
                    backgroundColor: backgroundColor,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    forceElevated: false,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Informations du profil avec avatar à gauche
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar à gauche
                              _buildAvatar(isDarkMode: isDarkMode),
                              const SizedBox(width: 16),
                              // Infos à droite
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Nom de l'auteur
                                    Text(
                                      widget.authorName,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Spécialité
                                    if (_authorProfile?['speciality'] != null)
                                      Text(
                                        _authorProfile!['speciality'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: textColorSecondary,
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    // Stats en colonne
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStatItemCompact(
                                          'Histoires',
                                          _stats['total_stories']?.toString() ?? '0',
                                          isDarkMode: isDarkMode,
                                        ),
                                        _buildStatItemCompact(
                                          'Followers',
                                          _followersCount.toString(),
                                          isDarkMode: isDarkMode,
                                          onTap: () => _showUsersBottomSheet(
                                            title: 'Followers',
                                            icon: Icons.people,
                                            loader: () => _authorService.getFollowersList(widget.authorId),
                                          ),
                                        ),
                                        _buildStatItemCompact(
                                          'Vues',
                                          _stats['total_views']?.toString() ?? '0',
                                          isDarkMode: isDarkMode,
                                          onTap: () => _showUsersBottomSheet(
                                            title: 'Lecteurs uniques',
                                            icon: Icons.remove_red_eye,
                                            subtitle: '${_stats['total_views'] ?? 0} vues au total (1 vue par histoire lue)',
                                            loader: () => _authorService.getViewersList(widget.authorId),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Bouton Suivre/Abonné
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _toggleFollow,
                              icon: Icon(
                                _isFollowing ? Icons.check : Icons.add,
                              ),
                              label: Text(
                                _isFollowing ? 'Abonné' : 'Suivre',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing
                                    ? (isDarkMode
                                          ? Colors.grey[800]
                                          : Colors.grey[300])
                                    : (isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                foregroundColor: _isFollowing
                                    ? textColor
                                    : (isDarkMode
                                          ? Colors.black
                                          : Colors.white),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Biographie
                          if (_authorProfile?['biography'] != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Biographie',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _authorProfile!['biography'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColorSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),

                          // Tabs
                          TabBar(
                            controller: _tabController,
                            indicatorColor: textColor,
                            labelColor: textColor,
                            unselectedLabelColor: textColorSecondary,
                            tabs: const [
                              Tab(text: 'Histoires'),
                              Tab(text: 'À propos'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildStoriesTab(isDarkMode: isDarkMode),
                  _buildAboutTab(isDarkMode: isDarkMode),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar({required bool isDarkMode}) {
    final avatarData = _authorProfile?['avatar'] as String?;
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    final borderColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        border: Border.all(color: borderColor, width: 3),
      ),
      child: ClipOval(
        child: avatarData != null && avatarData.isNotEmpty
            ? _buildAvatarImage(avatarData, iconColor)
            : Icon(Icons.person, size: 60, color: iconColor),
      ),
    );
  }

  Widget _buildAvatarImage(String avatarData, Color iconColor) {
    // Vérifier si c'est une URL (commence par /uploads/ ou http)
    if (avatarData.startsWith('/uploads/') ||
        avatarData.startsWith('http://') ||
        avatarData.startsWith('https://')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
      final imageUrl = avatarData.startsWith('http')
          ? avatarData
          : '$apiUrl$avatarData';

      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: 60, color: iconColor);
        },
      );
    }

    // Sinon, c'est du base64 (backward compatibility)
    try {
      final base64String = avatarData.contains(',')
          ? avatarData.split(',').last
          : avatarData;

      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: 60, color: iconColor);
        },
      );
    } catch (e) {
      return Icon(Icons.person, size: 60, color: iconColor);
    }
  }


  void _showUsersBottomSheet({
    required String title,
    required IconData icon,
    required Future<List<Map<String, dynamic>>> Function() loader,
    String? subtitle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UsersListBottomSheet(
        title: title,
        icon: icon,
        loader: loader,
        subtitle: subtitle,
      ),
    );
  }

  Widget _buildStatItemCompact(
    String label,
    String value, {
    required bool isDarkMode,
    VoidCallback? onTap,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textColorSecondary = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    final child = Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: textColorSecondary)),
            if (onTap != null) ...[  
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 14, color: textColorSecondary),
            ],
          ],
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
  }

  Widget _buildStoriesTab({required bool isDarkMode}) {
    final textColorSecondary = isDarkMode ? Colors.white70 : Colors.black54;
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200;

    if (_authorStories.isEmpty) {
      return Center(
        child: Text(
          'Aucune histoire publiée',
          style: TextStyle(color: textColorSecondary),
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
      itemCount: _authorStories.length,
      itemBuilder: (context, index) {
        final story = _authorStories[index];
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
              color: cardColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: story.coverImage != null && story.coverImage!.isNotEmpty
                  ? _buildCoverImage(story.coverImage!)
                  : const Center(
                      child: Icon(Icons.book, color: Colors.grey, size: 60),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutTab({required bool isDarkMode}) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textColorSecondary = isDarkMode ? Colors.grey[300] : Colors.grey[700];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Membre depuis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _authorProfile?['created_at'] != null
                ? DateFormat(
                    'dd MMMM yyyy',
                  ).format(DateTime.parse(_authorProfile!['created_at']))
                : 'Non disponible',
            style: TextStyle(fontSize: 14, color: textColorSecondary),
          ),
        ],
      ),
    );
  }

  // Helper method to build cover image (supports both URL and base64)
  Widget _buildCoverImage(String coverImage) {
    // Vérifier si c'est une URL relative (commence par /uploads/)
    if (coverImage.startsWith('/uploads/')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
      final imageUrl = '$apiUrl$coverImage';
      
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey,
              size: 60,
            ),
          );
        },
      );
    }
    
    // Vérifier si c'est une URL complète
    if (coverImage.startsWith('http://') || coverImage.startsWith('https://')) {
      return Image.network(
        coverImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey,
              size: 60,
            ),
          );
        },
      );
    }
    
    // Sinon, c'est du base64 (backward compatibility)
    try {
      final base64String = coverImage.contains(',')
          ? coverImage.split(',').last
          : coverImage;
      
      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey,
              size: 60,
            ),
          );
        },
      );
    } catch (e) {
      return const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 60,
        ),
      );
    }
  }
}

// ── Bottom sheet: list of users (followers or viewers) ──────────────────────

class _UsersListBottomSheet extends StatefulWidget {
  final String title;
  final IconData icon;
  final Future<List<Map<String, dynamic>>> Function() loader;
  final String? subtitle;

  const _UsersListBottomSheet({
    required this.title,
    required this.icon,
    required this.loader,
    this.subtitle,
  });

  @override
  State<_UsersListBottomSheet> createState() => _UsersListBottomSheetState();
}

class _UsersListBottomSheetState extends State<_UsersListBottomSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await widget.loader();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  Widget _buildSkeletonList(bool isDark) {
    final baseColor = isDark ? Colors.white10 : Colors.black12;
    final highlightColor = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.06);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: 8,
      separatorBuilder: (_, __) => Divider(
        color: isDark ? Colors.white12 : Colors.black12,
        height: 1,
      ),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 130,
                    height: 13,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String? avatarData) {
    final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
    if (avatarData == null || avatarData.isEmpty) {
      return const Icon(Icons.person, color: Colors.grey, size: 24);
    }
    if (avatarData.startsWith('/uploads/') ||
        avatarData.startsWith('http://') ||
        avatarData.startsWith('https://')) {
      final url = avatarData.startsWith('http') ? avatarData : '$apiUrl$avatarData';
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.person, color: Colors.grey, size: 24),
      );
    }
    try {
      final b64 = avatarData.contains(',') ? avatarData.split(',').last : avatarData;
      return Image.memory(
        base64Decode(b64),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.person, color: Colors.grey, size: 24),
      );
    } catch (_) {
      return const Icon(Icons.person, color: Colors.grey, size: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSec = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, color: textColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (!_isLoading) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_users.length}',
                          style: TextStyle(fontSize: 13, color: textColorSec),
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(fontSize: 12, color: textColorSec),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: dividerColor, height: 20),
          // List
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(isDark)
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun résultat',
                          style: TextStyle(color: textColorSec),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        separatorBuilder: (_, __) =>
                            Divider(color: dividerColor, height: 1),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                              ),
                              child: ClipOval(
                                child: _buildUserAvatar(
                                    user['avatar'] as String?),
                              ),
                            ),
                            title: Text(
                              user['pseudo'] as String? ??
                                  user['username'] as String? ??
                                  'Utilisateur',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
