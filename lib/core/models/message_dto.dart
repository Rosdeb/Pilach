import 'package:intl/intl.dart';
import '../../Features/Chat/data/models/message_model.dart';

class MessageDto {
  final String id;
  final String? clientMsgId;
  final String conversationId;
  final int? seq;
  final String senderId;
  final String type;
  final String? text;
  final String status;
  final String createdAt;
  final String? editedAt;
  final bool deleted;
  final String? replyToId;

  MessageDto({
    required this.id,
    this.clientMsgId,
    required this.conversationId,
    this.seq,
    required this.senderId,
    required this.type,
    this.text,
    required this.status,
    required this.createdAt,
    this.editedAt,
    this.deleted = false,
    this.replyToId,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    return MessageDto(
      id: json['id'] as String,
      clientMsgId: json['clientMsgId'] as String?,
      conversationId: json['conversationId'] as String,
      seq: json['seq'] as int?,
      senderId: json['senderId'] as String,
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      status: json['status'] as String? ?? 'sent',
      createdAt: json['createdAt'] as String,
      editedAt: json['editedAt'] as String?,
      deleted: json['deleted'] as bool? ?? false,
      replyToId: json['replyToId'] as String?,
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'client_msg_id': clientMsgId,
      'conversation_id': conversationId,
      'seq': seq,
      'sender_id': senderId,
      'type': type,
      'text': text,
      'status': status,
      'created_at': createdAt,
      'edited_at': editedAt,
      'deleted': deleted ? 1 : 0,
      'reply_to_id': replyToId,
    };
  }
}

extension MessageSqliteMapper on Map<String, dynamic> {
  MessageModel toMessageModel(String currentUserId) {
    final timeStr = this['created_at'] as String;
    final dt = DateTime.parse(timeStr).toLocal();
    final formattedTime = DateFormat('hh:mm a').format(dt);
    
    final senderId = this['sender_id'] as String;
    final isMe = senderId == currentUserId;

    MessageStatus msgStatus;
    switch (this['status']) {
      case 'sending':
        msgStatus = MessageStatus.sending;
        break;
      case 'failed':
        msgStatus = MessageStatus.failed;
        break;
      case 'delivered':
        msgStatus = MessageStatus.delivered;
        break;
      case 'seen':
        msgStatus = MessageStatus.seen;
        break;
      default:
        msgStatus = MessageStatus.sent;
    }

    return MessageModel(
      id: this['id'] as String,
      text: this['text'] ?? '',
      time: formattedTime,
      timestamp: dt,
      isMe: isMe,
      status: msgStatus,
      senderId: senderId,
    );
  }
}
