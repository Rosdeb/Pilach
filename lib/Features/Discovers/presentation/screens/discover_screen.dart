import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/core/utils/app_colour.dart';

import '../../../../components/AppText/appText.dart';
import '../providers/discover_providers.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(), // Smooth iOS scrolling
          slivers: [
            // iOS Large Title Navigation Bar
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              automaticallyImplyLeading: false,
              expandedHeight: 65.0, // Gives room for the large iOS title layout
              toolbarHeight: 65.0,
              backgroundColor: AppColors.background, // Semi-transparent base
              surfaceTintColor:  AppColors.background,
              centerTitle: true,
              // This is where the magic glass blur effect happens
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: const FlexibleSpaceBar(
                    titlePadding: EdgeInsets.only(left: 24.0, bottom: 16.0),
                    centerTitle: false,
                    title: AppText(
                      'Discover',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main Content Body
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // --- STORIES SECTION ---
                    _buildSectionHeader('Stories', 'See All'),
                    const SizedBox(height: 12),
                    _buildStoriesTray(),

                    const SizedBox(height: 35),

                    // --- NEARBY SCAN SECTION ---
                    _buildSectionHeader('Nearby People', state.isScanning ? 'Scanning...' : 'Paused'),
                    const SizedBox(height: 20),
                    _buildRadarScanner(context, ref, state.isScanning),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Components ---

  Widget _buildSectionHeader(String title, String actionText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: () {},
          child: Text(
            actionText,
            style: const TextStyle(
              color: CupertinoColors.activeBlue,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoriesTray() {
    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, index) {
          if (index == 0) {
            // First item is the "Publish Story" CTA slot
            return Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () {
                  // TODO: Publish story logic
                },
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.plus,
                            size: 26,
                            color: CupertinoColors.activeBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Story',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          // Sample User Stories
          return Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [CupertinoColors.activeOrange, CupertinoColors.systemPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: CupertinoColors.systemGroupedBackground,
                      child: Icon(CupertinoIcons.person_fill, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'User $index',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRadarScanner(BuildContext context, WidgetRef ref, bool isScanning) {
    return Center(
      child: GestureDetector(
        onTap: () => ref.read(discoverProvider.notifier).toggleScan(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Concentric Radar Circles
            _buildRadarCircle(240, isScanning ? 0.3 : 0.1),
            _buildRadarCircle(170, isScanning ? 0.5 : 0.2),
            _buildRadarCircle(110, isScanning ? 0.7 : 0.3),

            // Central Interactive Scanner Core
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: CupertinoColors.activeBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Icon(
                isScanning ? CupertinoIcons.goforward : CupertinoIcons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarCircle(double size, double opacity) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: CupertinoColors.activeBlue.withOpacity(opacity),
          width: 1.5,
        ),
      ),
    );
  }
}