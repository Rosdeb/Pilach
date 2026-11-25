import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';
import 'package:app/components/FloatingErrorBar/floatingbar.dart';
import 'package:app/core/services/location_service.dart';
import 'package:app/core/utils/app_toast.dart';
import 'inbox_providers.dart';

class AttachmentDrawerOverlay extends ConsumerWidget {
  const AttachmentDrawerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(showAttachmentMenuProvider);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: show ? 0 : -260,
      child: const AttachmentDrawer(),
    );
  }
}

class AttachmentDrawerSection extends ConsumerWidget {
  const AttachmentDrawerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(showAttachmentMenuProvider);
    if (!show) return const SizedBox.shrink();
    return const AttachmentDrawer();
  }
}

class AttachmentDrawer extends ConsumerWidget {
  const AttachmentDrawer({super.key});

  Future<void> _pickAndSendImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file != null) {
        ref.read(showAttachmentMenuProvider.notifier).state = false;
        final chatId = ref.read(currentChatIdProvider);
        if (chatId != null) {
          await ref
              .read(directChatProvider.notifier)
              .sendImageAttachment(file.path);
        }
      }
    } catch (e) {
      debugPrint('Failed to pick image: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 250,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          AttachmentIcon(
            icon: Icons.insert_drive_file,
            color: Colors.indigo,
            label: 'Document',
            onTap: () => _pickAndSendDocument(context, ref),
          ),
          AttachmentIcon(
            icon: Icons.camera_alt,
            color: Colors.pink,
            label: 'Camera',
            onTap: () => _pickAndSendImage(context, ref, ImageSource.camera),
          ),
          AttachmentIcon(
            icon: Icons.image,
            color: Colors.purple,
            label: 'Gallery',
            onTap: () => _pickAndSendImage(context, ref, ImageSource.gallery),
          ),
          const AttachmentIcon(
            icon: Icons.headset,
            color: Colors.orange,
            label: 'Audio',
          ),
          AttachmentIcon(
            icon: Icons.location_on,
            color: Colors.green,
            label: 'Location',
            onTap: () => _pickAndSendLocation(context, ref),
          ),
          const AttachmentIcon(
            icon: Icons.person,
            color: Colors.blue,
            label: 'Contact',
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendLocation(BuildContext context, WidgetRef ref) async {
    ref.read(showAttachmentMenuProvider.notifier).state = false;
    final chatId = ref.read(currentChatIdProvider);
    debugPrint('[AttachmentDrawer] _pickAndSendLocation tapped for chatId: $chatId');
    if (chatId == null) {
      debugPrint('[AttachmentDrawer] currentChatIdProvider is null, cannot send message');
      return;
    }

    AppToast.show(context, '📍 Acquiring GPS & generating map link...');

    final result = await LocationService.instance.getCurrentLocation();
    if (!context.mounted) return;

    if (result.isSuccess && result.messageText != null) {
      debugPrint('[AttachmentDrawer] Location acquired: ${result.coordinates}, link: ${result.mapUrl}');
      await ref
          .read(directChatProvider.notifier)
          .sendMessage(result.messageText!);
      debugPrint('[AttachmentDrawer] Location message sent successfully');
    } else {
      debugPrint('[AttachmentDrawer] Failed to acquire location: ${result.errorMessage}');
      FloatingErrorBar.show(
        context,
        message: result.errorMessage ?? 'Could not determine location.',
      );
    }
  }

  Future<void> _pickAndSendDocument(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          ref.read(showAttachmentMenuProvider.notifier).state = false;
          final chatId = ref.read(currentChatIdProvider);
          if (chatId != null) {
            await ref
                .read(directChatProvider.notifier)
                .sendFileAttachment(path);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to pick document: $e');
    }
  }
}

class AttachmentIcon extends StatelessWidget {
  const AttachmentIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
