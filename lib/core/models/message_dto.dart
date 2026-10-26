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
  final String? replyToJson;
  final String? reactionsJson;
  final String? attachmentsJson;
  final String? mediaUrl;
  final bool isPinned;
  final String? pinnedAt;

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
    this.replyToJson,
    this.reactionsJson,
    this.attachmentsJson,
    this.mediaUrl,
    this.isPinned = false,
    this.pinnedAt,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    String? extractedMediaUrl = _asString(json['mediaUrl']);
    String? attachmentsStr;
    if (json['attachments'] != null) {
      attachmentsStr = jsonEncode(json['attachments']);
      if (extractedMediaUrl == null && json['attachments'] is List && (json['attachments'] as List).isNotEmpty) {
        final first = (json['attachments'] as List).first;
        if (first is Map) {
          extractedMediaUrl = _asString(first['url']);
        }
      }
    }

    return MessageDto(
      id: (json['id'] ?? json['messageId'])?.toString() ?? '',
      clientMsgId: _asString(json['clientMsgId'] ?? json['client_msg_id']),
      conversationId: (json['chatId'] ?? json['conversationId'])?.toString() ?? '',
      seq: _asInt(json['seq']),
      senderId: (json['senderId'] ?? (json['sender'] is Map ? (json['sender']['id'] ?? json['sender']['_id']) : null))?.toString() ?? '',
      type: (_asString(json['type']) ?? 'TEXT').toUpperCase(),
      text: _asString(json['text']),
      status: (_asString(json['status']) ?? 'sent').toLowerCase(),
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      editedAt: _asString(json['editedAt']),
      deleted: _asBool(json['isDeleted'] ?? json['deleted']),
      replyToId: _asString(json['replyToId'] ?? json['reply_to_id']),
      replyToJson: json['replyTo'] != null ? jsonEncode(json['replyTo']) : null,
      reactionsJson: json['reactions'] != null ? jsonEncode(json['reactions']) : null,
      attachmentsJson: attachmentsStr,
      mediaUrl: extractedMediaUrl,
      isPinned: _asBool(json['isPinned'] ?? json['pinned']),
      pinnedAt: _asString(json['pinnedAt']),
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
      'reply_to_json': replyToJson,
      'reactions_json': reactionsJson,
      'attachments_json': attachmentsJson ?? (mediaUrl != null ? jsonEncode([{'url': mediaUrl, 'type': type}]) : null),
      'is_pinned': isPinned ? 1 : 0,
      'pinned_at': pinnedAt,
    };
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    return value is String ? value : value.toString();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }
}

extension MessageSqliteMapper on Map<String, dynamic> {
  MessageModel toMessageModel(String currentUserId) {
    final timeStr = this['created_at']?.toString();
    final dt = DateTime.tryParse(timeStr ?? '')?.toLocal() ?? DateTime.now();
    final formattedTime = DateFormat('hh:mm a').format(dt);
    
    final senderId = (this['sender_id'] as String?) ?? '';
    final isMe = currentUserId.isNotEmpty && senderId == currentUserId;

    MessageStatus msgStatus;
    final statusStr = (this['status'] as String?)?.toLowerCase() ?? 'sent';
    switch (statusStr) {
      case 'queued':
        msgStatus = MessageStatus.queued;
        break;
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
          parsedReactions = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
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
          mediaUrl = decoded.first['url']?.toString();
        }
      } catch (_) {}
    }

    ReplyMessageModel? parsedReplyTo;
    if (this['reply_to_json'] != null) {
      try {
        final decoded = jsonDecode(this['reply_to_json']);
        if (decoded is Map<String, dynamic>) {
          parsedReplyTo = ReplyMessageModel.fromJson(decoded);
        }
      } catch (_) {}
    }

    final typeStr = (this['type'] as String?)?.toUpperCase() ?? 'TEXT';
    final msgType = messageTypeFromWire(typeStr);

    final bool isDeleted = this['deleted'] == 1 || this['deleted'] == true || this['is_deleted'] == 1 || this['isDeleted'] == true;

    return MessageModel(
      id: this['id']?.toString() ?? '',
      text: this['text']?.toString() ?? (msgType == MessageType.unknown ? 'Unsupported message' : ''),
      time: formattedTime,
      timestamp: dt,
      isMe: isMe,
      status: msgStatus,
      senderId: senderId,
      type: msgType,
      mediaUrl: mediaUrl,
      isDeleted: isDeleted,
      reactions: parsedReactions,
      replyToMessageId: this['reply_to_id']?.toString(),
      replyToMessage: parsedReplyTo,
      seq: MessageDto._asInt(this['seq']),
      isPinned: this['is_pinned'] == 1 || this['is_pinned'] == true,
      pinnedAt: this['pinned_at']?.toString(),
    );
  }
}
