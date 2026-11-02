class BlockedUser {
  final String id;
  final String? username;
  final String? name;
  final String? avatarUrl;
  final DateTime? createdAt;

  BlockedUser({
    required this.id,
    this.username,
    this.name,
    this.avatarUrl,
    this.createdAt,
  });

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (username != null && username!.trim().isNotEmpty) return '@${username!.trim()}';
    if (id.length > 8) return 'User ${id.substring(0, 8)}';
    return 'User $id';
  }

  String? get handle => (username != null && username!.trim().isNotEmpty)
      ? '@${username!.trim()}'
      : null;

  String get email => handle ?? '';

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      username: json['username'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'avatarUrl': avatarUrl,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
