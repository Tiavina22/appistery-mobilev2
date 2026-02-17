import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LazyImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? shimmerBaseColor;
  final Color? shimmerHighlightColor;

  const LazyImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = shimmerBaseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final highlightColor = shimmerHighlightColor ?? (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            // Image loaded - fade in
            return AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: child,
            );
          }

          // Loading - show shimmer
          return Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: width,
              height: height,
              color: baseColor,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Error - show placeholder
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              borderRadius: borderRadius,
            ),
            child: Icon(
              Icons.broken_image_outlined,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              size: 40,
            ),
          );
        },
      ),
    );
  }
}

class LazyCircleAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final Color? backgroundColor;

  const LazyCircleAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: child,
              );
            }

            return Shimmer.fromColors(
              baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person,
              size: radius,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            );
          },
        ),
      ),
    );
  }
}
