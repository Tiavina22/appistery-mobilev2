import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
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
      print('Erreur lors du chargement du profil: $e');
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // AppBar avec avatar
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: Colors.grey[900],
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
                                colors: [Colors.grey[800]!, Colors.black],
                              ),
                            ),
                          ),
                          // Avatar centré
                          Center(child: _buildAvatar()),
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
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                                color: Colors.grey[400],
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
                              ),
                              _buildStatItem(
                                'Followers',
                                _followersCount.toString(),
                              ),
                              _buildStatItem(
                                'Vues',
                                _stats['total_views']?.toString() ?? '0',
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
                                    ? Colors.grey[800]
                                    : Colors.white,
                                foregroundColor: _isFollowing
                                    ? Colors.white
                                    : Colors.black,
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
                                  const Text(
                                    'Biographie',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _authorProfile!['biography'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[300],
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
                            indicatorColor: Colors.white,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey,
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
                children: [_buildStoriesTab(), _buildAboutTab()],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final avatarData = _authorProfile?['avatar'] as String?;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(
        child: avatarData != null && avatarData.isNotEmpty
            ? Image.memory(
                base64Decode(avatarData.split(',').last),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.white70,
                  );
                },
              )
            : const Icon(Icons.person, size: 60, color: Colors.white70),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildStoriesTab() {
    if (_authorStories.isEmpty) {
      return const Center(
        child: Text(
          'Aucune histoire publiée',
          style: TextStyle(color: Colors.white70),
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
              color: Colors.grey.shade900,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: story.coverImage != null && story.coverImage!.isNotEmpty
                  ? Image.memory(
                      base64Decode(story.coverImage!.split(',').last),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.book, color: Colors.grey, size: 60),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(Icons.book, color: Colors.grey, size: 60),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Email',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _authorProfile?['email'] ?? 'Non disponible',
            style: TextStyle(fontSize: 14, color: Colors.grey[300]),
          ),
          const SizedBox(height: 20),
          const Text(
            'Membre depuis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _authorProfile?['created_at'] != null
                ? DateFormat(
                    'dd MMMM yyyy',
                  ).format(DateTime.parse(_authorProfile!['created_at']))
                : 'Non disponible',
            style: TextStyle(fontSize: 14, color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }
}
