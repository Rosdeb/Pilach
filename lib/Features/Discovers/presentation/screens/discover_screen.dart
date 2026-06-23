import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../components/AppText/appText.dart';
import '../providers/discover_providers.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // iOS Large Title Navigation Bar
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              automaticallyImplyLeading: false,
              expandedHeight: 65.0,
              toolbarHeight: 65.0,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: theme.scaffoldBackgroundColor,
              centerTitle: true,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 24.0, bottom: 16.0),
                    centerTitle: false,
                    title: AppText(
                      'Discover',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
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
                    _buildSectionHeader(context, 'Stories', 'See All'),
                    const SizedBox(height: 12),
                    _buildStoriesTray(context),

                    const SizedBox(height: 35),

                    // --- NEARBY SCAN SECTION ---
                    _buildSectionHeader(context, 'Nearby People', state.isScanning ? 'Scanning...' : 'Paused'),
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

  Widget _buildSectionHeader(BuildContext context, String title, String actionText) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
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

  Widget _buildStoriesTray(BuildContext context) {
    final theme = Theme.of(context);
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
                            color: theme.colorScheme.onSurface.withOpacity(0.08),
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
                    Text(
                      'Your Story',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
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
                      color: theme.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.onSurface.withOpacity(0.05),
                      child: Icon(CupertinoIcons.person_fill, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'User $index',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRadarScanner(BuildContext context, WidgetRef ref, bool isScanning) {
    final theme = Theme.of(context);
    return Center(
      child: GestureDetector(
        onTap: () => ref.read(discoverProvider.notifier).toggleScan(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Concentric Radar Circles
            _buildRadarCircle(context, 240, isScanning ? 0.3 : 0.1),
            _buildRadarCircle(context, 170, isScanning ? 0.5 : 0.2),
            _buildRadarCircle(context, 110, isScanning ? 0.7 : 0.3),

            // Central Interactive Scanner Core
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(
                isScanning ? CupertinoIcons.goforward : CupertinoIcons.add,
                color: theme.colorScheme.onPrimary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarCircle(BuildContext context, double size, double opacity) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(opacity),
          width: 1.5,
        ),
      ),
    );
  }
}