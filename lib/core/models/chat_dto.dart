import '../../Features/Chat/data/models/chat_model.dart';
import 'package:intl/intl.dart';

class ChatDto {
  final String id;
  final String type;
  final String? title;
  final String? avatarUrl;
  final int unreadCount;
  final String createdAt;
  final dynamic lastMessageSeq; 
  final String? lastMessageAt;
  final String? updatedAt;
  final Map<String, dynamic>? lastMessage;
  final List<dynamic>? members;
  final String? dmKey;       // "userId1:userId2" format
  final String? creatorId;   // conversation creator

  ChatDto({
    required this.id,
    required this.type,
    this.title,
    this.avatarUrl,
    required this.unreadCount,
    required this.createdAt,
    this.lastMessageSeq,
    this.lastMessageAt,
    this.updatedAt,
    this.lastMessage,
    this.members,
    this.dmKey,
    this.creatorId,
  });

  factory ChatDto.fromJson(Map<String, dynamic> json) {
    return ChatDto(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String,
      lastMessageSeq: json['lastMessageSeq'],
      lastMessageAt: json['lastMessageAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      lastMessage: json['lastMessage'] as Map<String, dynamic>?,
      members: json['members'] as List<dynamic>?,
      dmKey: json['dmKey'] as String?,
      creatorId: json['creatorId'] as String?,
    );
  }

  // To save to SQLite
  Map<String, dynamic> toSqliteMap() {
    String? displayTitle = title;
    String? displayAvatar = avatarUrl;
    String? otherUserId;
    bool isOnline = false;
    String? lastActive;
    
    // PRIVATE chat: other member-এর info নাও
    if (type == 'PRIVATE' && members != null && members!.isNotEmpty) {
      final firstMember = members!.first;
      if (firstMember is Map) {
        // API তে member-এ 'userId' নেই — 'user.id' বা অন্য field চেক করো
        otherUserId = firstMember['userId'] as String?         // ভবিষ্যতে যদি আসে
                   ?? (firstMember['user'] as Map?)?['id'] as String?; // user.id

        final profile = (firstMember['user'] as Map?)?['profile'] as Map?;
        if (profile != null) {
          // Other member-এর name ও avatar দিয়ে override করো
          displayTitle = profile['name']?.toString() ?? displayTitle;
          displayAvatar = profile['avatarUrl']?.toString() ?? displayAvatar;
        }

        final userObj = firstMember['user'] as Map?;
        if (userObj != null) {
          final status = userObj['status'];
          final isOnlineBool = userObj['isOnline'];
          if (isOnlineBool == true || status == 'ONLINE') {
            isOnline = true;
          }
          lastActive = userObj['lastActive']?.toString();
        }
      }
    }

    // otherUserId এখনো null? dmKey থেকে বের করার চেষ্টা করো
    // dmKey format: "userId1:userId2" — creatorId বাদ দিলে other user পাওয়া যাবে
    if (otherUserId == null && dmKey != null && creatorId != null) {
      final parts = dmKey!.split(':');
      if (parts.length == 2) {
        // যেটা creatorId না সেটাই other user
        otherUserId = parts.firstWhere(
          (p) => p != creatorId,
          orElse: () => parts.first,
        );
      }
    }

    return {
      'id': id,
      'other_user_id': otherUserId,
      'type': type,
      'title': displayTitle,
      'avatar_url': displayAvatar,
      'unread_count': unreadCount,
      'last_message_seq': (lastMessageSeq is String) ? int.tryParse(lastMessageSeq) : lastMessageSeq,
      'last_message_preview': lastMessage?['text'],
      'last_message_at': lastMessageAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_online': isOnline ? 1 : 0,
      'last_active_at': lastActive,
    };
  }
}

extension ChatDtoMapper on ChatDto {
  /// Converts the backend DTO perfectly into the UI ChatModel
  ChatModel toDomain() {
    String formattedTime = '';
    if (lastMessageAt != null) {
      final dt = DateTime.tryParse(lastMessageAt!);
      if (dt != null) formattedTime = DateFormat('hh:mm a').format(dt.toLocal());
    }

    String? displayTitle = title;
    String? displayAvatar = avatarUrl;
    String? otherUserId;
    
    // Fallback for PRIVATE chats
    if (type == 'PRIVATE' && members != null && members!.isNotEmpty) {
      final firstMember = members!.first;
      if (firstMember is Map) {
        otherUserId = firstMember['userId'] as String?;
        final profile = (firstMember['user'] as Map?)?['profile'] as Map?;
        if (profile != null) {
          // Force override title and avatar from the member's profile for private chats
          displayTitle = profile['name']?.toString() ?? displayTitle;
          displayAvatar = profile['avatarUrl']?.toString() ?? displayAvatar;
        }
      }
    }

    return ChatModel(
      id: id,
      userId: otherUserId,
      name: displayTitle ?? 'Unknown User', // Handle PRIVATE chats with null title
      message: lastMessage?['text'] ?? 'New Chat',
      image: displayAvatar ?? 'https://cdn.motor1.com/images/mgl/bglVnv/239:0:1438:1080/best-new-cars-coming-out-in-2025.webp',
      time: formattedTime,
      unreadCount: unreadCount,
      isOnline: false, // Provide true via a separate presence service if needed
      isMuted: false,
      isRead: unreadCount == 0,
      isPinned: false,
    );
  }
}

extension ChatSqliteMapper on Map<String, dynamic> {
  /// Converts an SQLite row into the UI ChatModel
  ChatModel toChatModel() {
    String formattedTime = '';
    final timeStr = this['last_message_at'] ?? this['created_at'];
    if (timeStr != null) {
      final dt = DateTime.tryParse(timeStr as String);
      if (dt != null) formattedTime = DateFormat('hh:mm a').format(dt.toLocal());
    }

    final sqliteAvatar = this['avatar_url'] as String?;
    String resolvedAvatar = (sqliteAvatar == null || sqliteAvatar == 'assets/images/default.png')
        ? 'https://cdn.motor1.com/images/mgl/bglVnv/239:0:1438:1080/best-new-cars-coming-out-in-2025.webp'
        : sqliteAvatar;

    // ✅ সরাসরি URL ব্যবহার করো — আলাদা cache-busting দরকার নেই
    // যুক্তি: conversation.updated_at প্রতিটা message-এ পরিবর্তন হয়
    //       তাই ?v=updated_at দিলে প্রতি মেসেজে avatar re-download হয়!
    // Server নতুন avatar দিলে URL নিজেই পরিবর্তন হবে → CachedNetworkImage তন নতুন দিয়ে load করবে

    return ChatModel(
      id: this['id'] as String,
      userId: this['other_user_id'] as String?,
      name: this['title'] ?? 'Unknown User',
      message: this['last_message_preview'] ?? 'New Chat',
      image: resolvedAvatar,
      time: formattedTime,
      unreadCount: (this['unread_count'] as num?)?.toInt() ?? 0,
      isOnline: (this['is_online'] as num?)?.toInt() == 1,
      isMuted: (this['is_muted'] as num?)?.toInt() == 1,
      isRead: ((this['unread_count'] as num?)?.toInt() ?? 0) == 0,
      isPinned: (this['is_pinned'] as num?)?.toInt() == 1,
      lastActive: this['last_active_at'] as String?,
    );
  }
}
