import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/story_service.dart';
import '../services/reading_service.dart';
import '../services/author_service.dart';
import '../providers/story_provider.dart';
import '../widgets/facebook_notification.dart';
import 'author_profile_screen.dart';
import 'reader_screen.dart';

class StoryDetailScreen extends StatefulWidget {
  final Story story;

  const StoryDetailScreen({super.key, required this.story});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen>
    with WidgetsBindingObserver {
  bool _isExpanded = false;
  bool _isLoadingStory = false;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  late AuthorService _authorService;

  // Nouveaux états pour le suivi de lecture
  bool _isCompleted = false;
  Map<String, dynamic>? _completionInfo;
  Map<String, dynamic>? _readingStats;
  bool _isLoadingStats = false;

  // États pour le statut de lecture
  Map<String, dynamic>? _lastReadingPosition;
  bool _hasStartedReading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authorService = AuthorService();
    _loadFollowingStatus();
    _loadReadingStats();
    _loadLastReadingPosition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadLastReadingPosition() async {
    try {
      print(
        '📍 [StoryDetailScreen._loadLastReadingPosition] Chargement dernière position...',
      );
      final readingService = ReadingService();
      final lastPosition = await readingService.getLastPosition(
        widget.story.id,
      );

      if (mounted) {
        setState(() {
          _lastReadingPosition = lastPosition;
          _hasStartedReading = lastPosition != null;
        });
        if (lastPosition != null) {
          print(
            '   ✅ Dernière position trouvée: chapitre ${lastPosition['chapter_id']}',
          );
        } else {
          print('   ℹ️ Aucune lecture antérieure');
        }
      }
    } catch (e) {
      print('   ❌ Erreur: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Rafraîchir les stats quand on revient à cette page
      _loadReadingStats();
    }
  }

  Future<void> _loadReadingStats() async {
    setState(() => _isLoadingStats = true);
    try {
      print(
        '📊 [StoryDetailScreen._loadReadingStats] story=${widget.story.id}',
      );
      final readingService = ReadingService();

      // Charger les stats publiques
      final stats = await readingService.getReadingStats(widget.story.id);

      // Charger la completion info
      final completionInfo = await readingService.getCompletionInfo(
        widget.story.id,
      );

      if (mounted) {
        setState(() {
          _readingStats = stats;
          _completionInfo = completionInfo;
          _isCompleted =
              completionInfo != null && completionInfo['is_completed'] == true;
        });
      }
    } catch (e) {
      print('❌ Erreur _loadReadingStats: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _loadFollowingStatus() async {
    try {
      final isFollowing = await _authorService.isFollowing(1);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    } catch (e) {
      // Silencieusement échouer
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isLoadingFollow = true);
    try {
      final wasFollowing = _isFollowing;
      if (_isFollowing) {
        await _authorService.unfollowAuthor(1);
      } else {
        await _authorService.followAuthor(1);
      }
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });

        // Afficher une belle notification style Facebook
        if (_isFollowing) {
          NotificationOverlay.show(
            context,
            message: 'Vous suivez maintenant ${widget.story.author}',
            icon: Icons.check_circle_outline,
            backgroundColor: Colors.green[600]!,
            duration: const Duration(seconds: 3),
          );
        } else {
          NotificationOverlay.show(
            context,
            message: 'Vous avez arrêté de suivre ${widget.story.author}',
            icon: Icons.remove_circle_outline,
            backgroundColor: Colors.orange[600]!,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationOverlay.show(
          context,
          message: 'Erreur: ${e.toString()}',
          icon: Icons.error_outline,
          backgroundColor: Colors.red[600]!,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollow = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Image de couverture avec gradient overlay
          SliverAppBar(
            expandedHeight: size.height * 0.4,
            pinned: true,
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.white),
                ),
                onPressed: () {
                  // TODO: Partager l'histoire
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image de couverture
                  widget.story.coverImage != null &&
                          widget.story.coverImage!.isNotEmpty
                      ? Image.memory(
                          base64Decode(
                            widget.story.coverImage!.split(',').last,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[900],
                              child: const Icon(
                                Icons.book,
                                size: 100,
                                color: Colors.white24,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.book,
                            size: 100,
                            color: Colors.white24,
                          ),
                        ),
                  // Gradient overlay (du bas vers le haut)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    widget.story.title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Métadonnées (Genre, Chapitres, Auteur)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMetaChip(
                        icon: Icons.category_outlined,
                        label: widget.story.genre,
                      ),
                      _buildMetaChip(
                        icon: Icons.menu_book_outlined,
                        label: '${widget.story.chapters} chapitres',
                      ),
                      if (widget.story.rating != null)
                        _buildMetaChip(
                          icon: Icons.star,
                          label: widget.story.rating!.toStringAsFixed(1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Auteur avec avatar
                  GestureDetector(
                    onTap: () {
                      // TODO: Naviguer vers le profil de l'auteur
                    },
                    child: Row(
                      children: [
                        // Avatar de l'auteur
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          child: ClipOval(child: _buildAuthorAvatar()),
                        ),
                        const SizedBox(width: 12),
                        // Nom de l'auteur
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'By',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                              Text(
                                widget.story.author,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Boutons d'action
                  Row(
                    children: [
                      // Bouton Lire
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isLoadingStory
                              ? null
                              : () async {
                                  setState(() => _isLoadingStory = true);
                                  try {
                                    // Charger les détails complets de l'histoire avec les chapitres
                                    final storyService = StoryService();
                                    final fullStory = await storyService
                                        .getStoryById(widget.story.id);

                                    // Vérifier qu'il y a des chapitres
                                    if (fullStory.chaptersList.isEmpty) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Cette histoire n\'a pas encore de chapitres',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    // Récupérer la dernière position de lecture
                                    final readingService = ReadingService();
                                    final lastPosition = await readingService
                                        .getLastPosition(fullStory.id);

                                    int startChapter = 0;
                                    if (lastPosition != null &&
                                        lastPosition['chapter_id'] != null) {
                                      // Trouver l'index du chapitre
                                      final chapterIndex = fullStory
                                          .chaptersList
                                          .indexWhere(
                                            (c) =>
                                                c['id'] ==
                                                lastPosition['chapter_id'],
                                          );
                                      if (chapterIndex >= 0) {
                                        startChapter = chapterIndex;
                                      }
                                    }

                                    if (mounted) {
                                      print(
                                        '🚀 [StoryDetailScreen] Navigation vers ReaderScreen',
                                      );
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReaderScreen(
                                            story: fullStory,
                                            initialChapterIndex: startChapter,
                                          ),
                                        ),
                                      );
                                      // Rafraîchir les stats quand on revient
                                      print(
                                        '↩️ [StoryDetailScreen] Retour du ReaderScreen - Rafraîchissement',
                                      );
                                      await _loadReadingStats();
                                      await _loadLastReadingPosition();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoadingStory = false);
                                    }
                                  }
                                },
                          icon: _isLoadingStory
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black,
                                    ),
                                  ),
                                )
                              : Icon(
                                  _hasStartedReading
                                      ? Icons.play_arrow
                                      : Icons.play_arrow,
                                  size: 28,
                                ),
                          label: Text(
                            _isLoadingStory
                                ? 'Chargement...'
                                : _hasStartedReading
                                ? 'Continuer'
                                : 'Lire',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasStartedReading
                                ? Colors.orange
                                : Colors.white,
                            foregroundColor: _hasStartedReading
                                ? Colors.white
                                : Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bouton Favoris
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Provider.of<StoryProvider>(
                              context,
                              listen: false,
                            ).toggleFavorite(widget.story.id);
                          },
                          icon: Icon(
                            widget.story.isFavorite ? Icons.check : Icons.add,
                            size: 24,
                          ),
                          label: Text(
                            widget.story.isFavorite ? 'Ajouté' : 'Ma liste',
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Synopsis
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Synopsis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedCrossFade(
                        firstChild: Text(
                          widget.story.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        secondChild: Text(
                          widget.story.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        crossFadeState: _isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                      if (widget.story.description.length > 150)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Text(
                            _isExpanded ? 'Voir moins' : 'Voir plus',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section stats et completion
                  _buildStatsSection(),

                  const SizedBox(height: 32),

                  // Liste des chapitres
                  const Text(
                    'Chapitres',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildChaptersList(),

                  const SizedBox(height: 32),

                  // À propos de l'auteur
                  const Text(
                    'À propos de l\'auteur',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAuthorSection(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersList() {
    // Pour l'instant, afficher des chapitres fictifs
    // TODO: Récupérer les vrais chapitres depuis l'API
    final chapters = List.generate(
      widget.story.chapters,
      (index) => {
        'number': index + 1,
        'title': 'Chapitre ${index + 1}',
        'duration': '${(index % 3 + 1) * 5} min',
      },
    );

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: chapters.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${chapter['number']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            chapter['title'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            chapter['duration'] as String,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_outline, color: Colors.white70),
            onPressed: () {
              // Naviguer vers le lecteur à ce chapitre
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReaderScreen(
                    story: widget.story,
                    initialChapterIndex: index,
                  ),
                ),
              );
            },
          ),
          onTap: () {
            // Naviguer vers le lecteur à ce chapitre
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReaderScreen(
                  story: widget.story,
                  initialChapterIndex: index,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuthorSection() {
    return GestureDetector(
      onTap: () {
        // Naviguer vers le profil de l'auteur
        // Note: Pour l'instant on utilise un ID fictif, il faudra récupérer le vrai author_id
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthorProfileScreen(
              authorId: 1, // TODO: Récupérer le vrai author_id depuis la Story
              authorName: widget.story.author,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            // Avatar de l'auteur
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child:
                    widget.story.authorAvatar != null &&
                        widget.story.authorAvatar!.isNotEmpty
                    ? _buildAuthorAvatarLarge()
                    : const Icon(Icons.person, color: Colors.white70, size: 30),
              ),
            ),
            const SizedBox(width: 16),
            // Infos auteur
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.story.author,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Afficher le nombre de followers
                  Text(
                    widget.story.authorFollowers != null
                        ? '${widget.story.authorFollowers} followers'
                        : 'Followers',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Bouton suivre
            OutlinedButton(
              onPressed: _isLoadingFollow ? null : _toggleFollow,
              style: OutlinedButton.styleFrom(
                foregroundColor: _isFollowing ? Colors.white : Colors.white,
                backgroundColor: _isFollowing
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
                side: BorderSide(
                  color: _isFollowing ? Colors.white : Colors.white70,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _isLoadingFollow
                    ? 'Chargement...'
                    : (_isFollowing ? 'Suivi' : 'Suivre'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Méthode pour construire l'avatar de l'auteur en base64 (version large pour la section "À propos")
  Widget _buildAuthorAvatarLarge() {
    if (widget.story.authorAvatar != null &&
        widget.story.authorAvatar!.isNotEmpty) {
      try {
        final base64String = widget.story.authorAvatar!.contains(',')
            ? widget.story.authorAvatar!.split(',').last
            : widget.story.authorAvatar!;

        return Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.person, color: Colors.white70, size: 30);
          },
        );
      } catch (e) {
        return const Icon(Icons.person, color: Colors.white70, size: 30);
      }
    }
    return const Icon(Icons.person, color: Colors.white70, size: 30);
  }

  // Méthode pour construire l'avatar de l'auteur en base64
  Widget _buildAuthorAvatar() {
    // Afficher l'avatar en base64 s'il existe, sinon afficher une icône par défaut
    if (widget.story.authorAvatar != null &&
        widget.story.authorAvatar!.isNotEmpty) {
      try {
        // Décoder le base64
        final base64String = widget.story.authorAvatar!.contains(',')
            ? widget.story.authorAvatar!.split(',').last
            : widget.story.authorAvatar!;

        return Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.withOpacity(0.3),
              child: const Icon(Icons.person, color: Colors.white70, size: 24),
            );
          },
        );
      } catch (e) {
        // En cas d'erreur de décodage, afficher l'icône par défaut
        return Container(
          color: Colors.grey.withOpacity(0.3),
          child: const Icon(Icons.person, color: Colors.white70, size: 24),
        );
      }
    }
    // Si pas d'avatar, afficher l'icône par défaut
    return Container(
      color: Colors.grey.withOpacity(0.3),
      child: const Icon(Icons.person, color: Colors.white70, size: 24),
    );
  }

  // Section pour afficher les stats et le statut de completion
  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statut de lecture
        if (_isCompleted)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              border: Border.all(color: Colors.green, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vous avez complété cette histoire',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (_completionInfo != null)
                        Text(
                          'Temps de lecture: ${_completionInfo!['total_reading_time_hours']} h',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Stats publiques
        if (_readingStats != null && !_isLoadingStats)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('${_readingStats!['total_views'] ?? 0}', 'Vues'),
                Container(height: 40, width: 1, color: Colors.white12),
                _buildStatItem(
                  '${_readingStats!['unique_readers'] ?? 0}',
                  'Lecteurs',
                ),
                Container(height: 40, width: 1, color: Colors.white12),
                _buildStatItem(
                  '${_readingStats!['completed_reads'] ?? 0}',
                  'Complétées',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
