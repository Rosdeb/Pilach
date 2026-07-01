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
  final Map<String, dynamic>? lastMessage;

  ChatDto({
    required this.id,
    required this.type,
    this.title,
    this.avatarUrl,
    required this.unreadCount,
    required this.createdAt,
    this.lastMessageSeq,
    this.lastMessageAt,
    this.lastMessage,
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
      lastMessage: json['lastMessage'] as Map<String, dynamic>?,
    );
  }

  // To save to SQLite
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'avatar_url': avatarUrl,
      'unread_count': unreadCount,
      'last_message_seq': (lastMessageSeq is String) ? int.tryParse(lastMessageSeq) : lastMessageSeq,
      'last_message_preview': lastMessage?['text'],
      'last_message_at': lastMessageAt,
      'created_at': createdAt,
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

    return ChatModel(
      id: id,
      name: title ?? 'Unknown User', // Handle PRIVATE chats with null title
      message: lastMessage?['text'] ?? 'New Chat',
      image: avatarUrl ?? 'assets/images/default.png',
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

    return ChatModel(
      id: this['id'] as String,
      name: this['title'] ?? 'Unknown User',
      message: this['last_message_preview'] ?? 'New Chat',
      image: this['avatar_url'] ?? 'assets/images/default.png',
      time: formattedTime,
      unreadCount: (this['unread_count'] as num?)?.toInt() ?? 0,
      isOnline: false,
      isMuted: (this['is_muted'] as num?)?.toInt() == 1,
      isRead: ((this['unread_count'] as num?)?.toInt() ?? 0) == 0,
      isPinned: (this['is_pinned'] as num?)?.toInt() == 1,
    );
  }
}
