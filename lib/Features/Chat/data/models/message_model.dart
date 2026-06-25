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
