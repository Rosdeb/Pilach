import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colour.dart';
import '../../widgets/chat_bundle.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<MessageModel> _messages = [
    MessageModel(
      text: "Hey! Are we still on for the project review this afternoon?",
      time: "10:42 AM",
      isMe: false,
    ),
    MessageModel(
      text: "Absolutely! I've just finished the final mockups for the new dashboard.",
      time: "10:45 AM",
      isMe: true,
      status: MessageStatus.seen,
    ),
    MessageModel(
      text: "That sounds great. I'm really curious to see how you handled the bento grid section. 🍱",
      time: "10:46 AM",
      isMe: false,
    ),
    MessageModel(
      text: "I think you'll like it. It feels very clean and intuitive now. I'll share my screen during the call at 2 PM.",
      time: "10:48 AM",
      isMe: true,
      status: MessageStatus.seen,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // --- iOS STYLE CHAT TOP BAR ---
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1494790108377-be9c29b29330'),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.successGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Alexandra Sterling',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Online',
                    style: TextStyle(
                      color: AppColors.successGreen.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.phone, color: AppColors.successGreen, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.video_camera, color: AppColors.successGreen, size: 26),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.ellipsis_vertical, color: AppColors.textDark, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        //border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.1), width: 1)),
      ),

      // --- CHAT MESSAGES BODY ---
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: [
                  // Today Separator
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(color: AppColors.textLight, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  // Message list mapping
                  ..._messages.map((msg) => ChatBubble(message: msg)),
                ],
              ),
            ),

            // --- BOTTOM COMPOSER INPUT DECK ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.1), width: 1)),
              ),
              child: Row(
                children: [
                  // Attachment Add Button
                  IconButton(
                    icon: const Icon(CupertinoIcons.add, color: AppColors.successGreen, size: 24),
                    onPressed: () {},
                  ),

                  // Expanded Input Box
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        maxHeight: 120,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white_bg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.border.withOpacity(0.15),
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 5,right: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,

                                hintText: 'Type a message',
                                border: InputBorder.none,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(50),
                                  borderSide: BorderSide(
                                    color: Colors.transparent
                                  )
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(50),
                                  borderSide: BorderSide(
                                    color: Colors.transparent,
                                  )
                                ),
                                fillColor: AppColors.white_bg,
                                isDense: true,
                              ),
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.smiley,
                              size: 20,
                              color: AppColors.textLight,
                            ),
                            onPressed: () {},
                            padding: EdgeInsets.all(5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Action Floating Trigger
                  GestureDetector(
                    onTap: () {
                      if (_messageController.text.trim().isEmpty) return;
                      setState(() {
                        _messages.add(MessageModel(
                          text: _messageController.text.trim(),
                          time: "1:03 AM", // Dynamic handling replaces this
                          isMe: true,
                          status: MessageStatus.sent,
                        ));
                        _messageController.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.blue, // Dynamic custom primary blue choice from screenshot
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 18),
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

enum MessageStatus { sent, delivered, seen }

class MessageModel {
  final String text;
  final String time;
  final bool isMe;
  final MessageStatus? status;

  MessageModel({
    required this.text,
    required this.time,
    required this.isMe,
    this.status,
  });
}