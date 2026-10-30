import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app/components/AppText/appText.dart';
import 'package:app/core/constants/app_paths.dart';
import 'package:app/core/utils/app_toast.dart';
import 'package:app/Features/Me/data/models/device_session_model.dart';
import 'package:app/Features/Me/presentation/providers/device_session_provider.dart';

class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleLinkNewDevice() {
    final isMaxReached = ref.read(isMaxDevicesReachedProvider);
    if (isMaxReached) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Device Limit Reached'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'You can link a maximum of 5 devices to this account. Please terminate an existing session before linking a new device.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      return;
    }
    context.push(AppPaths.qr_screen);
  }

  void _showTerminateAllDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Terminate All Other Sessions?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            'You will be logged out of all other devices including other phones, tablets, and desktop apps. Only this current device will stay active.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Terminate All'),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(deviceSessionsProvider.notifier)
                  .terminateAllOtherSessions();
              AppToast.show(
                context,
                'All other sessions terminated successfully',
                type: ToastType.success,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTerminateSingleDialog(DeviceSessionModel session) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Terminate ${session.deviceName}?'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'This session will be logged out immediately. Location: ${session.location}.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Terminate'),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(deviceSessionsProvider.notifier)
                  .terminateSession(session.id);
              AppToast.show(
                context,
                'Session terminated for ${session.deviceName}',
                type: ToastType.success,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSessionDetailsSheet(DeviceSessionModel session) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pill indicator
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(
                    _getDeviceIcon(session.platformType),
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              session.deviceName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (session.isCurrentDevice) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF34C759,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'THIS DEVICE',
                                style: TextStyle(
                                  color: Color(0xFF34C759),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.clientName,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Metadata card
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    context,
                    label: 'Status',
                    value: session.lastActive,
                    isHighlight: session.isCurrentDevice,
                  ),
                  _buildDetailDivider(theme),
                  _buildDetailRow(
                    context,
                    label: 'Application',
                    value: session.appVersion,
                  ),
                  _buildDetailDivider(theme),
                  _buildDetailRow(
                    context,
                    label: 'Operating System',
                    value: session.osVersion,
                  ),
                  _buildDetailDivider(theme),
                  _buildDetailRow(
                    context,
                    label: 'IP Address',
                    value: session.ipAddress,
                    trailingWidget: GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: session.ipAddress),
                        );
                        AppToast.show(
                          context,
                          'IP Address copied',
                          type: ToastType.success,
                        );
                      },
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  _buildDetailDivider(theme),
                  _buildDetailRow(
                    context,
                    label: 'Location',
                    value: session.location,
                  ),
                  _buildDetailDivider(theme),
                  _buildDetailRow(
                    context,
                    label: 'Signed In',
                    value: session.loginDate,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Terminate action button
            if (!session.isCurrentDevice) ...[
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _showTerminateSingleDialog(session);
                  },
                  child: const Text(
                    'Terminate This Session',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isHighlight = false,
    Widget? trailingWidget,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isHighlight
                      ? const Color(0xFF34C759)
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 8),
                trailingWidget,
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: theme.dividerColor.withValues(alpha: 0.1),
    );
  }

  IconData _getDeviceIcon(DevicePlatformType type) {
    switch (type) {
      case DevicePlatformType.ios:
      case DevicePlatformType.android:
        return CupertinoIcons.device_phone_portrait;
      case DevicePlatformType.macos:
      case DevicePlatformType.windows:
      case DevicePlatformType.linux:
        return CupertinoIcons.device_laptop;
      case DevicePlatformType.tablet:
        return Icons.tablet_mac_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentDevice = ref.watch(currentDeviceSessionProvider);
    final otherDevices = ref.watch(filteredOtherDeviceSessionsProvider);
    final totalOtherCount = ref.watch(deviceSessionsProvider).where((s) => !s.isCurrentDevice).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- GLASS EFFECT APP BAR ---
          SliverAppBar(
            pinned: true,
            expandedHeight: 60.0,
            toolbarHeight: 60.0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: theme.colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
            title: AppText(
              'Devices & Sessions',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Link Desktop App',
                icon: Icon(
                  Icons.qr_code_scanner,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                onPressed: _handleLinkNewDevice,
              ),
            ],
          ),

          // --- BODY CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // --- HERO / INFO CARD ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(
                            CupertinoIcons.device_laptop,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Multi-Device Management',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (ref.watch(deviceSessionsProvider).length >= 5
                                              ? const Color(0xFFFF9500)
                                              : const Color(0xFF34C759))
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${ref.watch(deviceSessionsProvider).length}/5 MAX',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: ref.watch(deviceSessionsProvider).length >= 5
                                            ? const Color(0xFFFF9500)
                                            : const Color(0xFF34C759),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You can link up to 5 app devices (phones, tablets, and desktop apps) with your account. If you spot an unfamiliar login, terminate it immediately.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _handleLinkNewDevice,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (ref.watch(isMaxDevicesReachedProvider)
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.primary)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        ref.watch(isMaxDevicesReachedProvider)
                                            ? Icons.lock_outline_rounded
                                            : Icons.qr_code,
                                        size: 16,
                                        color: ref.watch(isMaxDevicesReachedProvider)
                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                            : theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        ref.watch(isMaxDevicesReachedProvider)
                                            ? 'Device Limit Reached (5/5 Max)'
                                            : 'Link Desktop App',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: ref.watch(isMaxDevicesReachedProvider)
                                              ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SECTION: THIS DEVICE ---
                  _buildSectionHeader(context, 'THIS DEVICE'),
                  if (currentDevice != null) ...[
                    Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showSessionDetailsSheet(currentDevice),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(
                                      0xFF34C759,
                                    ).withValues(alpha: 0.15),
                                    child: Icon(
                                      _getDeviceIcon(
                                        currentDevice.platformType,
                                      ),
                                      color: const Color(0xFF34C759),
                                      size: 24,
                                    ),
                                  ),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34C759),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            currentDevice.deviceName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF34C759,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'ONLINE',
                                            style: TextStyle(
                                              color: Color(0xFF34C759),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currentDevice.clientName} • ${currentDevice.osVersion}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currentDevice.location} • ${currentDevice.ipAddress}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // --- TERMINATE ALL OTHER SESSIONS BUTTON ---
                  if (totalOtherCount > 0) ...[
                    Material(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _showTerminateAllDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                CupertinoIcons.clear_circled_solid,
                                color: Color(0xFFFF3B30),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Terminate All Other Sessions',
                                style: TextStyle(
                                  color: Color(0xFFFF3B30),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- SECTION: OTHER ACTIVE SESSIONS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(context, 'ACTIVE SESSIONS'),
                      if (totalOtherCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '$totalOtherCount devices',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // --- SEARCH BAR IF >= 2 OTHER SESSIONS ---
                  if (totalOtherCount >= 2) ...[
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.search,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                ref
                                    .read(
                                      deviceSessionSearchQueryProvider.notifier,
                                    )
                                    .state = val;
                              },
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.transparent,
                                hintText: 'Search by device, OS, or location...',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                ref
                                  .read(
                                  deviceSessionSearchQueryProvider.notifier,
                                    )
                                    .state = '';
                              },
                              child: Icon(
                                CupertinoIcons.clear_circled_solid,
                                size: 16,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // --- LIST OF OTHER SESSIONS ---
                  if (otherDevices.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 36,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.shield_lefthalf_fill,
                            size: 44,
                            color: const Color(
                              0xFF34C759,
                            ).withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            totalOtherCount == 0
                                ? 'No Other Active Sessions'
                                : 'No Matching Sessions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalOtherCount == 0
                                ? 'Your account is only logged in on this device. All sessions are secure.'
                                : 'Try searching for another device name, operating system, or location.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          if (totalOtherCount == 0) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () {
                                ref
                                    .read(deviceSessionsProvider.notifier)
                                    .resetToDefaults();
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset Demo Sessions'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (int i = 0; i < otherDevices.length; i++) ...[
                            _buildSessionRow(context, otherDevices[i]),
                            if (i < otherDevices.length - 1)
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 64,
                                endIndent: 16,
                                color: theme.dividerColor.withValues(alpha: 0.1),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionRow(BuildContext context, DeviceSessionModel session) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showSessionDetailsSheet(session),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.1,
              ),
              child: Icon(
                _getDeviceIcon(session.platformType),
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.deviceName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.location} • ${session.lastActive}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.clientName} • ${session.ipAddress}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Terminate Session',
              icon: const Icon(
                CupertinoIcons.clear_circled,
                color: Color(0xFFFF3B30),
                size: 20,
              ),
              onPressed: () => _showTerminateSingleDialog(session),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
