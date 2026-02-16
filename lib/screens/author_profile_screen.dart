import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  bool _isLoading = true;
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
    setState(() => _isLoading = true);

    try {
      // Charger en parallèle
      final results = await Future.wait([
        _authorService.getAuthorProfile(widget.authorId),
        _authorService.isFollowing(widget.authorId),
        _authorService.getFollowersCount(widget.authorId),
        _authorService.getAuthorStories(widget.authorId),
        _authorService.getAuthorStats(widget.authorId),
      ]);

      setState(() {
        _authorProfile = results[0] as Map<String, dynamic>;
        _isFollowing = results[1] as bool;
        _followersCount = results[2] as int;
        _authorStories = (results[3] as List)
            .map((json) => Story.fromJson(json))
            .toList();
        _stats = results[4] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.grey[200];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // AppBar avec avatar
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: cardColor,
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
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Fond dégradé
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDarkMode
                                    ? [Colors.grey[800]!, Colors.black]
                                    : [Colors.grey[400]!, Colors.grey[200]!],
                              ),
                            ),
                          ),
                          // Avatar centré
                          Center(child: _buildAvatar(isDarkMode: isDarkMode)),
                        ],
                      ),
                    ),
                  ),

                  // Informations du profil
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Nom de l'auteur
                          Text(
                            widget.authorName,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Spécialité
                          if (_authorProfile?['speciality'] != null)
                            Text(
                              _authorProfile!['speciality'],
                              style: TextStyle(
                                fontSize: 16,
                                color: textColorSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 20),

                          // Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                'Histoires',
                                _stats['total_stories']?.toString() ?? '0',
                                isDarkMode: isDarkMode,
                              ),
                              _buildStatItem(
                                'Followers',
                                _followersCount.toString(),
                                isDarkMode: isDarkMode,
                              ),
                              _buildStatItem(
                                'Vues',
                                _stats['total_views']?.toString() ?? '0',
                                isDarkMode: isDarkMode,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

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

  Widget _buildStatItem(
    String label,
    String value, {
    required bool isDarkMode,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textColorSecondary = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: textColorSecondary)),
      ],
    );
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
            'Email',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _authorProfile?['email'] ?? 'Non disponible',
            style: TextStyle(fontSize: 14, color: textColorSecondary),
          ),
          const SizedBox(height: 20),
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
