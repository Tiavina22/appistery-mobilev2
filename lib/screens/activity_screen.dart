import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';

import '../services/feed_service.dart';
import '../services/reaction_service.dart';
import '../services/story_service.dart';
import '../widgets/lazy_image.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/reaction_list_bottom_sheet.dart';
import 'story_detail_screen.dart';
import 'author_profile_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final FeedService _feedService = FeedService();
  final ReactionService _reactionService = ReactionService();
  final StoryService _storyService = StoryService();
  final ScrollController _scrollController = ScrollController();

  List<FeedItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  // Local reaction state overrides (for instant UI feedback)
  final Map<int, String?> _localReactions = {};
  final Map<int, int> _localReactionTotals = {};

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _feedService.getFeed(page: 1, limit: 10);
      final items = result['items'] as List<FeedItem>;
      final pagination = result['pagination'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _items = items;
          _page = 1;
          _hasMore = pagination != null &&
              (pagination['page'] as int) < (pagination['pages'] as int);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _feedService.getFeed(page: _page + 1, limit: 10);
      final items = result['items'] as List<FeedItem>;
      final pagination = result['pagination'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _items.addAll(items);
          _page += 1;
          _hasMore = pagination != null &&
              (pagination['page'] as int) < (pagination['pages'] as int);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _toggleReaction(FeedItem item, String reactionType) async {
    final currentReaction = _localReactions.containsKey(item.id)
        ? _localReactions[item.id]
        : item.reactions.userReaction;
    final currentTotal = _localReactionTotals.containsKey(item.id)
        ? _localReactionTotals[item.id]!
        : item.reactions.total;

    // Optimistic update
    setState(() {
      if (currentReaction == reactionType) {
        // Remove reaction
        _localReactions[item.id] = null;
        _localReactionTotals[item.id] = currentTotal - 1;
      } else if (currentReaction != null) {
        // Change reaction type (total stays the same)
        _localReactions[item.id] = reactionType;
        _localReactionTotals[item.id] = currentTotal;
      } else {
        // Add new reaction
        _localReactions[item.id] = reactionType;
        _localReactionTotals[item.id] = currentTotal + 1;
      }
    });

    try {
      await _reactionService.toggleReaction(item.id, reactionType: reactionType);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _localReactions.remove(item.id);
          _localReactionTotals.remove(item.id);
        });
      }
    }
  }

  void _showReactionPicker(FeedItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _reactionPickerItem('👍', 'like', item),
              _reactionPickerItem('❤️', 'love', item),
              _reactionPickerItem('😂', 'haha', item),
              _reactionPickerItem('😮', 'wow', item),
              _reactionPickerItem('😢', 'sad', item),
              _reactionPickerItem('😡', 'angry', item),
            ],
          ),
        );
      },
    );
  }

  Widget _reactionPickerItem(String emoji, String type, FeedItem item) {
    final current = _localReactions.containsKey(item.id)
        ? _localReactions[item.id]
        : item.reactions.userReaction;
    final isSelected = current == type;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _toggleReaction(item, type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1DB954).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          emoji,
          style: TextStyle(fontSize: isSelected ? 32 : 28),
        ),
      ),
    );
  }

  void _showComments(FeedItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return CommentsBottomSheet(
              storyId: item.id,
              storyTitle: item.title,
            );
          },
        );
      },
    );
  }

  void _showReactionsList(FeedItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return ReactionListBottomSheet(
              storyId: item.id,
              initialCounts: item.reactions.counts,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildShimmerFeed();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: const Color(0xFF1DB954),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1DB954),
                  ),
                ),
              ),
            );
          }
          return _buildFeedCard(_items[index]);
        },
      ),
    );
  }

  // ─── Feed Card (Facebook-style) ────────────────────────────────────

  Widget _buildFeedCard(FeedItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Author avatar + name + time + genre
          _buildCardHeader(item, isDark),

          // Synopsis preview
          if (item.synopsis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                item.synopsis,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Cover image (tap to open story)
          _buildCoverImage(item, isDark),

          // Story title overlay bar
          _buildTitleBar(item, isDark),

          // Reaction summary + comment count
          _buildReactionSummary(item, isDark, dividerColor),

          // Divider
          Container(height: 0.5, color: dividerColor),

          // Action buttons row
          _buildActionButtons(item, isDark),
        ],
      ),
    );
  }

  Widget _buildCardHeader(FeedItem item, bool isDark) {
    final timeAgo = _formatTimeAgo(item.createdAt);

    return GestureDetector(
      onTap: () {
        if (item.author != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AuthorProfileScreen(
                authorId: item.author!.id,
                authorName: item.author!.pseudo,
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            // Author avatar
            _buildAuthorAvatar(item.author, isDark),
            const SizedBox(width: 10),

            // Author name + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.author?.pseudo ?? 'Inconnu',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isPremium) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Premium',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1DB954),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      if (item.genre != null) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                        Text(
                          item.genre!.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF1DB954).withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // More options
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                size: 20,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              onPressed: () => _onStoryTap(item),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorAvatar(FeedAuthor? author, bool isDark) {
    final avatarData = author?.avatar;
    const double size = 42;

    if (avatarData == null || avatarData.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
        child: const Center(
          child: Icon(
            Icons.person_rounded,
            color: Color(0xFF1DB954),
            size: 22,
          ),
        ),
      );
    }

    // Relative URL (/uploads/...)
    if (avatarData.startsWith('/uploads/')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
        child: ClipOval(
          child: LazyImage(
            imageUrl: '$apiUrl$avatarData',
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        ),
      );
    }

    // Full URL
    if (avatarData.startsWith('http')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
        child: ClipOval(
          child: LazyImage(
            imageUrl: avatarData,
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        ),
      );
    }

    // Base64
    try {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          image: DecorationImage(
            image: MemoryImage(base64Decode(avatarData)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (_) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
        child: const Center(
          child: Icon(Icons.person_rounded, color: Color(0xFF1DB954), size: 22),
        ),
      );
    }
  }

  Widget _buildCoverImage(FeedItem item, bool isDark) {
    final cover = item.coverImage;
    if (cover == null || cover.isEmpty) {
      return GestureDetector(
        onTap: () => _onStoryTap(item),
        child: Container(
          height: 220,
          width: double.infinity,
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          child: Center(
            child: Icon(
              Icons.auto_stories_rounded,
              size: 48,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
        ),
      );
    }

    String imageUrl = cover;
    if (cover.startsWith('/uploads/')) {
      final apiUrl = dotenv.env['API_URL'] ?? 'https://mistery.pro';
      imageUrl = '$apiUrl$cover';
    }

    // For base64 covers
    if (!cover.startsWith('http') && !cover.startsWith('/uploads/')) {
      try {
        return GestureDetector(
          onTap: () => _onStoryTap(item),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            width: double.infinity,
            child: Image.memory(
              base64Decode(cover.contains(',') ? cover.split(',').last : cover),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _buildPlaceholderCover(isDark),
            ),
          ),
        );
      } catch (_) {
        return GestureDetector(
          onTap: () => _onStoryTap(item),
          child: _buildPlaceholderCover(isDark),
        );
      }
    }

    return GestureDetector(
      onTap: () => _onStoryTap(item),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        width: double.infinity,
        child: LazyImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover(bool isDark) {
    return Container(
      height: 220,
      width: double.infinity,
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 48,
          color: isDark ? Colors.grey[700] : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildTitleBar(FeedItem item, bool isDark) {
    return GestureDetector(
      onTap: () => _onStoryTap(item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${item.chaptersCount}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
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

  Widget _buildReactionSummary(
      FeedItem item, bool isDark, Color dividerColor) {
    final totalReactions = _localReactionTotals.containsKey(item.id)
        ? _localReactionTotals[item.id]!
        : item.reactions.total;
    final commentCount = item.commentCount;

    if (totalReactions == 0 && commentCount == 0) {
      return const SizedBox(height: 4);
    }

    // Top 3 reaction emojis
    final topEmojis = _getTopReactionEmojis(item);

    // Build "Username and X others" text
    String reactionText = '';
    if (totalReactions > 0) {
      final reactors = item.reactions.recentReactors;
      if (reactors.isNotEmpty) {
        final firstName = reactors.first.username;
        final othersCount = totalReactions - 1;
        if (othersCount <= 0) {
          reactionText = firstName;
        } else if (othersCount == 1) {
          reactionText = '$firstName ${'activity_and_one_other'.tr()}';
        } else {
          reactionText =
              '$firstName ${'activity_and_others'.tr(namedArgs: {'count': _formatCount(othersCount)})}';
        }
      } else {
        reactionText = _formatCount(totalReactions);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          if (totalReactions > 0)
            Flexible(
              child: GestureDetector(
                onTap: () => _showReactionsList(item),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji icons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: topEmojis
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child:
                                    Text(e, style: const TextStyle(fontSize: 16)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        reactionText,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          if (commentCount > 0)
            GestureDetector(
              onTap: () => _showComments(item),
              child: Text(
                '$commentCount ${'comments'.tr()}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(FeedItem item, bool isDark) {
    final userReaction = _localReactions.containsKey(item.id)
        ? _localReactions[item.id]
        : item.reactions.userReaction;

    final reactionEmoji = _reactionTypeToEmoji(userReaction);
    final reactionLabel = _reactionTypeToLabel(userReaction);
    final isReacted = userReaction != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          // Like / React button
          Expanded(
            child: _buildActionButton(
              icon: isReacted
                  ? null
                  : Icon(
                      Icons.thumb_up_off_alt_outlined,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
              emoji: isReacted ? reactionEmoji : null,
              label: reactionLabel ?? 'like_button'.tr(),
              labelColor: isReacted
                  ? const Color(0xFF1DB954)
                  : (isDark ? Colors.white54 : Colors.black54),
              onTap: () => _toggleReaction(item, userReaction ?? 'like'),
              onLongPress: () => _showReactionPicker(item),
            ),
          ),

          // Comment button
          Expanded(
            child: _buildActionButton(
              icon: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              label: 'comments'.tr(),
              labelColor: isDark ? Colors.white54 : Colors.black54,
              onTap: () => _showComments(item),
            ),
          ),

          // Read button
          Expanded(
            child: _buildActionButton(
              icon: Icon(
                Icons.auto_stories_outlined,
                size: 20,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              label: 'read_now'.tr(),
              labelColor: isDark ? Colors.white54 : Colors.black54,
              onTap: () => _onStoryTap(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    Widget? icon,
    String? emoji,
    required String label,
    required Color labelColor,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji != null)
              Text(emoji, style: const TextStyle(fontSize: 18)),
            if (icon != null) icon,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  void _onStoryTap(FeedItem item) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1DB954)),
        ),
      );

      final story = await _storyService.getStoryById(item.id);

      if (mounted) {
        Navigator.pop(context); // dismiss loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryDetailScreen(story: story),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error'.tr())),
        );
      }
    }
  }

  List<String> _getTopReactionEmojis(FeedItem item) {
    final counts = Map<String, int>.from(item.reactions.counts);
    if (counts.isEmpty) return ['👍'];

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(3)
        .map((e) => _reactionTypeToEmoji(e.key) ?? '👍')
        .toList();
  }

  String? _reactionTypeToEmoji(String? type) {
    switch (type) {
      case 'like':
        return '👍';
      case 'love':
        return '❤️';
      case 'haha':
        return '😂';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'angry':
        return '😡';
      default:
        return null;
    }
  }

  String? _reactionTypeToLabel(String? type) {
    switch (type) {
      case 'like':
        return 'like_button'.tr();
      case 'love':
        return 'activity_love'.tr();
      case 'haha':
        return 'activity_haha'.tr();
      case 'wow':
        return 'activity_wow'.tr();
      case 'sad':
        return 'activity_sad'.tr();
      case 'angry':
        return 'activity_angry'.tr();
      default:
        return null;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo';
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'activity_just_now'.tr();
  }

  // ─── Shimmer / Error / Empty states ────────────────────────────────

  Widget _buildShimmerFeed() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header shimmer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: baseColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Synopsis shimmer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Cover shimmer
                Container(
                  height: 220,
                  width: double.infinity,
                  color: baseColor,
                ),
                // Title shimmer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Container(
                    width: 200,
                    height: 16,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Actions shimmer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      3,
                      (_) => Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
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

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'error'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'activity_load_error'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('retry'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1DB954),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dynamic_feed_rounded,
              size: 56,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'activity_empty'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'activity_empty_desc'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
