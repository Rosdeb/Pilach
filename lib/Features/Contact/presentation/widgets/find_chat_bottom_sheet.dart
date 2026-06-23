import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/find_chat_bottom_sheet.dart';
// Import your findAndConnectChatProvider and ChatRoomScreen page here

class FindChatBottomSheet extends ConsumerStatefulWidget {
  const FindChatBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<FindChatBottomSheet> createState() => FindChatBottomSheetState();
}

class FindChatBottomSheetState extends ConsumerState<FindChatBottomSheet> {
  final _idController = TextEditingController();
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  void _handleSearchAndConnect() async {
    final enteredId = _idController.text.trim();
    if (enteredId.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    // Run the lookup through your Riverpod layout layer channel
    final chatRoomId = ref.read(findAndConnectChatProvider).searchAndCreateChatThread(enteredId);

    setState(() {
      _isSearching = false;
    });

    if (chatRoomId != null) {
      // 1. Pop out of the current bottom sheet overlay layer context safely
      Navigator.of(context).pop();

      // 2. Instantly route the viewport screen straight to the freshly created chat room thread
      // Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: chatRoomId)));
    } else {
      setState(() {
        _errorMessage = "No active user profile matched this App ID.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      // FIXED: Swapped hardcoded container height for a dynamic max-constraint boundary.
      // This prevents the keyboard overlay from squishing and clipping content.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
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
          mainAxisSize: MainAxisSize.min, // FIXED: Shrinks container tightly around content bounds
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
                    'Find Chat',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _idController.text.trim().isEmpty || _isSearching
                        ? null
                        : _handleSearchAndConnect,
                    child: Text(
                      'Connect',
                      style: TextStyle(
                        color: _idController.text.trim().isEmpty || _isSearching
                            ? theme.colorScheme.onSurface.withOpacity(0.3)
                            : const Color(0xFF34C759),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- BODY LAYOUT INTEGRATION ---
            Flexible( // FIXED: Swapped Expanded for Flexible so it reacts correctly to height changes
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 24.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0, // Moves cleanly over screen keyboards
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Graphic Display Cluster
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.chat_bubble_text_fill,
                          color: Color(0xFF34C759),
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Start Conversation via ID',
                        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Enter your friend\'s unique application identifier code or scan their generated profile card matrix.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13, height: 1.3),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- SEARCH CONNECTIVITY CARD BLOCK ---
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.person_crop_circle_badge_plus,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _idController,
                                autofocus: true,
                                onChanged: (value) => setState(() {}), // Refreshes action button activation state
                                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
                                decoration: InputDecoration(
                                  fillColor: theme.colorScheme.surface,
                                  hintText: 'App Id (e.g. KC-92834)',
                                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            // iOS suffix QR finder integration button
                            IconButton(
                              icon: Icon(
                                CupertinoIcons.qrcode_viewfinder,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                              onPressed: () {
                                // Fire up your scanner pipeline layout routing step here
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Error context label diagnostics loop output channel
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
                        ),
                      ),

                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.only(top: 20.0),
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}