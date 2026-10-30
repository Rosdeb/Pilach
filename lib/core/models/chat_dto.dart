import '../../Features/Chat/data/models/chat_model.dart';
import '../utils/date_formatter.dart';

dynamic _selectOtherMember(List<dynamic> members, String? currentUserId) {
  if (currentUserId == null || currentUserId.isEmpty) return members.first;
  for (final member in members) {
    if (_memberUserId(member) != currentUserId) return member;
  }
  return members.first;
}

String? _memberUserId(dynamic member) {
  if (member is! Map) return null;
  final user = member['user'];
  final id = member['userId'] ?? (user is Map ? user['id'] : null);
  return id?.toString();
}

Map<dynamic, dynamic>? _presenceForMember(dynamic member) {
  if (member is! Map) return null;
  final user = member['user'];
  return user is Map ? user : member;
}

bool _memberIsOnline(dynamic member) {
  final presence = _presenceForMember(member);
  if (presence == null) return false;
  final rawOnline =
      presence['isOnline'] ?? presence['online'] ?? presence['is_online'];
  final status = (presence['status'] ?? presence['presenceStatus'])
      ?.toString()
      .toUpperCase();
  return rawOnline == true ||
      rawOnline == 1 ||
      rawOnline?.toString().toLowerCase() == 'true' ||
      status == 'ONLINE';
}

bool _memberHasPresence(dynamic member) {
  final presence = _presenceForMember(member);
  return presence != null &&
      (presence.containsKey('isOnline') ||
          presence.containsKey('online') ||
          presence.containsKey('is_online') ||
          presence.containsKey('status') ||
          presence.containsKey('presenceStatus'));
}

String? _memberLastActive(dynamic member) {
  final presence = _presenceForMember(member);
  return (presence?['lastActive'] ??
          presence?['lastSeen'] ??
          presence?['last_active_at'])
      ?.toString();
}

List<String> _extractMemberAvatars(List<dynamic>? members) {
  if (members == null || members.isEmpty) return const [];
  final avatars = <String>[];
  for (final member in members) {
    if (member is! Map) continue;
    final userMap = member['user'] as Map?;
    final profile =
        (userMap?['profile'] as Map?) ?? (member['profile'] as Map?);

    String? avatar = profile?['avatarUrl']?.toString() ??
        profile?['avatar']?.toString() ??
        userMap?['avatarUrl']?.toString() ??
        userMap?['avatar']?.toString() ??
        member['avatarUrl']?.toString() ??
        member['avatar']?.toString();

    if (avatar != null) {
      avatar = avatar.trim();
      if (avatar.isNotEmpty &&
          avatar != 'null' &&
          avatar != 'assets/images/default.png' &&
          !avatar.contains('motor1.com')) {
        if (!avatars.contains(avatar)) {
          avatars.add(avatar);
        }
      }
    }
  }
  return avatars;
}

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
  final String? dmKey; // "userId1:userId2" format
  final String? creatorId; // conversation creator

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
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      type: json['type']?.toString() ?? 'PRIVATE',
      title: json['title']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      createdAt:
          json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      lastMessageSeq: json['lastMessageSeq'],
      lastMessageAt: json['lastMessageAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      lastMessage: json['lastMessage'] is Map
          ? Map<String, dynamic>.from(json['lastMessage'] as Map)
          : null,
      members: json['members'] as List<dynamic>?,
      dmKey: json['dmKey']?.toString(),
      creatorId: json['creatorId']?.toString(),
    );
  }

  String? _resolveLastMessagePreview() {
    if (lastMessage == null) return null;

    final String? text = lastMessage?['text'] as String?;
    final String type =
        (lastMessage?['type'] as String?)?.toUpperCase() ?? 'TEXT';
    final attachments = lastMessage?['attachments'] as List<dynamic>?;

    if (text != null && text.isNotEmpty) {
      if (type == 'IMAGE') return '📷 $text';
      if (type == 'VIDEO') return '🎥 $text';
      if (type == 'AUDIO' || type == 'VOICE') return '🎵 $text';
      if (type == 'FILE') return '📁 $text';
      return text;
    }

    if (attachments != null && attachments.isNotEmpty) {
      final attachmentType = (attachments.first['type'] as String?)
          ?.toUpperCase();
      if (attachmentType == 'IMAGE') return '📷 Photo';
      if (attachmentType == 'VIDEO') return '🎥 Video';
      if (attachmentType == 'AUDIO' || attachmentType == 'VOICE')
        return '🎵 Audio';
      if (attachmentType == 'FILE') return '📁 File';
    }

    if (type == 'IMAGE') return '📷 Photo';
    if (type == 'VIDEO') return '🎥 Video';
    if (type == 'AUDIO' || type == 'VOICE') return '🎵 Audio';
    if (type == 'FILE') return '📁 File';

    return lastMessage?['text'] as String?;
  }

  // To save to SQLite
  Map<String, dynamic> toSqliteMap([String? currentUserId]) {
    String? displayTitle = title;
    String? displayAvatar = avatarUrl;
    String? otherUserId;
    bool? isOnline;
    String? lastActive;

    if (type == 'GROUP') {
      if (avatarUrl == null ||
          avatarUrl!.isEmpty ||
          avatarUrl!.contains('motor1.com') ||
          avatarUrl == 'assets/images/default.png') {
        final memberAvatars = _extractMemberAvatars(members);
        if (memberAvatars.isNotEmpty) {
          displayAvatar = 'MEMBERS_AVATARS:${memberAvatars.take(3).join(',')}';
        } else {
          displayAvatar = null;
        }
      }
    } else if (type == 'PRIVATE' && members != null && members!.isNotEmpty) {
      final otherMember = _selectOtherMember(members!, currentUserId);

      if (otherMember is Map) {
        otherUserId = _memberUserId(otherMember);

        final userMap = otherMember['user'] as Map?;
        final profile =
            (userMap?['profile'] as Map?) ?? (otherMember['profile'] as Map?);
        if (profile != null) {
          displayTitle =
              profile['name']?.toString() ??
              profile['displayName']?.toString() ??
              displayTitle;
          displayAvatar =
              profile['avatarUrl']?.toString() ??
              profile['avatar']?.toString() ??
              displayAvatar;
        } else if (userMap != null) {
          displayTitle =
              userMap['name']?.toString() ??
              userMap['username']?.toString() ??
              displayTitle;
          displayAvatar =
              userMap['avatarUrl']?.toString() ??
              userMap['avatar']?.toString() ??
              displayAvatar;
        } else {
          displayTitle = otherMember['name']?.toString() ?? displayTitle;
          displayAvatar = otherMember['avatarUrl']?.toString() ?? displayAvatar;
        }

        if (_memberHasPresence(otherMember)) {
          isOnline = _memberIsOnline(otherMember);
        }
        lastActive = _memberLastActive(otherMember);
      }
    }

    // otherUserId dmKey থেকে বের করো (format: "userId1:userId2")
    if (otherUserId == null && dmKey != null) {
      final parts = dmKey!.split(':');
      if (parts.length == 2) {
        if (currentUserId != null && currentUserId.isNotEmpty) {
          otherUserId = parts.firstWhere(
            (p) => p != currentUserId,
            orElse: () => parts.first,
          );
        } else if (creatorId != null) {
          otherUserId = parts.firstWhere(
            (p) => p != creatorId,
            orElse: () => parts.first,
          );
        }
      }
    }

    final String? lastMessagePreview = _resolveLastMessagePreview();

    return {
      'id': id,
      'other_user_id': otherUserId,
      'type': type,
      'title': displayTitle,
      'avatar_url': displayAvatar,
      'unread_count': unreadCount,
      'last_message_seq': (lastMessageSeq is String)
          ? int.tryParse(lastMessageSeq)
          : lastMessageSeq,
      'last_message_preview': lastMessagePreview,
      'last_message_at': lastMessageAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_online': isOnline == null ? null : (isOnline ? 1 : 0),
      'last_active_at': lastActive,
    };
  }
}

extension ChatDtoMapper on ChatDto {
  /// Converts the backend DTO perfectly into the UI ChatModel
  ChatModel toDomain([String? currentUserId]) {
    String formattedTime = '';
    if (lastMessageAt != null) {
      final dt = DateTime.tryParse(lastMessageAt!);
      if (dt != null)
        formattedTime = DateFormatter.formatConversationTime(dt.toLocal());
    }

    String? displayTitle = title;
    String? displayAvatar = avatarUrl;
    String? otherUserId;
    bool isOnline = false;
    String? lastActive;
    List<String> memberAvatars = const [];

    if (type == 'GROUP') {
      memberAvatars = _extractMemberAvatars(members);
      if (displayAvatar == null ||
          displayAvatar.isEmpty ||
          displayAvatar.contains('motor1.com') ||
          displayAvatar == 'assets/images/default.png') {
        displayAvatar = '';
      }
    } else if (type == 'PRIVATE' && members != null && members!.isNotEmpty) {
      final otherMember = _selectOtherMember(members!, currentUserId);

      if (otherMember is Map) {
        otherUserId = _memberUserId(otherMember);
        final profile = (otherMember['user'] as Map?)?['profile'] as Map?;
        if (profile != null) {
          // Force override title and avatar from the member's profile for private chats
          displayTitle = profile['name']?.toString() ?? displayTitle;
          displayAvatar = profile['avatarUrl']?.toString() ?? displayAvatar;
        }
        isOnline = _memberIsOnline(otherMember);
        lastActive = _memberLastActive(otherMember);
      }
      if (displayAvatar != null &&
          (displayAvatar.contains('motor1.com') ||
              displayAvatar == 'assets/images/default.png')) {
        displayAvatar = '';
      }
    }

    final String? previewMessage = _resolveLastMessagePreview();

    return ChatModel(
      id: id,
      userId: otherUserId,
      name:
          displayTitle ??
          (type == 'GROUP' ? 'Group Chat' : 'Unknown User'),
      message: previewMessage ?? 'New Chat',
      image: displayAvatar ?? '',
      time: formattedTime,
      unreadCount: unreadCount,
      isOnline: isOnline,
      isMuted: false,
      isRead: unreadCount == 0,
      isPinned: false,
      lastActive: lastActive,
      type: type,
      memberAvatars: memberAvatars,
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
      if (dt != null)
        formattedTime = DateFormatter.formatConversationTime(dt.toLocal());
    }

    final sqliteAvatar = this['avatar_url'] as String?;
    final String chatType =
        (this['type'] as String?)?.toUpperCase() ?? 'PRIVATE';
    List<String> memberAvatars = const [];
    String resolvedAvatar = '';

    if (sqliteAvatar != null && sqliteAvatar.startsWith('MEMBERS_AVATARS:')) {
      final rawList = sqliteAvatar.substring('MEMBERS_AVATARS:'.length);
      if (rawList.isNotEmpty) {
        memberAvatars = rawList
            .split(',')
            .map((u) => u.trim())
            .where((u) => u.isNotEmpty && !u.contains('motor1.com'))
            .toList();
      }
      resolvedAvatar = '';
    } else if (sqliteAvatar != null &&
        sqliteAvatar.trim().isNotEmpty &&
        sqliteAvatar != 'assets/images/default.png' &&
        !sqliteAvatar.contains('motor1.com')) {
      resolvedAvatar = sqliteAvatar.trim();
    }

    // ✅ সরাসরি URL ব্যবহার করো — আলাদা cache-busting দরকার নেই
    // যুক্তি: conversation.updated_at প্রতিটা message-এ পরিবর্তন হয়
    //       তাই ?v=updated_at দিলে প্রতি মেসেজে avatar re-download হয়!
    // Server নতুন avatar দিলে URL নিজেই পরিবর্তন হবে → CachedNetworkImage তন নতুন দিয়ে load করবে

    final rawTitle = this['title'] as String?;
    final otherUid = this['other_user_id'] as String?;
    final String resolvedName =
        (rawTitle != null && rawTitle.trim().isNotEmpty && rawTitle != 'null')
        ? rawTitle.trim()
        : (chatType == 'GROUP'
            ? 'Group Chat'
            : (otherUid != null && otherUid.isNotEmpty
                ? (otherUid.length > 8
                    ? 'User ${otherUid.substring(0, 8)}'
                    : 'User $otherUid')
                : 'Chat'));

    return ChatModel(
      id: this['id'] as String,
      userId: otherUid,
      name: resolvedName,
      message: this['last_message_preview'] ?? 'New Chat',
      image: resolvedAvatar,
      time: formattedTime,
      unreadCount: (this['unread_count'] as num?)?.toInt() ?? 0,
      isOnline: (this['is_online'] as num?)?.toInt() == 1,
      isMuted: (this['is_muted'] as num?)?.toInt() == 1,
      isRead: ((this['unread_count'] as num?)?.toInt() ?? 0) == 0,
      isPinned: (this['is_pinned'] as num?)?.toInt() == 1,
      draft: this['draft']?.toString(),
      lastActive: this['last_active_at'] as String?,
      type: chatType,
      memberAvatars: memberAvatars,
    );
  }
}
