class ChatModel {
  final String id;
  final String name;
  final String message;
  final String image;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final bool isMuted;

  ChatModel({
    required this.id,
    required this.name,
    required this.message,
    required this.image,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    this.isMuted = false,
  });

  ChatModel copyWith({
    String? id,
    String? name,
    String? message,
    String? image,
    String? time,
    int? unreadCount,
    bool? isOnline,
    bool? isMuted,
  }) {
    return ChatModel(
      id: id ?? this.id,
      name: name ?? this.name,
      message: message ?? this.message,
      image: image ?? this.image,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}