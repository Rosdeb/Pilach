import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewContactBottomSheet extends ConsumerStatefulWidget {
  const NewContactBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<NewContactBottomSheet> createState() => _NewContactBottomSheetState();
}

class _NewContactBottomSheetState extends ConsumerState<NewContactBottomSheet> {
  final _appIdController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _appIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      // FIXED: Replaced static height with a dynamic max-constraint boundary.
      // This allows the sheet to expand naturally up to 85% of screen real estate when pushed by the keyboard.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // FIXED: Shrinks container tightly to wrap list content boundaries
            children: [
              // --- STICKY iOS TOP NAVIGATION HEADER BAR ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.12), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      'New Contact',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Access your Riverpod network providers here using 'ref'
                        // e.g., ref.read(chatProvider.notifier).connectWithId(_appIdController.text);
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Color(0xFF34C759),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- BODY INPUTS CONTENT ---
              Flexible( // FIXED: Wrapped in Flexible instead of Expanded so it squishes properly when keyboard displays
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 24.0,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24.0, // Dynamic Keyboard buffer spacing offset
                  ),
                  child: Column(
                    children: [
                      // --- PROFILE PICTURE PLACEHOLDER ---
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF1A3E40) : const Color(0xFFB8D8DA),
                              backgroundImage: const NetworkImage("https://static.vecteezy.com/system/resources/thumbnails/053/733/179/small/every-detail-of-a-sleek-modern-car-captured-in-close-up-photo.jpg"),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.camera_fill,
                                  color: theme.colorScheme.onPrimary,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Add Photo',
                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- GROUPED ROWS COMPONENT INPUT BLOCK ---
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // App ID field with explicit trailing scan action integration
                            _buildInlineField(
                              context: context,
                              hint: 'App Id',
                              controller: _appIdController,
                              keyboardType: TextInputType.text,
                              prefixIcon: CupertinoIcons.person_crop_circle_badge_plus,
                              suffixAction: IconButton(
                                icon: Icon(
                                  CupertinoIcons.qrcode_viewfinder,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                ),
                                onPressed: () {
                                  // Hook up your camera scanning package routine layer here
                                },
                              ),
                            ),
                            _buildDivider(theme),
                            _buildInlineField(
                              context: context,
                              hint: 'First Name',
                              controller: _firstNameController,
                              keyboardType: TextInputType.name,
                            ),
                            _buildDivider(theme),
                            _buildInlineField(
                              context: context,
                              hint: 'Last Name',
                              controller: _lastNameController,
                              keyboardType: TextInputType.name,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- SECONDARY DATA BLOCK ---
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildInlineField(
                              context: context,
                              hint: 'Phone',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              prefixIcon: CupertinoIcons.phone,
                            ),
                            _buildDivider(theme),
                            _buildInlineField(
                              context: context,
                              hint: 'Email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: CupertinoIcons.mail,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
    );
  }

  // Row field design matching standard configuration
  Widget _buildInlineField({
    required BuildContext context,
    required String hint,
    required TextEditingController controller,
    required TextInputType keyboardType,
    IconData? prefixIcon,
    Widget? suffixAction,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, color: theme.colorScheme.onSurface.withOpacity(0.6), size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                fillColor: theme.colorScheme.surface,
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (suffixAction != null) suffixAction,
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.12)),
    );
  }
}