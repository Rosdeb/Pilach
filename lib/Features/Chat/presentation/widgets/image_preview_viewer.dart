import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

/// Full-screen performance-optimized image viewer with pinch-to-zoom and hero animations
class FullScreenImageViewer extends StatefulWidget {
  final String imagePathOrUrl;
  final String? heroTag;
  final String? title;

  const FullScreenImageViewer({
    super.key,
    required this.imagePathOrUrl,
    this.heroTag,
    this.title,
  });

  static void open(BuildContext context, {required String imagePathOrUrl, String? heroTag, String? title}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.white54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: FullScreenImageViewer(
              imagePathOrUrl: imagePathOrUrl,
              heroTag: heroTag,
              title: title,
            ),
          );
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      // ignore: deprecated_member_use
      _transformationController.value = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        // ignore: deprecated_member_use
        ..scale(2.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocalFile = File(widget.imagePathOrUrl).existsSync();
    final String resolvedUrl = (widget.imagePathOrUrl.startsWith('http://') || widget.imagePathOrUrl.startsWith('https://'))
        ? widget.imagePathOrUrl
        : 'https://xdtunnel.icu/${widget.imagePathOrUrl}';

    Widget imageWidget;
    if (isLocalFile) {
      imageWidget = Image.file(
        File(widget.imagePathOrUrl),
        fit: BoxFit.contain,
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: resolvedUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
        ),
        errorWidget: (context, url, error) => const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.white70, size: 64),
            SizedBox(height: 12),
            Text('Failed to load image', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Zoom Viewer
            GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: imageWidget,
                ),
              ),
            ),

            // Top Bar Controls
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (widget.title != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.title!,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-send Image Preview Modal with Caption Input Box
class PreSendImagePreviewModal extends StatefulWidget {
  final String filePath;
  final Function(String caption) onSend;

  const PreSendImagePreviewModal({
    super.key,
    required this.filePath,
    required this.onSend,
  });

  static Future<void> show(BuildContext context, {required String filePath, required Function(String caption) onSend}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PreSendImagePreviewModal(
        filePath: filePath,
        onSend: onSend,
      ),
    );
  }

  @override
  State<PreSendImagePreviewModal> createState() => _PreSendImagePreviewModalState();
}

class _PreSendImagePreviewModalState extends State<PreSendImagePreviewModal> {
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'Preview Image',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 48), // Balancing
              ],
            ),
          ),

          // High-performance image preview container
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
              maxWidth: double.infinity,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(widget.filePath),
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Caption Input Bar & Send Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ZoomTapAnimation(
                  onTap: () {
                    final caption = _captionController.text.trim();
                    Navigator.of(context).pop();
                    widget.onSend(caption);
                  },
                  child: const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFF00A884),
                    child: Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
