class ChatModel {
  final String name;
  final String message;
  final String image;
  final String time;
  final int unreadCount;
  final bool isOnline;

  ChatModel({
    required this.name,
    required this.message,
    required this.image,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
  });
}