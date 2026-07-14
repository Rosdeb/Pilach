class StoryModel {
  final String id;
  final String authorId;
  final String type;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? caption;
  final String privacy;
  final bool isPinned;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  StoryModel({
    required this.id,
    required this.authorId,
    required this.type,
    this.mediaUrl,
    this.thumbnailUrl,
    this.caption,
    required this.privacy,
    this.isPinned = false,
    this.expiresAt,
    this.createdAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      type: json['type'] ?? 'IMAGE',
      mediaUrl: json['mediaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      caption: json['caption'] as String?,
      privacy: json['privacy'] ?? 'EVERYONE',
      isPinned: json['isPinned'] ?? false,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt']) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'type': type,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'privacy': privacy,
      'isPinned': isPinned,
      'expiresAt': expiresAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
