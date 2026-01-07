import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/reaction_service.dart';
import '../providers/theme_provider.dart';

class StoryCommentsScreen extends StatefulWidget {
  final int storyId;
  final String storyTitle;

  const StoryCommentsScreen({
    super.key,
    required this.storyId,
    required this.storyTitle,
  });

  @override
  State<StoryCommentsScreen> createState() => _StoryCommentsScreenState();
}

class _StoryCommentsScreenState extends State<StoryCommentsScreen> {
  final ReactionService _reactionService = ReactionService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      print('🔄 [CommentsScreen._loadComments] Chargement des commentaires...');
      setState(() => _isLoading = true);
      final data = await _reactionService.getStoryComments(widget.storyId);
      print('📦 [CommentsScreen._loadComments] Données reçues: $data');
      setState(() {
        _comments = data['comments'] ?? [];
        _isLoading = false;
      });
      print(
        '✅ [CommentsScreen._loadComments] ${_comments.length} commentaires chargés',
      );
    } catch (e) {
      print('❌ [CommentsScreen._loadComments] Erreur: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      setState(() => _isSubmitting = true);
      await _reactionService.addComment(widget.storyId, text);
      _commentController.clear();
      _focusNode.unfocus();
      await _loadComments();
      setState(() => _isSubmitting = false);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'comments'.tr(),
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: dividerColor),
        ),
      ),
      body: Column(
        children: [
          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
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
                    onRefresh: _loadComments,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 0),
                      itemCount: _comments.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: dividerColor, indent: 56),
                      itemBuilder: (context, index) {
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
              border: Border(top: BorderSide(color: dividerColor!)),
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
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[300],
                      child: Icon(Icons.person, size: 20, color: subtextColor),
                    ),
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
  }

  Widget _buildCommentItem(
    Map<String, dynamic> comment,
    Color textColor,
    Color? subtextColor,
  ) {
    final user = comment['user'];
    final username =
        user?['username'] ?? user?['email']?.split('@')[0] ?? 'User';
    final commentText = comment['comment_text'] ?? '';
    final createdAt = comment['created_at'];
    final isEdited = comment['is_edited'] == true;
    final avatar = user?['avatar'];

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
              backgroundImage: avatar != null && avatar.toString().isNotEmpty
                  ? MemoryImage(base64Decode(avatar.toString().split(',').last))
                  : null,
              child: avatar == null || avatar.toString().isEmpty
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
                          'modifié',
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
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'maintenant';
    }
  }
}
