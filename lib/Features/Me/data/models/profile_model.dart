class ProfileModel {
  final String id;
  final String userId;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final dynamic metadata;
  final String createdAt;
  final String updatedAt;

  ProfileModel({
    required this.id,
    required this.userId,
    required this.name,
    this.bio,
    this.avatarUrl,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      metadata: json['metadata'],
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'metadata': metadata,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? bio,
    String? avatarUrl,
    dynamic metadata,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
