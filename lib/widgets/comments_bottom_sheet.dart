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

class CommentsBottomSheet extends StatefulWidget {
  final int storyId;
  final String storyTitle;

  const CommentsBottomSheet({
    super.key,
    required this.storyId,
    required this.storyTitle,
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      setState(() => _isSubmitting = true);
      
      // Optimistic update - add comment immediately
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      
      final optimisticComment = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'comment_text': text,
        'created_at': DateTime.now().toIso8601String(),
        'is_edited': false,
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
      });
      
      _commentController.clear();
      _focusNode.unfocus();
      
      // Send to server
      await _reactionService.addComment(widget.storyId, text);
      
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
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: dividerColor!)),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: subtextColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Title
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'comments'.tr(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
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
                              Icon(
                                Icons.mode_comment_outlined,
                                size: 80,
                                color: subtextColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'no_comments_yet'.tr(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'be_first_to_comment'.tr(),
                                style: TextStyle(fontSize: 15, color: subtextColor),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshComments,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 0, bottom: 16),
                          itemCount: _comments.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: dividerColor, indent: 56),
                          itemBuilder: (context, index) {
                            if (index == _comments.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            final comment = _comments[index];
                            return _buildCommentItem(
                              comment,
                              textColor,
                              subtextColor,
                            );
                          },
                        ),
                      ),
              ),
              
              // Comment input
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(top: BorderSide(color: dividerColor)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Avatar
                        _buildCurrentUserAvatar(authProvider, isDark, subtextColor),
                        const SizedBox(width: 12),
                        // Input field
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: TextField(
                              controller: _commentController,
                              focusNode: _focusNode,
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(color: textColor, fontSize: 15),
                              onChanged: (value) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'add_comment'.tr(),
                                hintStyle: TextStyle(color: subtextColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Send button
                        IconButton(
                          onPressed:
                              _commentController.text.trim().isEmpty ||
                                  _isSubmitting
                              ? null
                              : _submitComment,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          color: const Color(0xFF1DB954),
                          disabledColor: subtextColor,
                        ),
                      ],
                    ),
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
  ) {
    final user = comment['user'];
    final author = comment['author'];
    final isAuthor = author != null;
    
    final username = isAuthor
        ? (author['pseudo'] ?? author['email']?.split('@')[0] ?? 'Creator')
        : (user?['username'] ?? user?['email']?.split('@')[0] ?? 'User');
    
    final avatar = isAuthor ? author['avatar'] : user?['avatar'];
    final commentText = comment['comment_text'] ?? '';
    final createdAt = comment['created_at'];
    final isEdited = comment['is_edited'] == true;

    final timeAgo = createdAt != null
        ? _formatTimeAgo(DateTime.parse(createdAt.toString()))
        : '';

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
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
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Comment content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username and time
                  Row(
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('·', style: TextStyle(color: subtextColor)),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(fontSize: 15, color: subtextColor),
                      ),
                      if (isEdited) ...[
                        const SizedBox(width: 4),
                        Text('·', style: TextStyle(color: subtextColor)),
                        const SizedBox(width: 4),
                        Text(
                          'edited'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: subtextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Comment text
                  Text(
                    commentText,
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                      height: 1.4,
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 30) {
      return DateFormat('d MMM').format(dateTime);
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
