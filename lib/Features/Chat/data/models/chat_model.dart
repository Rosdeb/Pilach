class ChatModel {
  final String id;
  final String? userId; // For private chats
  final String name;
  final String message;
  final String image;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final bool isMuted;
  final bool isRead;
  final String? draft;
  final bool isPinned;
  final String? lastActive;
  final String type;

  bool get isGroup => type.toUpperCase() == 'GROUP';

  ChatModel({
    required this.id,
    this.userId,
    required this.name,
    required this.message,
    required this.image,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    this.isMuted = false,
    this.isRead = false,
    this.draft,
    this.isPinned = false,
    this.lastActive,
    this.type = 'PRIVATE',
  });

  ChatModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? message,
    String? image,
    String? time,
    int? unreadCount,
    bool? isOnline,
    bool? isMuted,
    bool? isRead,
    String? draft,
    bool clearDraft = false,
    bool? isPinned,
    String? lastActive,
    String? type,
  }) {
    return ChatModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      message: message ?? this.message,
      image: image ?? this.image,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isMuted: isMuted ?? this.isMuted,
      isRead: isRead ?? this.isRead,
      draft: clearDraft ? null : (draft ?? this.draft),
      isPinned: isPinned ?? this.isPinned,
      lastActive: lastActive ?? this.lastActive,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatModel &&
        other.id == id &&
        other.userId == userId &&
        other.name == name &&
        other.message == message &&
        other.image == image &&
        other.time == time &&
        other.unreadCount == unreadCount &&
        other.isOnline == isOnline &&
        other.isMuted == isMuted &&
        other.isRead == isRead &&
        other.draft == draft &&
        other.isPinned == isPinned &&
        other.lastActive == lastActive;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    message,
    image,
    time,
    unreadCount,
    isOnline,
    isMuted,
    isRead,
    draft,
    isPinned,
    lastActive,
  );
}
