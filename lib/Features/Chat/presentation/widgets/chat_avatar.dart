import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Stateless avatar with image loading, Cupertino icon fallback, and online indicator.
///
/// Displays [imageUrl] via [CachedNetworkImage] if present; otherwise falls back
/// to a native Cupertino icon (e.g. person or group) on a themed circular background.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    this.imageUrl,
    this.isGroup = false,
    this.icon,
    this.backgroundColor,
    this.iconColor,
    required this.isOnline,
    required this.onlineColor,
    required this.borderColor,
    this.radius = 24,
  });

  final String? imageUrl;
  final bool isGroup;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isOnline;
  final Color onlineColor;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = radius * 2;
    final isDark = theme.brightness == Brightness.dark;

    final IconData effectiveIcon = icon ??
        (isGroup ? CupertinoIcons.person_2_fill : CupertinoIcons.person_fill);

    final Color effectiveBgColor = backgroundColor ??
        (isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : theme.colorScheme.primary.withValues(alpha: 0.10));

    final Color effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    final hasValidImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    Widget buildFallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: effectiveBgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            effectiveIcon,
            color: effectiveIconColor,
            size: radius * 1.05,
          ),
        );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: effectiveBgColor,
            child: ClipOval(
              child: hasValidImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!.trim(),
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (_, _) => buildFallback(),
                      errorWidget: (_, _, _) => buildFallback(),
                    )
                  : buildFallback(),
            ),
          ),
          if (isOnline)
            Positioned(
              bottom: 1,
              right: 1,
              child: _OnlineDot(color: onlineColor, borderColor: borderColor),
            ),
        ],
      ),
    );
  }
}

/// Tiny stateless dot — extracted so const is reachable when color is fixed.
class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: const SizedBox(width: 12, height: 12),
    );
  }
}
