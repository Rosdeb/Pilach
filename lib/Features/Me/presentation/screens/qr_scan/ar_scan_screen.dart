import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../../../components/AppText/appText.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/daos/chat_dao.dart';
import '../../../../../core/utils/app_colour.dart';
import '../../../../../core/utils/app_toast.dart';
import '../../providers/profile_provider.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../Chat/data/models/chat_model.dart';
import '../../../../Chat/presentation/providers/chat_provider.dart';
import '../../../../Chat/presentation/providers/direct_chat_provider.dart';

// userIdProvider removed in favor of reading directly from authProvider

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  QrImage? _cachedQrImage;
  String? _cachedQrData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    final initialId = _resolveCurrentUserId();
    if (initialId.isNotEmpty) {
      _getOrCreateQrImage(initialId);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_resolveCurrentUserId().isEmpty) {
          ref.read(profileNotifierProvider.notifier).fetchProfile();
        }
      });
    }
  }

  QrImage? _getOrCreateQrImage(String qrData) {
    if (qrData.isEmpty || qrData == '***' || qrData == 'unknown_user_id') {
      return null;
    }
    if (_cachedQrData == qrData && _cachedQrImage != null) {
      return _cachedQrImage;
    }
    _cachedQrData = qrData;
    _cachedQrImage = QrImage(
      QrCode.fromData(data: qrData, errorCorrectLevel: QrErrorCorrectLevel.H),
    );
    return _cachedQrImage;
  }

  String _resolveCurrentUserId() {
    final authId = ref.read(authProvider).id;
    if (authId != null && authId.isNotEmpty && authId != '***') {
      return authId;
    }
    final profileUserId = ref.read(profileNotifierProvider).value?.userId;
    if (profileUserId != null && profileUserId.isNotEmpty) {
      return profileUserId;
    }
    final profileId = ref.read(profileNotifierProvider).value?.id;
    if (profileId != null && profileId.isNotEmpty) {
      return profileId;
    }
    return '';
  }

  String? _extractUserId(String raw) {
    String clean = raw.trim();
    if (clean.isEmpty) return null;

    // Strip wrapping quotes if present
    if ((clean.startsWith('"') && clean.endsWith('"')) ||
        (clean.startsWith("'") && clean.endsWith("'"))) {
      clean = clean.substring(1, clean.length - 1).trim();
    }

    // 1. Try parsing JSON (e.g. {"userId": "...", "id": "..."})
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map) {
          final id = decoded['userId'] ?? decoded['id'] ?? decoded['user_id'] ?? decoded['sub'];
          if (id != null) return id.toString().trim();
        }
      } catch (_) {}
    }

    // 2. Try parsing URL/URI (e.g. https://messenger.xdtunnel.icu/user/USER_ID or pilach://user/USER_ID)
    if (clean.startsWith('http://') || clean.startsWith('https://') || clean.contains('://')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        if (uri.queryParameters.containsKey('userId')) {
          return uri.queryParameters['userId']!.trim();
        }
        if (uri.queryParameters.containsKey('id')) {
          return uri.queryParameters['id']!.trim();
        }
        if (uri.pathSegments.isNotEmpty) {
          final last = uri.pathSegments.last.trim();
          if (last.isNotEmpty) return last;
        }
      }
    }

    // 3. Colon prefix (e.g. "user:abc" or "userId:abc" or "id:abc")
    if (clean.contains(':')) {
      final parts = clean.split(':');
      if (parts.length == 2) {
        final prefix = parts[0].trim().toLowerCase();
        if (prefix == 'user' || prefix == 'userid' || prefix == 'id' || prefix == 'pilach') {
          return parts[1].trim();
        }
      }
    }

    // 4. Clean plain ID
    clean = clean.replaceAll(RegExp(r'[\r\n\t]'), '').trim();
    if (clean.isNotEmpty && clean != '***' && clean != 'unknown_user_id') {
      return clean;
    }

    return null;
  }

  Future<void> _handleScannedBarcode(String rawValue) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final targetUserId = _extractUserId(rawValue);
    Logger.log('📷 QR Barcode Scanned: raw="$rawValue", extracted="$targetUserId"');

    if (targetUserId == null || targetUserId.isEmpty || targetUserId == '***' || targetUserId == 'unknown_user_id') {
      AppToast.show(context, 'Invalid QR code. Please scan a valid user QR code.', type: ToastType.error);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _resumeScanning();
      });
      return;
    }

    final currentUserId = _resolveCurrentUserId();
    if (currentUserId.isNotEmpty && targetUserId == currentUserId) {
      AppToast.show(context, 'You cannot start a conversation with yourself', type: ToastType.warning);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _resumeScanning();
      });
      return;
    }

    // 1. Check in-memory conversations in chatProvider
    final existingChat = ref.read(chatProvider).cast<ChatModel?>().firstWhere(
      (c) => c != null && (c.userId == targetUserId || c.id == targetUserId),
      orElse: () => null,
    );

    if (existingChat != null) {
      if (!mounted) return;
      ref.read(currentChatIdProvider.notifier).state = existingChat.id;
      AppToast.show(context, 'Opening conversation...', type: ToastType.info);
      context.pushReplacement(AppPaths.chat);
      return;
    }

    // 2. Check local SQLite database
    final localRow = await ChatDao().getChatByOtherUserId(targetUserId);
    if (localRow != null && localRow['id'] != null) {
      if (!mounted) return;
      final existingChatId = localRow['id'] as String;
      ref.read(currentChatIdProvider.notifier).state = existingChatId;
      AppToast.show(context, 'Opening conversation...', type: ToastType.info);
      context.pushReplacement(AppPaths.chat);
      return;
    }

    // 3. New private conversation: call POST /api/v1/conversations
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 18),
                Text(
                  'Starting private chat...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final newChatId = await ref.read(chatProvider.notifier).findOrCreatePrivateConversation(targetUserId);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (newChatId != null && newChatId.isNotEmpty) {
        if (!mounted) return;
        ref.read(currentChatIdProvider.notifier).state = newChatId;
        context.pushReplacement(AppPaths.chat);
      } else {
        if (!mounted) return;
        AppToast.show(context, 'Could not start conversation with user', type: ToastType.error);
        _resumeScanning();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      AppToast.show(
        context,
        errorMsg.isNotEmpty ? errorMsg : 'Failed to start conversation',
        type: ToastType.error,
      );
      _resumeScanning();
    }
  }

  void _resumeScanning() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileAsync = ref.watch(profileNotifierProvider);
    final profileModel = profileAsync.value;

    final myUserId = (authState.id != null && authState.id!.isNotEmpty && authState.id != '***')
        ? authState.id!
        : (profileModel?.userId != null && profileModel!.userId.isNotEmpty)
            ? profileModel.userId
            : (profileModel?.id != null && profileModel!.id.isNotEmpty)
                ? profileModel.id
                : '';

    final myName = (authState.name != null && authState.name!.isNotEmpty && authState.name != 'Unknow')
        ? authState.name!
        : (profileModel?.name != null && profileModel!.name.isNotEmpty)
            ? profileModel.name
            : 'User';

    final myImage = (authState.profileImage != null && authState.profileImage!.isNotEmpty && authState.profileImage != 'image_not_found')
        ? authState.profileImage!
        : (profileModel?.avatarUrl != null && profileModel!.avatarUrl!.isNotEmpty)
            ? profileModel.avatarUrl!
            : 'image_not_found';

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AppText(
          "QR Code",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.share,
              color: AppColors.successGreen,
              size: 22,
            ),
            onPressed: () {
              if (myUserId.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: myUserId));
                AppToast.show(context, 'User ID copied to clipboard', type: ToastType.success);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // --- iOS Style Segmented Tab Bar ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(7.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: theme.colorScheme.onSurface,
                unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(
                  0.5,
                ),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: "My Code"),
                  Tab(text: "Scan Code"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // --- Tab Views ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildMyCodeTab(
                  context,
                  myUserId,
                  myName,
                  myImage,
                ),
                _buildScanCodeTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: MY CODE (Updated with pretty_qr_code) ---
  Widget _buildMyCodeTab(
    BuildContext context,
    String qrData,
    String name,
    String image,
  ) {
    final qrImage = _getOrCreateQrImage(qrData);
    final bool hasValidId = qrImage != null;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User Profile info row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.1,
                        ),
                        backgroundImage: image != "image_not_found"
                            ? NetworkImage(image)
                            : null,
                        child: image == "image_not_found"
                            ? Icon(
                                Icons.person,
                                size: 25,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Scan to connect with me",
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // QR View Container - Must remain white background for scanning compatibility
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: qrImage != null
                        ? PrettyQrView(
                            qrImage: qrImage,
                            decoration: const PrettyQrDecoration(
                              background: Colors.transparent,
                              quietZone: PrettyQrQuietZone.zero,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Generating your code...",
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 12, 48, 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          hasValidId ? qrData : 'Loading your User ID...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.5,
                            height: 1.4,
                          ),
                        ),
                      ),

                      if (hasValidId)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: qrData),
                                );

                                if (context.mounted) {
                                  AppToast.show(context, 'ID copied', type: ToastType.success);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  CupertinoIcons.doc_on_doc,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Text(
                    "Your QR code is private. Other people can scan this to add or connect with you instantly.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.4,
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

  // --- TAB 2: SCAN CODE ---
  Widget _buildScanCodeTab(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            "Align the QR code within the frame to scan",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),

          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      if (_isProcessing) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final String? scannedValue = barcode.rawValue;
                        if (scannedValue != null && scannedValue.trim().isNotEmpty) {
                          _handleScannedBarcode(scannedValue);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                height: 260,
                child: CustomPaint(painter: QRScannerOverlayPainter()),
              ),
            ],
          ),
          const Spacer(),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              final isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                padding: const EdgeInsets.all(16),
                style: IconButton.styleFrom(
                  backgroundColor: isTorchOn
                      ? AppColors.primary
                      : theme.colorScheme.surface,
                  shape: const CircleBorder(),
                  shadowColor: Colors.black.withOpacity(0.05),
                  elevation: 4,
                ),
                icon: Icon(
                  isTorchOn
                      ? CupertinoIcons.lightbulb_fill
                      : CupertinoIcons.lightbulb,
                  color: isTorchOn ? Colors.white : theme.colorScheme.onSurface,
                  size: 24,
                ),
                onPressed: () {
                  _scannerController.toggleTorch();
                },
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class QRScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.successGreen
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double cornerSize = 25;

    canvas.drawPath(
      Path()
        ..moveTo(0, cornerSize)
        ..lineTo(0, 0)
        ..lineTo(cornerSize, 0),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerSize),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerSize)
        ..lineTo(0, size.height)
        ..lineTo(cornerSize, size.height),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
