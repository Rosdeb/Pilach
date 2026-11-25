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
    final chatId = ref.read(currentChatIdProvider);
    final chatNotifier = ref.read(directChatProvider.notifier);
    final menuNotifier = ref.read(showAttachmentMenuProvider.notifier);

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file != null) {
        menuNotifier.state = false;
        if (chatId != null) {
          await chatNotifier.sendImageAttachment(file.path);
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
    final chatId = ref.read(currentChatIdProvider);
    final menuNotifier = ref.read(showAttachmentMenuProvider.notifier);

    debugPrint('[AttachmentDrawer] _pickAndSendLocation tapped for chatId: $chatId');
    if (chatId == null) {
      debugPrint('[AttachmentDrawer] currentChatIdProvider is null, cannot send message');
      return;
    }

    final chatNotifier = ref.read(directChatProvider.notifier);
    AppToast.show(context, '📍 Acquiring GPS & generating map link...');
    menuNotifier.state = false;

    try {
      final result = await LocationService.instance.getCurrentLocation();
      debugPrint('[AttachmentDrawer] LocationService result: isSuccess=${result.isSuccess}, coordinates=${result.coordinates}, mapUrl=${result.mapUrl}');

      if (result.isSuccess && result.messageText != null) {
        debugPrint('[AttachmentDrawer] Sending location message to chatId: $chatId -> "${result.messageText}"');
        await chatNotifier.sendMessage(result.messageText!);
        debugPrint('[AttachmentDrawer] Location message sent successfully');
      } else {
        debugPrint('[AttachmentDrawer] Failed to acquire location: ${result.errorMessage}');
        if (context.mounted) {
          FloatingErrorBar.show(
            context,
            message: result.errorMessage ?? 'Could not determine location.',
          );
        }
      }
    } catch (e, stack) {
      debugPrint('[AttachmentDrawer] Unexpected error in _pickAndSendLocation: $e\n$stack');
      if (context.mounted) {
        FloatingErrorBar.show(
          context,
          message: 'Failed to share location: $e',
        );
      }
    }
  }

  Future<void> _pickAndSendDocument(BuildContext context, WidgetRef ref) async {
    final chatId = ref.read(currentChatIdProvider);
    final chatNotifier = ref.read(directChatProvider.notifier);
    final menuNotifier = ref.read(showAttachmentMenuProvider.notifier);

    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          menuNotifier.state = false;
          if (chatId != null) {
            await chatNotifier.sendFileAttachment(path);
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
