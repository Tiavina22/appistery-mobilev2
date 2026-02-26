import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/story_service.dart';
import '../services/reading_service.dart';
import '../services/author_service.dart';
import '../services/reaction_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/facebook_notification.dart';
import 'author_profile_screen.dart';
import 'reader_screen.dart';
import '../widgets/comments_bottom_sheet.dart';

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
  late ReactionService _reactionService;

  // Langue d'affichage sélectionnée (clé backend: gasy, fr, en)
  String _selectedLang = 'gasy';

  // États pour les réactions
  Map<String, dynamic>? _reactionsData;
  bool _isLoadingReactions = false;
  bool _hasUserReacted = false;
  int _commentsCount = 0;

  // Nouveaux états pour le suivi de lecture
  bool _isCompleted = false;
  Map<String, dynamic>? _readingStats;
  bool _isLoadingStats = false;

  // États pour le statut de lecture
  bool _hasStartedReading = false;

  // États pour les favoris
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;

  // Story avec chapitres chargés
  Story? _fullStory;
  bool _isLoadingChapters = false;

  // États pour la gestion des erreurs
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authorService = AuthorService();
    _reactionService = ReactionService();
    _isFavorite = widget.story.isFavorite;
    _loadFollowingStatus();
    _loadReadingStats();
    _loadLastReadingPosition();
    _loadReactions();
    _loadFullStoryWithChapters();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadLastReadingPosition() async {
    try {
      final readingService = ReadingService();
      final lastPosition = await readingService.getLastPosition(
        widget.story.id,
      );

      if (mounted) {
        setState(() {
          _hasStartedReading = lastPosition != null;
        });
        if (lastPosition != null) {
        } else {
        }
      }
    } catch (e) {
      debugPrint('❌ [StoryDetailScreen] Error loading last reading position: $e');
      // Non-critique, ne pas bloquer l'affichage
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
          _isCompleted =
              completionInfo != null && completionInfo['is_completed'] == true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [StoryDetailScreen] Error loading reading stats: $e');
      debugPrint('Stack trace: $stackTrace');
      // Non-critique, ne pas bloquer l'affichage
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
      debugPrint('❌ [StoryDetailScreen] Error loading following status: $e');
      // Non-critique, ne pas bloquer l'affichage
    }
  }

  Future<void> _loadReactions() async {
    try {
      setState(() => _isLoadingReactions = true);
      final data = await _reactionService.getStoryReactions(widget.story.id);

      // Charger aussi le nombre de commentaires
      final commentsData = await _reactionService.getStoryComments(
        widget.story.id,
      );
      final comments = commentsData['comments'] as List? ?? [];

      if (mounted) {
        setState(() {
          _reactionsData = data;
          _hasUserReacted = data['userReaction'] != null;
          _commentsCount =
              commentsData['pagination']?['total'] ?? comments.length;
          _isLoadingReactions = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [StoryDetailScreen] Error loading reactions: $e');
      // Non-critique, ne pas bloquer l'affichage
      if (mounted) {
        setState(() => _isLoadingReactions = false);
      }
    }
  }

  Future<void> _toggleReaction() async {
    try {
      // Sauvegarder l'état actuel avant le toggle
      final hadReactionBefore = _hasUserReacted;

      await _reactionService.toggleReaction(widget.story.id);
      await _loadReactions();

      if (mounted) {
        // Si l'utilisateur n'avait pas réagi avant et maintenant oui = ajout
        if (!hadReactionBefore && _hasUserReacted) {
          NotificationOverlay.show(
            context,
            message: 'Vous aimez cette histoire',
            icon: Icons.favorite,
            backgroundColor: Colors.pink[600]!,
            duration: const Duration(seconds: 2),
          );
        }
        // Si l'utilisateur avait réagi avant et maintenant non = retrait
        else if (hadReactionBefore && !_hasUserReacted) {
          NotificationOverlay.show(
            context,
            message: 'Réaction retirée',
            icon: Icons.favorite_border,
            backgroundColor: Colors.grey[600]!,
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationOverlay.show(
          context,
          message: '${'error'.tr()}: ${e.toString()}',
          icon: Icons.error_outline,
          backgroundColor: Colors.red[600]!,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  void _openComments() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        storyId: widget.story.id,
        storyTitle: widget.story.title, onCommentAdded: () {  },
      ),
    );
    // Recharger le compteur de commentaires au retour
    _loadReactions();
  }

  Future<void> _loadFullStoryWithChapters() async {
    if (_isLoadingChapters) return;

    setState(() {
      _isLoadingChapters = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      final storyService = StoryService();
      final fullStory = await storyService.getStoryById(widget.story.id);
      if (mounted) {
        setState(() {
          _fullStory = fullStory;
          _isLoadingChapters = false;
          _hasError = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [StoryDetailScreen] Error loading full story: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isLoadingFollow = true);
    try {
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
            message: '${'now_following'.tr()} ${widget.story.author}',
            icon: Icons.check_circle_outline,
            backgroundColor: const Color(0xFFFA586A),
            duration: const Duration(seconds: 3),
          );
        } else {
          NotificationOverlay.show(
            context,
            message: '${'unfollowed'.tr()} ${widget.story.author}',
            icon: Icons.remove_circle_outline,
            backgroundColor: const Color(0xFFFA586A),
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationOverlay.show(
          context,
          message: '${'error'.tr()}: ${e.toString()}',
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

  Future<void> _toggleFavorite() async {
    if (_isLoadingFavorite) return;

    setState(() => _isLoadingFavorite = true);
    try {
      final storyService = StoryService();

      if (_isFavorite) {
        await storyService.removeFavorite(widget.story.id);
      } else {
        await storyService.addFavorite(widget.story.id);
      }

      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
        });

        // Afficher une notification
        NotificationOverlay.show(
          context,
          message: _isFavorite ? 'Ajouté à Ma liste' : 'Retiré de Ma liste',
          icon: _isFavorite ? Icons.check : Icons.remove,
          backgroundColor: const Color(0xFFFA586A),
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationOverlay.show(
          context,
          message: '${'error'.tr()}: ${e.toString()}',
          icon: Icons.error_outline,
          backgroundColor: Colors.red[600]!,
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFavorite = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textColorSecondary = isDarkMode ? Colors.white70 : Colors.black54;
    final borderColor = isDarkMode ? Colors.white24 : Colors.black12;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Image de couverture avec gradient overlay
          SliverAppBar(
            expandedHeight: size.height * 0.4,
            pinned: true,
            backgroundColor: backgroundColor,
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
            actions: [],
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
                  if (widget.story.coverImage != null &&
                      widget.story.coverImage!.isNotEmpty) {
                    _showFullScreenImage(context);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image de couverture
                    _buildCoverImage(fit: BoxFit.cover),
                    // Gradient overlay (du bas vers le haut) - toujours noir pour le contraste avec l'image
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
                    // Stats en overlay style Instagram
                    if (_readingStats != null && !_isLoadingStats)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCompactStat(
                                Icons.visibility_outlined,
                                '${_readingStats!['total_views'] ?? 0}',
                              ),
                              const SizedBox(width: 12),
                              _buildCompactStat(
                                Icons.people_outline,
                                '${_readingStats!['unique_readers'] ?? 0}',
                              ),
                              const SizedBox(width: 12),
                              _buildCompactStat(
                                Icons.check_circle_outline,
                                '${_readingStats!['completed_reads'] ?? 0}',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
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
                    widget.story.titleMap.isNotEmpty
                        ? (widget.story.titleMap[_selectedLang] ?? widget.story.title)
                        : widget.story.title,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),

                  // Sélecteur de langue si plusieurs langues disponibles
                  if (widget.story.availableLanguages.length > 1) ...[
                    const SizedBox(height: 10),
                    _buildLanguageSelector(isDarkMode),
                  ],

                  const SizedBox(height: 12),

                  // Métadonnées (Genre, Chapitres, Auteur)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMetaChip(
                        icon: Icons.category_outlined,
                        label: widget.story.genre,
                        isDarkMode: isDarkMode,
                      ),
                      _buildMetaChip(
                        icon: Icons.menu_book_outlined,
                        label: '${widget.story.chapters} ${'chapters'.tr()}',
                        isDarkMode: isDarkMode,
                      ),
                      if (widget.story.rating != null)
                        _buildMetaChip(
                          icon: Icons.star,
                          label: widget.story.rating!.toStringAsFixed(1),
                          isDarkMode: isDarkMode,
                        ),
                      if (widget.story.createdAt != null)
                        _buildMetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: DateFormat(
                            'dd MMM yyyy',
                            context.locale.languageCode,
                          ).format(widget.story.createdAt!),
                          isDarkMode: isDarkMode,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Auteur avec avatar
                  GestureDetector(
                    onTap: () {
                      // Naviguer vers le profil de l'auteur
                      if (widget.story.authorId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AuthorProfileScreen(
                              authorId: widget.story.authorId!,
                              authorName: widget.story.author,
                            ),
                          ),
                        );
                      }
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
                          child: ClipOval(
                            child: _buildAuthorAvatar(isDarkMode: isDarkMode),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Nom de l'auteur
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'by'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColorSecondary,
                                ),
                              ),
                              Text(
                                widget.story.author,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
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
                                  // Vérifier le statut premium avant de continuer
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  final isUserPremium = authProvider.isPremium;
                                  final isStoryPremium = widget.story.isPremium;

                                  // Bloquer l'accès si l'histoire est premium et l'utilisateur ne l'est pas
                                  if (isStoryPremium && !isUserPremium) {
                                    _showPremiumLockedDialog();
                                    return;
                                  }

                                  setState(() => _isLoadingStory = true);
                                  try {
                                    // Utiliser _fullStory s'il est déjà chargé, sinon charger
                                    Story fullStory;
                                    if (_fullStory != null &&
                                        _fullStory!.chaptersList.isNotEmpty) {
                                      fullStory = _fullStory!;
                                    } else {
                                      final storyService = StoryService();
                                      fullStory = await storyService
                                          .getStoryById(widget.story.id);
                                    }

                                    // Vérifier qu'il y a des chapitres
                                    if (fullStory.chaptersList.isEmpty) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'no_chapters_yet'.tr(),
                                            ),
                                            backgroundColor: const Color(0xFFFA586A),
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
                                    // Si l'histoire est complétée, recommencer depuis le début
                                    // Sinon, continuer depuis la dernière position
                                    if (!_isCompleted &&
                                        lastPosition != null &&
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
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReaderScreen(
                                            story: fullStory,
                                            initialChapterIndex: startChapter,
                                            selectedLang: _selectedLang,
                                          ),
                                        ),
                                      );
                                      // Rafraîchir les stats quand on revient
                                       await _loadReadingStats();
                                      await _loadLastReadingPosition();
                                    }
                                  } catch (e) {
                                    debugPrint('❌ [StoryDetailScreen] Error opening reader: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('${'error'.tr()}: $e'),
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
                                  _isCompleted
                                      ? Icons.replay
                                      : (_hasStartedReading
                                            ? Icons.play_arrow
                                            : Icons.play_arrow),
                                  size: 28,
                                ),
                          label: Text(
                            _isLoadingStory
                                ? 'loading'.tr()
                                : _isCompleted
                                ? 'reread'.tr()
                                : (_hasStartedReading ? 'continue'.tr() : 'read'.tr()),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCompleted
                                ? const Color(0xFFFA586A)
                                : (_hasStartedReading
                                      ? const Color(0xFFFA586A)
                                      : (isDarkMode
                                            ? Colors.white
                                            : Colors.black)),
                            foregroundColor: _isCompleted
                                ? Colors.white
                                : (_hasStartedReading
                                      ? Colors.white
                                      : (isDarkMode
                                            ? Colors.black
                                            : Colors.white)),
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
                          onPressed: _isLoadingFavorite
                              ? null
                              : _toggleFavorite,
                          icon: Icon(
                            _isFavorite ? Icons.check : Icons.add,
                            size: 24,
                          ),
                          label: Text(
                            _isFavorite ? 'added_to_favorites'.tr() : 'add_to_list'.tr(),
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: textColorSecondary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Boutons de réactions et commentaires
                  Row(
                    children: [
                      // Bouton J'aime
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingReactions
                              ? null
                              : _toggleReaction,
                          icon: Icon(
                            _hasUserReacted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 20,
                            color: _hasUserReacted
                                ? Colors.pink
                                : textColorSecondary,
                          ),
                          label: Text(
                            _reactionsData != null &&
                                    _reactionsData!['totalCount'] != null
                                ? '${_reactionsData!['totalCount']}'
                                : '0',
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColorSecondary,
                            side: BorderSide(
                              color: _hasUserReacted
                                  ? Colors.pink
                                  : borderColor,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bouton Commentaires
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openComments,
                          icon: const Icon(Icons.comment_outlined, size: 20),
                          label: Text(
                            _commentsCount > 0
                                ? '$_commentsCount'
                                : 'Commentaires',
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColorSecondary,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                      Text(
                        'synopsis'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Text(
                          widget.story.synopsisMap.isNotEmpty
                              ? (widget.story.synopsisMap[_selectedLang] ?? widget.story.description)
                              : widget.story.description,
                          maxLines: _isExpanded ? null : 3,
                          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColorSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (widget.story.description.length > 150)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Text(
                            _isExpanded ? 'see_less'.tr() : 'see_more'.tr(),
                            style: TextStyle(
                              color: textColor,
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
                  Text(
                    'chapters_title'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildChaptersList(isDarkMode: isDarkMode),

                  const SizedBox(height: 32),

                  // À propos de l'auteur
                  Text(
                    'about_author'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAuthorSection(isDarkMode: isDarkMode),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required bool isDarkMode,
  }) {
    final chipBgColor = isDarkMode
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);
    final chipBorderColor = isDarkMode ? Colors.white24 : Colors.black12;
    final chipTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipTextColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: chipTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Sélecteur de langue pour les histoires multilingues
  Widget _buildLanguageSelector(bool isDarkMode) {
    final langs = widget.story.availableLanguages;
    if (langs.length <= 1) return const SizedBox.shrink();

    final textColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.translate, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              'Disponible en',
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: langs.map((langKey) {
            final isSelected = langKey == _selectedLang;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedLang = langKey;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1DB954)
                      : (isDarkMode
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1DB954)
                        : (isDarkMode ? Colors.white24 : Colors.black12),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  Story.languageDisplayName(langKey),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Resolves the story cover image URL for use in the premium dialog
  ImageProvider? _getCoverImageProvider() {
    final coverImage = widget.story.coverImage;
    if (coverImage == null || coverImage.isEmpty) return null;

    if (coverImage.startsWith('/uploads/')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:5500';
      return NetworkImage('$apiUrl$coverImage');
    }
    if (coverImage.startsWith('http://') || coverImage.startsWith('https://')) {
      return NetworkImage(coverImage);
    }
    // base64 fallback
    try {
      final b64 = coverImage.contains(',') ? coverImage.split(',').last : coverImage;
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  void _showPremiumLockedDialog() {
    final coverProvider = _getCoverImageProvider();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'premium',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim, secondAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) => Center(
        child: _PremiumLockedDialogContent(
          coverProvider: coverProvider,
          storyTitle: widget.story.title,
          onChooseOffer: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pushNamed('/subscription-offers');
          },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Widget _buildChaptersList({required bool isDarkMode}) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textColorSecondary = isDarkMode ? Colors.white70 : Colors.black54;
    final dividerColor = isDarkMode ? Colors.white12 : Colors.black12;

    // Afficher un loader pendant le chargement
    if (_isLoadingChapters) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFA586A)),
              ),
              const SizedBox(height: 16),
              Text(
                'Chargement des chapitres...',
                style: TextStyle(
                  fontSize: 14,
                  color: textColorSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Afficher un message d'erreur avec retry si le chargement a échoué
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Impossible de charger les chapitres',
                style: TextStyle(
                  fontSize: 14,
                  color: textColorSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColorSecondary.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = null;
                  });
                  _loadFullStoryWithChapters();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFA586A),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Vérifier le statut premium de l'utilisateur et de l'histoire
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isUserPremium = authProvider.isPremium;
    final isStoryPremium = widget.story.isPremium;

    // Fonction helper pour gérer la navigation vers un chapitre
    void navigateToChapter(int chapterIndex) {
      // Bloquer l'accès aux chapitres si l'histoire est premium et l'utilisateur ne l'est pas
      if (isStoryPremium && !isUserPremium) {
        _showPremiumLockedDialog();
        return;
      }

      // Utiliser _fullStory si disponible pour avoir les chapitres complets
      final storyForReader = _fullStory ?? widget.story;

      // Naviguer vers le lecteur
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(
            story: storyForReader,
            initialChapterIndex: chapterIndex,
            selectedLang: _selectedLang,
          ),
        ),
      );
    }

    // Utiliser les chapitres réels de l'histoire (depuis _fullStory si disponible, sinon widget.story)
    final storyToUse = _fullStory ?? widget.story;
    
    if (storyToUse.chaptersList.isNotEmpty) {
   
    }
    final chapters = storyToUse.chaptersList.isNotEmpty
        ? storyToUse.chaptersList
        : List.generate(
            storyToUse.chapters,
            (index) => {
              'chapter_number': index + 1,
              'title': '${'chapter_title'.tr()} ${index + 1}',
              'duration': '${(index % 3 + 1) * 5} ${'min_read'.tr()}',
            },
          );

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: chapters.length,
      separatorBuilder: (context, index) =>
          Divider(color: dividerColor, height: 1),
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        // Gérer le titre du chapitre (peut être une map avec lang ou un string)
        String chapterTitle = '';
        final titleData = chapter['title'];
        // Utiliser la langue sélectionnée par l'utilisateur (gasy par défaut)
        if (titleData is Map) {
          // Essayer d'abord la langue sélectionnée, puis gasy, puis les autres
          chapterTitle = titleData[_selectedLang]?.toString() ?? 
                        titleData['gasy']?.toString() ?? 
                        titleData['fr']?.toString() ?? 
                        titleData['en']?.toString() ??
                        titleData.values.firstOrNull?.toString() ??
                        '${'chapter_title'.tr()} ${index + 1}';
        } else if (titleData is String) {
          chapterTitle = titleData;
        } else {
          chapterTitle = '${'chapter_title'.tr()} ${index + 1}';
        }

        return InkWell(
          onTap: () => navigateToChapter(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Numéro du chapitre
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${chapter['chapter_number'] ?? chapter['number'] ?? index + 1}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Titre du chapitre
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chapterTitle,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Afficher l'icône lock pour les histoires premium
                      if (isStoryPremium && !isUserPremium)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.lock, color: Color(0xFFFA586A), size: 16),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton play
                IconButton(
                  icon: Icon(Icons.play_circle_outline, color: textColorSecondary, size: 28),
                  onPressed: () => navigateToChapter(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthorSection({required bool isDarkMode}) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textColorSecondary = isDarkMode ? Colors.white70 : Colors.black54;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

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
          color: isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Avatar de l'auteur
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child:
                    widget.story.authorAvatar != null &&
                        widget.story.authorAvatar!.isNotEmpty
                    ? _buildAuthorAvatarLarge(isDarkMode: isDarkMode)
                    : Icon(Icons.person, color: textColorSecondary, size: 30),
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
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Afficher le nombre de followers
                  Text(
                    widget.story.authorFollowers != null
                        ? '${widget.story.authorFollowers} ${'followers'.tr()}'
                        : 'followers'.tr(),
                    style: TextStyle(color: textColorSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Bouton suivre
            OutlinedButton(
              onPressed: _isLoadingFollow ? null : _toggleFollow,
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                backgroundColor: _isFollowing
                    ? (isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05))
                    : Colors.transparent,
                side: BorderSide(
                  color: _isFollowing ? textColor : textColorSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _isLoadingFollow
                    ? 'loading'.tr()
                    : (_isFollowing ? 'followed'.tr() : 'follow'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Méthode pour construire l'avatar de l'auteur (version large pour la section "À propos")
  Widget _buildAuthorAvatarLarge({required bool isDarkMode}) {
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    final avatarData = widget.story.authorAvatar;

    if (avatarData == null || avatarData.isEmpty) {
      return Icon(Icons.person, color: iconColor, size: 30);
    }

    // Vérifier si c'est une URL (commence par /uploads/ ou http)
    if (avatarData.startsWith('/uploads/') ||
        avatarData.startsWith('http://') ||
        avatarData.startsWith('https://')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:5500';
      final imageUrl = avatarData.startsWith('http')
          ? avatarData
          : '$apiUrl$avatarData';

      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, color: iconColor, size: 30);
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
          return Icon(Icons.person, color: iconColor, size: 30);
        },
      );
    } catch (e) {
      return Icon(Icons.person, color: iconColor, size: 30);
    }
  }

  // Méthode pour construire l'avatar de l'auteur (supporte URL et base64)
  Widget _buildAuthorAvatar({required bool isDarkMode}) {
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    final avatarData = widget.story.authorAvatar;

    if (avatarData == null || avatarData.isEmpty) {
      return Container(
        color: Colors.grey.withOpacity(0.3),
        child: Icon(Icons.person, color: iconColor, size: 24),
      );
    }

    // Vérifier si c'est une URL (commence par /uploads/ ou http)
    if (avatarData.startsWith('/uploads/') ||
        avatarData.startsWith('http://') ||
        avatarData.startsWith('https://')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:5500';
      final imageUrl = avatarData.startsWith('http')
          ? avatarData
          : '$apiUrl$avatarData';

      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.withOpacity(0.3),
            child: Icon(Icons.person, color: iconColor, size: 24),
          );
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
          return Container(
            color: Colors.grey.withOpacity(0.3),
            child: Icon(Icons.person, color: iconColor, size: 24),
          );
        },
      );
    } catch (e) {
      return Container(
        color: Colors.grey.withOpacity(0.3),
        child: Icon(Icons.person, color: iconColor, size: 24),
      );
    }
  }

  // Section pour afficher les stats et le statut de completion
  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge de lecture complétée
        if (_isCompleted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFA586A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  'already_read'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

        if (_isCompleted) const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCompactStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // Méthode pour afficher l'image de couverture en plein écran
  void _showFullScreenImage(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image en plein écran
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: InteractiveViewer(
                  child: Center(
                    child: _buildCoverImage(fit: BoxFit.contain),
                  ),
                ),
              ),
              // Bouton de fermeture
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to build cover image (supports both URL and base64)
  Widget _buildCoverImage({required BoxFit fit}) {
    final coverImage = widget.story.coverImage;
    
    if (coverImage == null || coverImage.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Icon(
          Icons.book,
          size: 100,
          color: Colors.white24,
        ),
      );
    }

    // Vérifier si c'est une URL relative (commence par /uploads/)
    if (coverImage.startsWith('/uploads/')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:5500';
      final imageUrl = '$apiUrl$coverImage';
      
      return Image.network(
        imageUrl,
        fit: fit,
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
      );
    }
    
    // Vérifier si c'est une URL complète
    if (coverImage.startsWith('http://') || coverImage.startsWith('https://')) {
      return Image.network(
        coverImage,
        fit: fit,
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
      );
    }
    
    // Sinon, c'est du base64 (backward compatibility)
    try {
      final base64String = coverImage.contains(',')
          ? coverImage.split(',').last
          : coverImage;
      
      return Image.memory(
        base64Decode(base64String),
        fit: fit,
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
      );
    } catch (e) {
      return Container(
        color: Colors.grey[900],
        child: const Icon(
          Icons.book,
          size: 100,
          color: Colors.white24,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Apple Music–style Premium Locked Dialog
// ---------------------------------------------------------------------------
class _PremiumLockedDialogContent extends StatelessWidget {
  final ImageProvider? coverProvider;
  final String storyTitle;
  final VoidCallback onChooseOffer;
  final VoidCallback onCancel;

  const _PremiumLockedDialogContent({
    required this.coverProvider,
    required this.storyTitle,
    required this.onChooseOffer,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = screenW * 0.82;
    final artSize = dialogW * 0.52;

    // Adaptive Apple-style palette
    final bgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor =
        isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);
    final cancelColor =
        isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
    final ctaColor =
        isDark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55);
    final placeholderBg =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE0E0E0);
    final placeholderIcon =
        isDark ? Colors.white24 : Colors.black26;
    final blurTint = isDark
        ? Colors.black.withOpacity(0.50)
        : Colors.white.withOpacity(0.45);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: dialogW,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: bgColor,
        ),
        child: Stack(
          children: [
            // ── Blurred tint background ──
            if (coverProvider != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        blurTint,
                        BlendMode.srcOver,
                      ),
                      child: Image(
                        image: coverProvider!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Foreground content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cover art with shadow
                  Container(
                    width: artSize,
                    height: artSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.45 : 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: coverProvider != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image(
                                  image: coverProvider!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: placeholderBg,
                                    child: Icon(
                                      Icons.auto_stories_rounded,
                                      size: 48,
                                      color: placeholderIcon,
                                    ),
                                  ),
                                ),
                                // Subtle lock overlay
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: placeholderBg,
                              child: Icon(
                                Icons.auto_stories_rounded,
                                size: 48,
                                color: placeholderIcon,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Story title
                  Text(
                    storyTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'premium_cta_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 14,
                      height: 1.4,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CTA Button – Apple-style filled rounded
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onChooseOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ctaColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'premium_go_choose_offer'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Cancel
                  GestureDetector(
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'cancel'.tr(),
                        style: TextStyle(
                          color: cancelColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
