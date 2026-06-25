import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RadarScanner extends StatefulWidget {
  final bool isScanning;
  final VoidCallback onTap;

  const RadarScanner({
    super.key,
    required this.isScanning,
    required this.onTap,
  });

  @override
  State<RadarScanner> createState() => _RadarScannerState();
}

class _RadarScannerState extends State<RadarScanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    if (widget.isScanning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RadarScanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isScanning) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 260,
          height: 260,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  _wave(theme, 0),
                  _wave(theme, 0.33),
                  _wave(theme, 0.66),

                  _buildCenterButton(theme),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _wave(ThemeData theme, double delay) {
    double progress = (_controller.value + delay) % 1;

    return Transform.scale(
      scale: progress,
      child: Opacity(
        opacity: (1 - progress).clamp(0, 1),
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(ThemeData theme) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(.4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Icon(
        widget.isScanning
            ? CupertinoIcons.arrow_2_circlepath
            : CupertinoIcons.add,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }
}