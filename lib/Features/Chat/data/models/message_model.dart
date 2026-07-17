// message_model.dart

enum MessageStatus {
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

  ReplyMessageModel({
    required this.id,
    required this.text,
    this.senderId,
    this.isDeleted = false,
  });

  factory ReplyMessageModel.fromJson(Map<String, dynamic> json) {
    return ReplyMessageModel(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      senderId: json['senderId'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'senderId': senderId,
      'isDeleted': isDeleted,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReplyMessageModel &&
        other.id == id &&
        other.text == text &&
        other.senderId == senderId &&
        other.isDeleted == isDeleted;
  }

  @override
  int get hashCode => Object.hash(id, text, senderId, isDeleted);
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
    return MessageModel(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      time: json['time'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      isMe: json['isMe'] as bool? ?? false,
      status: MessageStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      senderId: json['senderId'] as String?,
      senderName: json['senderName'] as String?,
      senderAvatar: json['senderAvatar'] as String?,
      type: MessageType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: json['mediaUrl'] as String?,
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
  audio,
  file,
  location,
  contact,
  sticker,
}