// message_model.dart

enum MessageStatus {
  sending,  // Message is being sent
  sent,     // Message sent to server
  delivered, // Message delivered to recipient
  seen,     // Message seen by recipient
  failed,   // Message failed to send
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
  final String? replyToMessageId;

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
    this.replyToMessageId,
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
    String? replyToMessageId,
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
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
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
      'replyToMessageId': replyToMessageId,
    };
  }

  // Create from JSON
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      time: json['time'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isMe: json['isMe'] as bool,
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
      replyToMessageId: json['replyToMessageId'] as String?,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, text: $text, time: $time, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && 
           other.id == id && 
           other.status == status && 
           other.text == text && 
           other.isDeleted == isDeleted && 
           other.isEdited == isEdited;
  }

  @override
  int get hashCode => Object.hash(id, status, text, isDeleted, isEdited);
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