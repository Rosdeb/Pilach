Map<String, dynamic> mergeMessageRows(
  Map<String, dynamic> incoming,
  Map<String, dynamic> existing,
) {
  final merged = Map<String, dynamic>.from(existing);

  incoming.forEach((key, value) {
    if (value == null) {
      return;
    }

    if (key == 'text' && (value as String).isEmpty) {
      return;
    }

    if (key == 'reply_to_json' && (value is String) && value.isEmpty) {
      return;
    }

    if (key == 'reactions_json' && (value is String) && value.isEmpty) {
      return;
    }

    if (key == 'attachments_json' && (value is String) && value.isEmpty) {
      return;
    }

    merged[key] = value;
  });

  return merged;
}
