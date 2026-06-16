import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
// Replace these imports with your actual path utilities
import '../../../../../components/AppText/appText.dart';
import '../../../../../core/utils/app_colour.dart';

// MOCK PROVIDER: Replace this with your actual Auth/User Profile Provider
final userIdProvider = Provider<String>((ref) {
  return "backend_user_id_123456789"; // This represents your backend ID data
});

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch your backend ID from Riverpod
    final backendId = ref.watch(userIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.back_icon, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const AppText(
          "QR Code",
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.share, color: AppColors.successGreen, size: 22),
            onPressed: () {
              // Share action logic
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // --- iOS Style Segmented Tab Bar ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: AppColors.textDark,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
                _buildMyCodeTab(backendId),
                _buildScanCodeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: MY CODE (Updated with pretty_qr_code) ---
  Widget _buildMyCodeTab(String qrData) {
    // Generate the QR configuration safely based on your backend string data
    final qrImage = QrImage(QrCode.fromData(
      data: qrData,
      errorCorrectLevel: QrErrorCorrectLevel.H, // High error correction permits logo overlays
    ));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
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
                        backgroundImage: NetworkImage('https://cdn.motor1.com/images/mgl/bglVnv/s3/best-new-cars-coming-out-in-2025.webp'), // Replace with actual asset/image
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Alex Koch",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Scan to connect with me",
                              style: TextStyle(fontSize: 13, color: AppColors.textLight),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Beautiful PrettyQrView Container
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: PrettyQrView(
                      qrImage: qrImage,
                      decoration: const  PrettyQrDecoration(
                        background: Colors.transparent,
                        quietZone: PrettyQrQuietZone.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    "Your QR code is private. Other people can scan this to add or connect with you instantly.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textLight, fontSize: 13, height: 1.4),
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
  Widget _buildScanCodeTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "Align the QR code within the frame to scan",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLight, fontSize: 14),
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
                  child: Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Icon(CupertinoIcons.camera_viewfinder, color: Colors.white54, size: 40),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                height: 260,
                child: CustomPaint(
                  painter: QRScannerOverlayPainter(),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            padding: const EdgeInsets.all(16),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              shadowColor: Colors.black.withOpacity(0.05),
              elevation: 4,
            ),
            icon: const Icon(CupertinoIcons.lightbulb_fill, color: AppColors.textDark, size: 24),
            onPressed: () {},
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

    canvas.drawPath(Path()..moveTo(0, cornerSize)..lineTo(0, 0)..lineTo(cornerSize, 0), paint);
    canvas.drawPath(Path()..moveTo(size.width - cornerSize, 0)..lineTo(size.width, 0)..lineTo(size.width, cornerSize), paint);
    canvas.drawPath(Path()..moveTo(0, size.height - cornerSize)..lineTo(0, size.height)..lineTo(cornerSize, size.height), paint);
    canvas.drawPath(Path()..moveTo(size.width - cornerSize, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}