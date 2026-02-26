import 'package:flutter/material.dart';

class ReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;
  final String? currentReaction;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.currentReaction,
  });

  static const Map<String, String> reactions = {
    'like': '❤️',
    'love': '😍',
    'haha': '😂',
    'wow': '😮',
    'sad': '😢',
    'angry': '😠',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.entries.map((entry) {
          final isSelected = currentReaction == entry.key;
          return GestureDetector(
            onTap: () => onReactionSelected(entry.key),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 1.0,
                  end: isSelected ? 1.3 : 1.0,
                ),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFC3C44).withOpacity(0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static void show(
    BuildContext context, {
    required Function(String) onReactionSelected,
    String? currentReaction,
    required Offset position,
  }) {
    final overlay = Overlay.of(context);
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent background to detect taps outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                overlayEntry?.remove();
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Reaction picker
          Positioned(
            left: position.dx.clamp(
              10.0,
              MediaQuery.of(context).size.width - 280,
            ),
            top: position.dy - 60,
            child: Material(
              color: Colors.transparent,
              child: ReactionPicker(
                currentReaction: currentReaction,
                onReactionSelected: (reactionType) {
                  onReactionSelected(reactionType);
                  overlayEntry?.remove();
                },
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);
  }

  static String getReactionEmoji(String? reactionType) {
    return reactions[reactionType] ?? reactions['like']!;
  }

  static String getReactionLabel(String reactionType) {
    final labels = {
      'like': 'J\'aime',
      'love': 'J\'adore',
      'haha': 'Haha',
      'wow': 'Wow',
      'sad': 'Triste',
      'angry': 'Grrr',
    };
    return labels[reactionType] ?? 'J\'aime';
  }
}
