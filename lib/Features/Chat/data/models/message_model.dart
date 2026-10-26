// message_model.dart

enum MessageStatus {
  queued,   // Persisted locally and waiting for a connection
  sending,  // Message is being sent
  sent,     // Message sent to server
  delivered, // Message delivered to recipient
  seen,     // Message seen by recipient
  failed,   // Message failed to send
}

class ReplyMessageModel {
  final String id;
  final String text;
  final String? senderId;
  final bool isDeleted;
  final String? type;       // e.g. 'IMAGE', 'VIDEO', 'AUDIO', 'FILE', 'TEXT'
  final String? mediaUrl;   // thumbnail URL for image/video replies

  ReplyMessageModel({
    required this.id,
    required this.text,
    this.senderId,
    this.isDeleted = false,
    this.type,
    this.mediaUrl,
  });

  factory ReplyMessageModel.fromJson(Map<String, dynamic> json) {
    // Resolve mediaUrl — server may send it directly or inside attachments[].
    String? mediaUrl = json['mediaUrl']?.toString();
    if (mediaUrl == null) {
      final attachments = json['attachments'];
      if (attachments is List && attachments.isNotEmpty && attachments.first is Map) {
        mediaUrl = attachments.first['url']?.toString();
      }
    }

    return ReplyMessageModel(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      senderId: json['senderId']?.toString(),
      isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1,
      type: json['type']?.toString(),
      mediaUrl: mediaUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'senderId': senderId,
      'isDeleted': isDeleted,
      if (type != null) 'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReplyMessageModel &&
        other.id == id &&
        other.text == text &&
        other.senderId == senderId &&
        other.isDeleted == isDeleted &&
        other.type == type &&
        other.mediaUrl == mediaUrl;
  }

  @override
  int get hashCode => Object.hash(id, text, senderId, isDeleted, type, mediaUrl);
}

class MessageModel {
  final String id;
  final String text;
  final String time;           // Display time (e.g., "Now", "1 min ago", "10:48 AM")
  final DateTime timestamp;    // Actual timestamp for calculations
  final bool isMe;
  final MessageStatus status;

  // Optional fields for future features
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final MessageType type;      // text, image, video, file, etc.
  final String? mediaUrl;
  final bool isEdited;
  final bool isDeleted;
  final bool? isPinned;
  final String? pinnedAt;
  final String? replyToMessageId;
  final ReplyMessageModel? replyToMessage;
  final List<Map<String, dynamic>>? reactions;
  final int? seq;

  MessageModel({
    required this.id,
    required this.text,
    required this.time,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sent,  // ✅ Default value
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.type = MessageType.text,
    this.mediaUrl,
    this.isEdited = false,
    this.isDeleted = false,
    this.isPinned = false,
    this.pinnedAt,
    this.replyToMessageId,
    this.replyToMessage,
    this.reactions,
    this.seq,
  });

  // Copy with method for immutable updates
  MessageModel copyWith({
    String? id,
    String? text,
    String? time,
    DateTime? timestamp,
    bool? isMe,
    MessageStatus? status,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    String? mediaUrl,
    bool? isEdited,
    bool? isDeleted,
    bool? isPinned,
    String? pinnedAt,
    String? replyToMessageId,
    ReplyMessageModel? replyToMessage,
    List<Map<String, dynamic>>? reactions,
    int? seq,
  }) {
    return MessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      time: time ?? this.time,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      status: status ?? this.status,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      reactions: reactions ?? this.reactions,
      seq: seq ?? this.seq,
    );
  }

  // Convert to JSON (for API/database)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'time': time,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
      'status': status.name,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'pinnedAt': pinnedAt,
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage?.toJson(),
      'reactions': reactions,
      'seq': seq,
    };
  }

  // Create from JSON
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final parsedTimestamp = DateTime.tryParse(json['timestamp']?.toString() ?? '');
    return MessageModel(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      timestamp: (parsedTimestamp ?? DateTime.now()).toLocal(),
      isMe: json['isMe'] as bool? ?? false,
      status: MessageStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      senderId: json['senderId']?.toString(),
      senderName: json['senderName']?.toString(),
      senderAvatar: json['senderAvatar']?.toString(),
      type: messageTypeFromWire(json['type']?.toString()),
      mediaUrl: json['mediaUrl']?.toString(),
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      pinnedAt: json['pinnedAt'] as String?,
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToMessage: json['replyToMessage'] != null
          ? ReplyMessageModel.fromJson(json['replyToMessage'])
          : null,
      reactions: json['reactions'] != null 
          ? List<Map<String, dynamic>>.from(json['reactions']) 
          : null,
      seq: json['seq'] as int?,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, text: $text, time: $time, status: $status, seq: $seq)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && 
           other.id == id && 
           other.status == status && 
           other.text == text && 
           other.isDeleted == isDeleted && 
           other.isEdited == isEdited &&
           other.isMe == isMe &&
           other.time == time &&
           other.timestamp == timestamp &&
           other.senderId == senderId &&
           other.seq == seq &&
           _reactionsEqual(other.reactions, reactions);
  }

  bool _reactionsEqual(List<Map<String, dynamic>>? a, List<Map<String, dynamic>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.toString() == b.toString();
  }

  @override
  int get hashCode => Object.hash(id, status, text, isDeleted, isEdited, isMe, time, timestamp, senderId, seq, reactions?.toString());
}

// Message types for future features
enum MessageType {
  text,
  image,
  video,
  gif,
  audio,
  voice,
  file,
  poll,
  system,
  deleted,
  edited,
  reply,
  location,
  contact,
  sticker,
  unknown,
}

MessageType messageTypeFromWire(String? value) {
  switch (value?.toUpperCase()) {
    case 'TEXT': return MessageType.text;
    case 'IMAGE': return MessageType.image;
    case 'VIDEO': return MessageType.video;
    case 'GIF': return MessageType.gif;
    case 'AUDIO': return MessageType.audio;
    case 'VOICE': return MessageType.voice;
    case 'FILE': return MessageType.file;
    case 'POLL': return MessageType.poll;
    case 'SYSTEM': return MessageType.system;
    case 'DELETED': return MessageType.deleted;
    case 'EDITED': return MessageType.edited;
    case 'REPLY': return MessageType.reply;
    case 'LOCATION': return MessageType.location;
    case 'CONTACT': return MessageType.contact;
    case 'STICKER': return MessageType.sticker;
    default: return MessageType.unknown;
  }
}
