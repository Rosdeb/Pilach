import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Stateless avatar with single image loading, Messenger-style composite group avatar,
/// Cupertino icon fallback, and online indicator.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    this.imageUrl,
    this.memberAvatars = const [],
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
  final List<String> memberAvatars;
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

    // 1. Single fallback widget (used for individual avatars or fallback group icon)
    Widget buildFallbackIcon() => Container(
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

    // 2. Determine avatar display mode
    final trimmedImg = imageUrl?.trim() ?? '';
    final hasDedicatedImage = trimmedImg.isNotEmpty &&
        !trimmedImg.startsWith('MEMBERS_AVATARS:') &&
        !trimmedImg.contains('motor1.com') &&
        trimmedImg != 'assets/images/default.png';

    Widget avatarContent;

    if (isGroup && !hasDedicatedImage) {
      final validAvatars = memberAvatars
          .map((url) => url.trim())
          .where((url) =>
              url.isNotEmpty &&
              !url.contains('motor1.com') &&
              url != 'assets/images/default.png' &&
              url != 'null')
          .toList();

      if (validAvatars.length >= 2) {
        // Messenger style composite group avatar
        avatarContent = _buildMessengerGroupAvatar(
          validAvatars: validAvatars,
          size: size,
          borderWidth: (size * 0.04).clamp(1.5, 3.5),
          borderColor: borderColor,
          bgColor: effectiveBgColor,
          iconColor: effectiveIconColor,
        );
      } else {
        // Default Cupertino group picture
        avatarContent = buildFallbackIcon();
      }
    } else if (hasDedicatedImage) {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: effectiveBgColor,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: trimmedImg,
            fit: BoxFit.cover,
            width: size,
            height: size,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => buildFallbackIcon(),
            errorWidget: (_, _, _) => buildFallbackIcon(),
          ),
        ),
      );
    } else {
      avatarContent = buildFallbackIcon();
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarContent,
          if (isOnline && !isGroup)
            Positioned(
              bottom: 1,
              right: 1,
              child: _OnlineDot(color: onlineColor, borderColor: borderColor),
            ),
        ],
      ),
    );
  }

  /// Builds a Facebook Messenger / iOS style overlapping circular composite avatar
  /// for 2 or 3+ group members.
  Widget _buildMessengerGroupAvatar({
    required List<String> validAvatars,
    required double size,
    required double borderWidth,
    required Color borderColor,
    required Color bgColor,
    required Color iconColor,
  }) {
    if (validAvatars.length == 2) {
      final childSize = size * 0.65;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Top-right circle (first member)
            Positioned(
              top: 0,
              right: 0,
              child: _buildMiniAvatar(
                url: validAvatars[0],
                childSize: childSize,
                borderWidth: borderWidth,
                borderColor: borderColor,
                bgColor: bgColor,
                iconColor: iconColor,
              ),
            ),
            // Bottom-left circle (second member) overlapping with cutout border
            Positioned(
              bottom: 0,
              left: 0,
              child: _buildMiniAvatar(
                url: validAvatars[1],
                childSize: childSize,
                borderWidth: borderWidth,
                borderColor: borderColor,
                bgColor: bgColor,
                iconColor: iconColor,
              ),
            ),
          ],
        ),
      );
    } else {
      // 3 or more members
      final childSize = size * 0.52;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Top-center circle (first member)
            Positioned(
              top: 0,
              left: (size - childSize) / 2,
              child: _buildMiniAvatar(
                url: validAvatars[0],
                childSize: childSize,
                borderWidth: borderWidth,
                borderColor: borderColor,
                bgColor: bgColor,
                iconColor: iconColor,
              ),
            ),
            // Bottom-left circle (second member)
            Positioned(
              bottom: 0,
              left: 0,
              child: _buildMiniAvatar(
                url: validAvatars[1],
                childSize: childSize,
                borderWidth: borderWidth,
                borderColor: borderColor,
                bgColor: bgColor,
                iconColor: iconColor,
              ),
            ),
            // Bottom-right circle (third member)
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildMiniAvatar(
                url: validAvatars[2],
                childSize: childSize,
                borderWidth: borderWidth,
                borderColor: borderColor,
                bgColor: bgColor,
                iconColor: iconColor,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMiniAvatar({
    required String url,
    required double childSize,
    required double borderWidth,
    required Color borderColor,
    required Color bgColor,
    required Color iconColor,
  }) {
    final innerContent = ClipOval(
      child: CachedNetworkImage(
        imageUrl: url.trim(),
        fit: BoxFit.cover,
        width: childSize,
        height: childSize,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) => Container(
          color: bgColor,
          alignment: Alignment.center,
          child: Icon(
            CupertinoIcons.person_fill,
            color: iconColor,
            size: childSize * 0.55,
          ),
        ),
        errorWidget: (_, _, _) => Container(
          color: bgColor,
          alignment: Alignment.center,
          child: Icon(
            CupertinoIcons.person_fill,
            color: iconColor,
            size: childSize * 0.55,
          ),
        ),
      ),
    );

    return Container(
      width: childSize,
      height: childSize,
      decoration: BoxDecoration(
        color: borderColor,
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: innerContent,
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
