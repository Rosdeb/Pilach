import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GlassFab extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final double size;

  const GlassFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.size = 56,
  });

  @override
  State<GlassFab> createState() => _GlassFabState();
}

class _GlassFabState extends State<GlassFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIOSButton(context);
    }
    return _buildAndroidButton(context);
  }

  // ── iOS: native spring scale + opacity press feel ─────────────────────────
  Widget _buildIOSButton(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.75 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: _buildFabBody(
            context: context,
            // iOS: frosted glass tint instead of flat green
            backgroundColor: primaryColor.withOpacity(0.92),
            iconColor: theme.colorScheme.onPrimary,
            withBlur: true,
          ),
        ),
      ),
    );
  }

  // ── Android: Material ink ripple ─────────────────────────────────────────
  Widget _buildAndroidButton(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size / 2),
        child: Material(
          color: primaryColor,
          child: InkWell(
            onTap: widget.onPressed,
            customBorder: const CircleBorder(),
            child: _buildFabBody(
              context: context,
              backgroundColor: primaryColor,
              iconColor: theme.colorScheme.onPrimary,
              withBlur: false,
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared visual body ────────────────────────────────────────────────────
  Widget _buildFabBody({
    required BuildContext context,
    required Color backgroundColor,
    required Color iconColor,
    required bool withBlur,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final circle = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(
          color: Colors.white.withOpacity(0.25), // subtle rim for glass effect
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          widget.icon,
          color: iconColor,
          size: 26,
        ),
      ),
    );

    if (!withBlur) return circle;

    // iOS only: BackdropFilter gives the frosted glass look
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: circle,
      ),
    );
  }
}