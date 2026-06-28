import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Stateless avatar with online indicator.
///
/// Wrapped in [RepaintBoundary] by the caller only once — not re-wrapped here,
/// so the caller controls layer budget.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.imageUrl,
    required this.cacheKey,
    required this.isOnline,
    required this.onlineColor,
    required this.borderColor,
  });

  final String imageUrl;
  final String cacheKey;
  final bool isOnline;
  final Color onlineColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                cacheKey: cacheKey, // stable — never changes per chat
                fit: BoxFit.cover,
                width: 48,
                height: 48,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) =>
                    const CupertinoActivityIndicator(radius: 10),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.person, size: 24),
              ),
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
