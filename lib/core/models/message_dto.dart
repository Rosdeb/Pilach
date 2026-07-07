import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';

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
  final String? reactionsJson;
  final String? attachmentsJson;
  final String? mediaUrl;

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
    this.reactionsJson,
    this.attachmentsJson,
    this.mediaUrl,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    String? extractedMediaUrl = json['mediaUrl'] as String?;
    String? attachmentsStr;
    if (json['attachments'] != null) {
      attachmentsStr = jsonEncode(json['attachments']);
      if (extractedMediaUrl == null && json['attachments'] is List && (json['attachments'] as List).isNotEmpty) {
        final first = (json['attachments'] as List).first;
        if (first is Map) {
          extractedMediaUrl = first['url'] as String?;
        }
      }
    }

    return MessageDto(
      id: (json['id'] ?? json['messageId'])?.toString() ?? '',
      clientMsgId: json['clientMsgId'] as String?,
      conversationId: (json['chatId'] ?? json['conversationId'])?.toString() ?? '',
      seq: json['seq'] as int?,
      senderId: json['senderId']?.toString() ?? '',
      type: json['type'] as String? ?? 'TEXT',
      text: json['text'] as String?,
      status: json['status'] as String? ?? 'sent',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      editedAt: json['editedAt'] as String?,
      deleted: (json['isDeleted'] ?? json['deleted']) as bool? ?? false,
      replyToId: json['replyToId'] as String?,
      reactionsJson: json['reactions'] != null ? jsonEncode(json['reactions']) : null,
      attachmentsJson: attachmentsStr,
      mediaUrl: extractedMediaUrl,
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
      'reactions_json': reactionsJson,
      'attachments_json': attachmentsJson ?? (mediaUrl != null ? jsonEncode([{'url': mediaUrl, 'type': type}]) : null),
    };
  }
}

extension MessageSqliteMapper on Map<String, dynamic> {
  MessageModel toMessageModel(String currentUserId) {
    final timeStr = this['created_at'] as String;
    final dt = DateTime.parse(timeStr).toLocal();
    final formattedTime = DateFormat('hh:mm a').format(dt);
    
    final senderId = (this['sender_id'] as String?) ?? '';
    final isMe = currentUserId.isNotEmpty && senderId == currentUserId;

    MessageStatus msgStatus;
    final statusStr = (this['status'] as String?)?.toLowerCase() ?? 'sent';
    switch (statusStr) {
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
      case 'read':
        msgStatus = MessageStatus.seen;
        break;
      default:
        msgStatus = MessageStatus.sent;
    }

    List<Map<String, dynamic>>? parsedReactions;
    if (this['reactions_json'] != null) {
      try {
        final decoded = jsonDecode(this['reactions_json']);
        if (decoded is List) {
          parsedReactions = List<Map<String, dynamic>>.from(decoded);
        }
      } catch (e) {
        // ignore
      }
    }

    String? mediaUrl;
    if (this['attachments_json'] != null) {
      try {
        final decoded = jsonDecode(this['attachments_json']);
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          mediaUrl = decoded.first['url'] as String?;
        }
      } catch (_) {}
    }

    final typeStr = (this['type'] as String?)?.toUpperCase() ?? 'TEXT';
    MessageType msgType = MessageType.text;
    if (typeStr == 'IMAGE') {
      msgType = MessageType.image;
    } else if (typeStr == 'VIDEO') {
      msgType = MessageType.video;
    } else if (typeStr == 'AUDIO') {
      msgType = MessageType.audio;
    } else if (typeStr == 'FILE') {
      msgType = MessageType.file;
    }

    final bool isDeleted = this['deleted'] == 1 || this['deleted'] == true || this['is_deleted'] == 1 || this['isDeleted'] == true;

    return MessageModel(
      id: this['id'] as String,
      text: this['text'] ?? '',
      time: formattedTime,
      timestamp: dt,
      isMe: isMe,
      status: msgStatus,
      senderId: senderId,
      type: msgType,
      mediaUrl: mediaUrl,
      isDeleted: isDeleted,
      reactions: parsedReactions,
      replyToMessageId: this['reply_to_id'] as String?,
      seq: this['seq'] as int?,
    );
  }
}
