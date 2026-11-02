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
  final String? authorName;
  final String? authorAvatar;

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
    this.authorName,
    this.authorAvatar,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final authorMap = json['author'] is Map<String, dynamic>
        ? json['author'] as Map<String, dynamic>
        : (json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : null);

    final profileMap = authorMap?['profile'] is Map<String, dynamic>
        ? authorMap!['profile'] as Map<String, dynamic>
        : (json['profile'] is Map<String, dynamic>
            ? json['profile'] as Map<String, dynamic>
            : null);

    final resolvedAuthorId = (json['authorId'] ??
            json['userId'] ??
            authorMap?['id'] ??
            authorMap?['userId'] ??
            '')
        .toString();

    final resolvedAuthorName = profileMap?['name'] ??
        profileMap?['fullName'] ??
        profileMap?['displayName'] ??
        authorMap?['name'] ??
        authorMap?['username'] ??
        json['authorName'] ??
        json['userName'] ??
        json['name'];

    final resolvedAuthorAvatar = profileMap?['avatarUrl'] ??
        profileMap?['avatar'] ??
        profileMap?['image'] ??
        profileMap?['profilePicture'] ??
        authorMap?['avatarUrl'] ??
        authorMap?['avatar'] ??
        authorMap?['image'] ??
        json['authorAvatar'] ??
        json['userAvatar'] ??
        json['avatarUrl'];

    return StoryModel(
      id: (json['id'] ?? '').toString(),
      authorId: resolvedAuthorId,
      type: (json['type'] ?? 'IMAGE').toString(),
      mediaUrl: json['mediaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      caption: json['caption'] as String?,
      privacy: (json['privacy'] ?? 'EVERYONE').toString(),
      isPinned: json['isPinned'] == true,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      authorName: resolvedAuthorName?.toString(),
      authorAvatar: resolvedAuthorAvatar?.toString(),
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
      if (authorName != null) 'authorName': authorName,
      if (authorAvatar != null) 'authorAvatar': authorAvatar,
    };
  }
}
