import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/reaction_service.dart';
import '../services/websocket_service.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import 'reaction_picker.dart';

class CommentsBottomSheet extends StatefulWidget {
  final int storyId;
  final String storyTitle;

  const CommentsBottomSheet({
    super.key,
    required this.storyId,
    required this.storyTitle, required Null Function() onCommentAdded,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final ReactionService _reactionService = ReactionService();
  final WebSocketService _wsService = WebSocketService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _comments = [];
  bool _isSubmitting = false;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  
  // Pour les réactions des commentaires
  Map<int, String?> _commentReactionTypes = {}; // Type de réaction de l'utilisateur
  Map<int, Map<String, int>> _commentReactionCounts = {}; // Nombre total par type
  int? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupWebSocketListeners();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // Load from cache first
    final cached = await _getCachedComments();
    if (cached != null && mounted) {
      setState(() {
        _comments = cached['comments'] ?? [];
      });
    }
    
    // Refresh in background
    _refreshComments();
  }

  Future<Map<String, dynamic>?> _getCachedComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'comments_${widget.storyId}';
      final cached = prefs.getString(key);
      
      if (cached != null) {
        final data = json.decode(cached);
        final timestamp = data['timestamp'] as int?;
        
        if (timestamp != null) {
          final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          
          // Cache valid for 5 minutes
          if (now.difference(cacheTime).inMinutes < 5) {
            return data['data'] as Map<String, dynamic>?;
          }
        }
      }
    } catch (e) {
      print('Error loading cached comments: $e');
    }
    return null;
  }

  Future<void> _cacheComments(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'comments_${widget.storyId}';
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      };
      await prefs.setString(key, json.encode(cacheData));
    } catch (e) {
      print('Error caching comments: $e');
    }
  }

  Future<void> _refreshComments() async {
    try {
      final data = await _reactionService.getStoryComments(widget.storyId);
      if (mounted) {
        setState(() {
          _comments = data['comments'] ?? [];
          _page = 1;
          final total = data['pagination']?['total'] ?? _comments.length;
          _hasMore = _comments.length < total;
          
          // Initialiser les réactions depuis la réponse du serveur
          _commentReactionTypes.clear();
          _commentReactionCounts.clear();
          
          for (var comment in _comments) {
            final commentId = comment['id'] as int;
            // Le serveur retourne user_reaction_type et reaction_counts
            _commentReactionTypes[commentId] = comment['user_reaction_type'];
            _commentReactionCounts[commentId] = 
                Map<String, int>.from(comment['reaction_counts'] ?? {});
            
            // Traiter aussi les réponses si elles existent
            if (comment['replies'] != null && comment['replies'] is List) {
              for (var reply in comment['replies']) {
                final replyId = reply['id'] as int;
                _commentReactionTypes[replyId] = reply['user_reaction_type'];
                _commentReactionCounts[replyId] = 
                    Map<String, int>.from(reply['reaction_counts'] ?? {});
              }
            }
          }
        });
        
        // Cache the data
        await _cacheComments(data);
      }
    } catch (e) {
      print('Error refreshing comments: $e');
    }
  }

  void _setupWebSocketListeners() {
    _wsService.onCommentAdded((data) {
      if (data['story_id'] == widget.storyId && mounted) {
        final comment = data['comment'];
        setState(() {
          _comments.insert(0, comment);
          
          // Initialiser les réactions pour le nouveau commentaire
          final commentId = comment['id'] as int;
          _commentReactionTypes[commentId] = comment['user_reaction_type'];
          _commentReactionCounts[commentId] = 
              Map<String, int>.from(comment['reaction_counts'] ?? {});
        });
        
        // Update cache
        _cacheComments({
          'comments': _comments,
          'pagination': {
            'total': _comments.length,
            'page': 1,
            'limit': 20,
            'pages': 1,
          }
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreComments();
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final nextPage = _page + 1;
      final data = await _reactionService.getStoryComments(
        widget.storyId,
        page: nextPage,
      );
      
      final newComments = data['comments'] as List? ?? [];
      final total = data['pagination']?['total'] ?? 0;
      
      if (mounted) {
        setState(() {
          _comments.addAll(newComments);
          _page = nextPage;
          _hasMore = _comments.length < total;
          _isLoadingMore = false;
          
          // Initialiser les réactions pour les nouveaux commentaires
          for (var comment in newComments) {
            final commentId = comment['id'] as int;
            _commentReactionTypes[commentId] = comment['user_reaction_type'];
            _commentReactionCounts[commentId] = 
                Map<String, int>.from(comment['reaction_counts'] ?? {});
            
            // Traiter aussi les réponses
            if (comment['replies'] != null && comment['replies'] is List) {
              for (var reply in comment['replies']) {
                final replyId = reply['id'] as int;
                _commentReactionTypes[replyId] = reply['user_reaction_type'];
                _commentReactionCounts[replyId] = 
                    Map<String, int>.from(reply['reaction_counts'] ?? {});
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  int _getCommentItemCount() {
    int count = 0;
    for (final comment in _comments) {
      count++; // Le commentaire principal
      final replies = comment['replies'] as List?;
      if (replies != null) {
        count += replies.length; // Les réponses
      }
    }
    return count;
  }

  Map<String, dynamic>? _getCommentAtIndex(int index) {
    int currentIndex = 0;
    
    for (final comment in _comments) {
      if (currentIndex == index) {
        return {'comment': comment, 'isReply': false};
      }
      currentIndex++;
      
      final replies = comment['replies'] as List?;
      if (replies != null) {
        for (final reply in replies) {
          if (currentIndex == index) {
            return {'comment': reply, 'isReply': true};
          }
          currentIndex++;
        }
      }
    }
    return null;
  }

  Future<void> _toggleCommentReaction(int commentId, String reactionType) async {
    try {
      // Optimistic update - update UI immediately
      final currentReaction = _commentReactionTypes[commentId];
      final currentCounts = _commentReactionCounts[commentId] ?? {};
      
      setState(() {
        // If same reaction, remove it
        if (currentReaction == reactionType) {
          _commentReactionTypes[commentId] = null;
          final newCounts = Map<String, int>.from(currentCounts);
          newCounts[reactionType] = (newCounts[reactionType] ?? 1) - 1;
          if (newCounts[reactionType]! <= 0) {
            newCounts.remove(reactionType);
          }
          _commentReactionCounts[commentId] = newCounts;
        } else {
          // Remove old reaction count if exists
          final newCounts = Map<String, int>.from(currentCounts);
          if (currentReaction != null) {
            newCounts[currentReaction] = (newCounts[currentReaction] ?? 1) - 1;
            if (newCounts[currentReaction]! <= 0) {
              newCounts.remove(currentReaction);
            }
          }
          // Add new reaction
          _commentReactionTypes[commentId] = reactionType;
          newCounts[reactionType] = (newCounts[reactionType] ?? 0) + 1;
          _commentReactionCounts[commentId] = newCounts;
        }
      });
      
      // Send to server (in background)
      final response = await _reactionService.toggleCommentReaction(
        commentId,
        reactionType: reactionType,
      );
      
      // Update with server response
      if (mounted) {
        setState(() {
          _commentReactionTypes[commentId] = response['userReactionType'];
          _commentReactionCounts[commentId] = 
              Map<String, int>.from(response['reactionCounts'] ?? {});
        });
      }
      
    } catch (e) {
      // Revert on error
      if (mounted) {
        // Reload comment reactions from server
        _refreshComments();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _replyToComment(int commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      setState(() => _isSubmitting = true);
      // Conserver l'ID du commentaire parent avant de réinitialiser l'état de réponse
      final parentId = _replyingToCommentId;
      
      // Optimistic update - add comment immediately
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      
      final optimisticComment = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'comment_text': text,
        'created_at': DateTime.now().toIso8601String(),
        'is_edited': false,
        'parent_comment_id': parentId,
        'user': {
          'id': user?['id'],
          'username': user?['username'],
          'email': user?['email'],
          'avatar': user?['avatar'],
        },
        'author': null,
      };
      
      setState(() {
        _comments.insert(0, optimisticComment);
        // Initialiser les likes pour le commentaire optimiste
        final commentId = optimisticComment['id'] as int;
        _commentReactionTypes[commentId] = null;
        _commentReactionCounts[commentId] = {};
      });
      
      _commentController.clear();
      _focusNode.unfocus();
      
      // Send to server
      await _reactionService.addComment(
        widget.storyId,
        text,
        parentCommentId: parentId,
      );
      _cancelReply();
      
      setState(() => _isSubmitting = false);
      
      // Refresh to get actual comment with ID
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshComments();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error'.tr() + ': $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.9],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header avec drag handle
              Container(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: dividerColor!)),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: subtextColor,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title avec close button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'comments_title'.tr(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              child: Icon(Icons.close, color: textColor, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              
              // Comments list
              Expanded(
                child: _comments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dividerColor,
                                ),
                                child: Icon(
                                  Icons.mode_comment_outlined,
                                  size: 50,
                                  color: subtextColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Aucun commentaire',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Soyez le premier à commenter',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshComments,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: _getCommentItemCount() + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _getCommentItemCount()) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      const Color(0xFF1DB954),
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            // Récupérer le commentaire ou réponse à afficher
                            final item = _getCommentAtIndex(index);
                            if (item == null) return const SizedBox.shrink();
                            
                            final isReply = item['isReply'] as bool? ?? false;
                            final comment = item['comment'] as Map<String, dynamic>?;
                            
                            if (comment == null) return const SizedBox.shrink();
                            
                            return _buildCommentItem(
                              comment,
                              textColor,
                              subtextColor,
                              dividerColor,
                              isReply: isReply,
                            );
                          },
                        ),
                      ),
              ),
              
              // Comment input - Instagram style
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(top: BorderSide(color: dividerColor)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply indicator
                      if (_replyingToCommentId != null)
                        Container(
                          color: dividerColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Réponse à ${_replyingToUsername}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtextColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _cancelReply,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: subtextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Avatar
                            _buildCurrentUserAvatar(authProvider, isDark, subtextColor),
                            const SizedBox(width: 10),
                            // Input field avec style Instagram
                            Expanded(
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 100),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: TextField(
                                  controller: _commentController,
                                  focusNode: _focusNode,
                                  maxLines: null,
                                  textCapitalization: TextCapitalization.sentences,
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  onChanged: (value) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'Ajouter un commentaire...',
                                    hintStyle: TextStyle(color: subtextColor),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Send button
                            Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _commentController.text.trim().isEmpty ||
                                    _isSubmitting
                                ? null
                                : _submitComment,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          const Color(0xFF1DB954),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.send_rounded,
                                      color: _commentController.text
                                              .trim()
                                              .isEmpty
                                          ? subtextColor
                                          : const Color(0xFF1DB954),
                                      size: 20,
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentUserAvatar(
    AuthProvider authProvider,
    bool isDark,
    Color? subtextColor,
  ) {
    final user = authProvider.user;
    final avatar = user?['avatar'];
    final username = user?['username'] ?? user?['email']?.split('@')[0] ?? 'U';
    
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF1DB954),
      backgroundImage: avatar != null && _isValidAvatar(avatar)
          ? _getAvatarImage(avatar)
          : null,
      child: avatar == null || !_isValidAvatar(avatar)
          ? Text(
              username[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            )
          : null,
    );
  }

  bool _isValidAvatar(dynamic avatar) {
    if (avatar == null) return false;
    final avatarStr = avatar.toString();
    return avatarStr.isNotEmpty && avatarStr != 'null';
  }

  ImageProvider? _getAvatarImage(dynamic avatar) {
    try {
      final avatarStr = avatar.toString();
      
      // Check if it's a base64 string
      if (avatarStr.contains('base64') || avatarStr.contains(',')) {
        final base64Str = avatarStr.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      }
      
      // Check if it's a URL path
      if (avatarStr.startsWith('/uploads/')) {
        final apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:5500';
        return NetworkImage('$apiUrl$avatarStr');
      }
      
      // Full URL
      return NetworkImage(avatarStr);
    } catch (e) {
      return null;
    }
  }

  Widget _buildCommentItem(
    Map<String, dynamic> comment,
    Color textColor,
    Color? subtextColor,
    Color? dividerColor, {
    bool isReply = false,
  }) {
    final user = comment['user'];
    final author = comment['author'];
    final isAuthor = author != null;
    
    final username = isAuthor
        ? (author['pseudo'] ?? author['email']?.split('@')[0] ?? 'Creator')
        : (user?['username'] ?? user?['email']?.split('@')[0] ?? 'User');
    
    final avatar = isAuthor ? author['avatar'] : user?['avatar'];
    final isPremium = isAuthor 
        ? (author?['is_premium'] ?? false)
        : (user?['is_premium'] ?? false);
    
    final commentText = comment['comment_text'] ?? '';
    final createdAt = comment['created_at'];
    final isEdited = comment['is_edited'] == true;
    
    // Get reaction data
    final commentId = comment['id'] as int;
    final userReactionType = _commentReactionTypes[commentId];
    final reactionCounts = _commentReactionCounts[commentId] ?? {};
    final totalReactions = reactionCounts.values.fold<int>(0, (sum, count) => sum + count);
    final hasReacted = userReactionType != null;

    final timeAgo = createdAt != null
        ? _formatTimeAgo(DateTime.parse(createdAt.toString()))
        : '';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isReply ? 28 : 12,
        vertical: 10,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left bar for replies
              if (isReply)
                Container(
                  width: 3,
                  height: 50,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF1DB954),
                backgroundImage: avatar != null && _isValidAvatar(avatar)
                    ? _getAvatarImage(avatar)
                    : null,
                child: avatar == null || !_isValidAvatar(avatar)
                    ? Text(
                        username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply indicator
                    if (isReply)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'comment_reply_to_comment'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: subtextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    // Username, badges, time
                    Wrap(
                      spacing: 4,
                      alignment: WrapAlignment.start,
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                        if (isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'premium_badge'.tr(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isAuthor)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'author_badge'.tr(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Comment text
                    Text(
                      commentText,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                    if (isEdited)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '(modifié)',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Actions - Réaction et Reply
                    Row(
                      children: [
                        // Reaction button avec long press
                        Material(
                          color: Colors.transparent,
                          child: GestureDetector(
                            onTap: () {
                              final commentId = comment['id'];
                              if (commentId != null) {
                                _toggleCommentReaction(commentId as int, 'like');
                              }
                            },
                            onLongPress: () {
                              final commentId = comment['id'];
                              if (commentId != null) {
                                final RenderBox box = context.findRenderObject() as RenderBox;
                                final position = box.localToGlobal(Offset.zero);
                                
                                ReactionPicker.show(
                                  context,
                                  currentReaction: userReactionType,
                                  position: Offset(position.dx, position.dy + 100),
                                  onReactionSelected: (reactionType) {
                                    _toggleCommentReaction(commentId as int, reactionType);
                                  },
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  if (hasReacted)
                                    Text(
                                      ReactionPicker.getReactionEmoji(userReactionType),
                                      style: const TextStyle(fontSize: 16),
                                    )
                                  else
                                    Icon(
                                      Icons.favorite_border,
                                      size: 14,
                                      color: subtextColor,
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    totalReactions > 0
                                        ? totalReactions.toString()
                                        : 'like_button'.tr(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: hasReacted ? const Color(0xFFFC3C44) : subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Reply button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _replyToComment(comment['id'] ?? 0, username);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Text(
                                'reply_button'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: subtextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 30) {
      // Use 'fr' locale as fallback since 'mg' (Malagasy) is not supported by intl
      return DateFormat('d MMM', 'fr').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}${'d'.tr()}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}${'h'.tr()}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}${'m'.tr()}';
    } else {
      return 'now'.tr();
    }
  }
}
