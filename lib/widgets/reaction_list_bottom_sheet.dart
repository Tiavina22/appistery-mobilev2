import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';

import '../services/reaction_service.dart';
import '../widgets/lazy_image.dart';

/// Bottom sheet that shows all users who reacted to a story,
/// with filter tabs by reaction type (like Facebook).
class ReactionListBottomSheet extends StatefulWidget {
  final int storyId;
  final Map<String, int> initialCounts;

  const ReactionListBottomSheet({
    super.key,
    required this.storyId,
    this.initialCounts = const {},
  });

  @override
  State<ReactionListBottomSheet> createState() =>
      _ReactionListBottomSheetState();
}

class _ReactionListBottomSheetState extends State<ReactionListBottomSheet> {
  final ReactionService _reactionService = ReactionService();

  String _selectedType = 'all';
  List<dynamic> _reactions = [];
  Map<String, int> _counts = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _counts = {'all': 0, ...widget.initialCounts};
    // Compute total for 'all'
    int total = 0;
    widget.initialCounts.forEach((_, v) => total += v);
    _counts['all'] = total;

    _loadReactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadReactions() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });

    try {
      final data = await _reactionService.getStoryReactionsList(
        widget.storyId,
        type: _selectedType,
        page: 1,
        limit: 30,
      );

      if (mounted) {
        setState(() {
          _reactions = data['reactions'] as List? ?? [];
          final serverCounts = data['counts'] as Map<String, dynamic>? ?? {};
          _counts = serverCounts
              .map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0));
          final pagination = data['pagination'] as Map<String, dynamic>?;
          _hasMore = pagination != null &&
              (pagination['page'] as int) < (pagination['pages'] as int);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final data = await _reactionService.getStoryReactionsList(
        widget.storyId,
        type: _selectedType,
        page: _page + 1,
        limit: 30,
      );

      if (mounted) {
        setState(() {
          _reactions.addAll(data['reactions'] as List? ?? []);
          _page += 1;
          final pagination = data['pagination'] as Map<String, dynamic>?;
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

  void _selectType(String type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    _loadReactions();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'reaction_list_title'.tr(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 22,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Reaction type filter tabs
          _buildFilterTabs(isDark),

          const SizedBox(height: 4),

          // Divider
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          ),

          // Reaction list
          Expanded(
            child: _isLoading
                ? _buildShimmerList(isDark)
                : _reactions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'reaction_list_empty'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount:
                            _reactions.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (ctx, index) {
                          if (index >= _reactions.length) {
                            return _buildShimmerTile(isDark);
                          }
                          return _buildReactionTile(
                              _reactions[index], isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    // Build ordered tabs: All, then each reaction type that has count > 0
    final tabs = <_FilterTab>[];

    // "All" tab
    tabs.add(_FilterTab(
      type: 'all',
      emoji: null,
      label: 'reaction_all'.tr(),
      count: _counts['all'] ?? 0,
    ));

    // Type tabs in order
    const orderedTypes = ['like', 'love', 'haha', 'wow', 'sad', 'angry'];
    const emojiMap = {
      'like': '👍',
      'love': '❤️',
      'haha': '😂',
      'wow': '😮',
      'sad': '😢',
      'angry': '😡',
    };

    for (final t in orderedTypes) {
      final c = _counts[t] ?? 0;
      if (c > 0) {
        tabs.add(_FilterTab(
          type: t,
          emoji: emojiMap[t],
          label: null,
          count: c,
        ));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedType == tab.type;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => _selectType(tab.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1DB954).withOpacity(0.15)
                      : (isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1DB954).withOpacity(0.4)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tab.emoji != null) ...[
                      Text(tab.emoji!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                    ],
                    if (tab.label != null)
                      Text(
                        tab.label!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? const Color(0xFF1DB954)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      '${tab.count}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF1DB954)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReactionTile(dynamic reaction, bool isDark) {
    final user = reaction['user'] as Map<String, dynamic>?;
    final reactionType = reaction['reaction_type'] as String? ?? 'like';
    final username = user?['username'] as String? ?? 'Utilisateur';
    final avatar = user?['avatar'] as String?;

    const emojiMap = {
      'like': '👍',
      'love': '❤️',
      'haha': '😂',
      'wow': '😮',
      'sad': '😢',
      'angry': '😡',
    };
    final emoji = emojiMap[reactionType] ?? '👍';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // User avatar with reaction badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildUserAvatar(avatar, username, isDark),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Username
          Expanded(
            child: Text(
              username,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(
      String? avatarData, String username, bool isDark) {
    const double size = 40;

    if (avatarData == null || avatarData.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
        child: Center(
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      );
    }

    // Relative URL
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
        child: Center(
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildShimmerList(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[300]!,
      highlightColor:
          isDark ? Colors.white.withOpacity(0.12) : Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder: (_, __) => _buildShimmerTileContent(),
      ),
    );
  }

  Widget _buildShimmerTile(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[300]!,
      highlightColor:
          isDark ? Colors.white.withOpacity(0.12) : Colors.grey[100]!,
      child: _buildShimmerTileContent(),
    );
  }

  Widget _buildShimmerTileContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Avatar placeholder
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Name placeholder
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab {
  final String type;
  final String? emoji;
  final String? label;
  final int count;

  _FilterTab({
    required this.type,
    this.emoji,
    this.label,
    required this.count,
  });
}
