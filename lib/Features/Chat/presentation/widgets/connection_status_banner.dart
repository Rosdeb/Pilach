import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_banner_provider.dart';

class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionBannerProvider);

    if (status == ConnectionBannerStatus.hidden) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final (label, textColor, bgColor, icon) = switch (status) {
      ConnectionBannerStatus.offline => (
        'No internet connection',
        Colors.white,
        const Color(0xFFEF4444),
        Icons.cloud_off_rounded,
      ),
      ConnectionBannerStatus.connecting => (
        'Connecting…',
        Colors.white,
        const Color(0xFFD97706),
        Icons.sync_rounded,
      ),
      ConnectionBannerStatus.reconnecting => (
        'Reconnecting…',
        Colors.white,
        const Color(0xFFD97706),
        Icons.sync_rounded,
      ),
      ConnectionBannerStatus.connected => (
        'Connected',
        Colors.white,
        const Color(0xFF10B981),
        Icons.check_circle_outline_rounded,
      ),
      ConnectionBannerStatus.hidden => (
        '',
        Colors.transparent,
        Colors.transparent,
        Icons.check,
      ),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        color: bgColor.withValues(alpha: 0.92),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
