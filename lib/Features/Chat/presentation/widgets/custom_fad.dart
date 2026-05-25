import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:messageapp/core/utils/app_colour.dart';

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
      return _buildIOSButton();
    }
    return _buildAndroidButton();
  }

  // ── iOS: native spring scale + opacity press feel ─────────────────────────
  Widget _buildIOSButton() {
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
            // iOS: frosted glass tint instead of flat green
            backgroundColor: AppColors.successGreen.withOpacity(0.92),
            iconColor: Colors.white,
            withBlur: true,
          ),
        ),
      ),
    );
  }

  // ── Android: Material ink ripple ─────────────────────────────────────────
  Widget _buildAndroidButton() {
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
          color: AppColors.successGreen,
          child: InkWell(
            onTap: widget.onPressed,
            customBorder: const CircleBorder(),
            child: _buildFabBody(
              backgroundColor: AppColors.successGreen,
              iconColor: const Color(0xFF1C1B1F),
              withBlur: false,
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared visual body ────────────────────────────────────────────────────
  Widget _buildFabBody({
    required Color backgroundColor,
    required Color iconColor,
    required bool withBlur,
  }) {
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
            color: AppColors.successGreen.withOpacity(0.35),
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