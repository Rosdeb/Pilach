/// Status hierarchy ranking: statuses can only advance forward in time.
int _statusRank(dynamic status) {
  final s = status?.toString().toLowerCase();
  switch (s) {
    case 'queued':
      return 1;
    case 'sending':
      return 2;
    case 'failed':
      return 2;
    case 'sent':
      return 3;
    case 'delivered':
      return 4;
    case 'seen':
    case 'read':
      return 5;
    default:
      return 0;
  }
}

/// Merges incoming message data with existing local SQLite message data.
/// Resolves conflicts across multiple devices using:
/// 1. Tombstone supremacy: deleted messages remain deleted.
/// 2. Monotonic status progression: delivery/seen receipts never regress.
/// 3. Last-Write-Wins (LWW) for text edits based on `edited_at` timestamps.
/// 4. Authoritative server reaction snapshots (including removals).
Map<String, dynamic> mergeMessageRows(
  Map<String, dynamic> incoming,
  Map<String, dynamic> existing,
) {
  final merged = Map<String, dynamic>.from(existing);

  // 1. Tombstone supremacy: If already deleted locally, keep it deleted.
  final existingDeleted =
      existing['deleted'] == 1 || existing['deleted'] == true;
  final incomingDeleted =
      incoming['deleted'] == 1 || incoming['deleted'] == true;
  if (existingDeleted && !incomingDeleted) {
    // Preserve deletion tombstone
    merged['deleted'] = 1;
  } else if (incomingDeleted) {
    merged['deleted'] = 1;
  }

  // 2. Check edit timestamp for text edits (LWW)
  final existingEditedAt = existing['edited_at']?.toString();
  final incomingEditedAt = incoming['edited_at']?.toString();
  bool useIncomingText = true;

  if (existingEditedAt != null && incomingEditedAt != null) {
    try {
      final existingTime = DateTime.parse(existingEditedAt);
      final incomingTime = DateTime.parse(incomingEditedAt);
      if (incomingTime.isBefore(existingTime)) {
        // Existing is newer; do not overwrite text with older incoming edit
        useIncomingText = false;
      }
    } catch (_) {}
  } else if (existingEditedAt != null &&
      incomingEditedAt == null &&
      existing['text'] != null) {
    // Local has an edit, incoming is an unedited or stale message representation
    useIncomingText = false;
  }

  // 3. Status monotonic check
  final existingStatusRank = _statusRank(existing['status']);
  final incomingStatusRank = _statusRank(incoming['status']);
  final shouldKeepExistingStatus = existingStatusRank > incomingStatusRank;

  // 4. A non-null server reaction list is an authoritative snapshot. Unioning
  // snapshots would resurrect reactions removed on another device. Null still
  // means "field omitted", so partial socket payloads preserve local data.
  final existingReactionsJson = existing['reactions_json']?.toString();
  final incomingReactionsJson = incoming['reactions_json']?.toString();
  final mergedReactionsJson = incomingReactionsJson ?? existingReactionsJson;

  // 5. Merge remaining fields
  incoming.forEach((key, value) {
    if (value == null) return;

    if (key == 'text') {
      if ((value as String).isEmpty || !useIncomingText) return;
    }

    if (key == 'edited_at' && !useIncomingText) {
      return;
    }

    if (key == 'status' && shouldKeepExistingStatus) {
      return;
    }

    if (key == 'deleted' && existingDeleted) {
      return;
    }

    if (key == 'reactions_json') {
      return; // Handled separately
    }

    if (key == 'reply_to_json' && (value is String) && value.isEmpty) {
      return;
    }

    if (key == 'attachments_json' && (value is String) && value.isEmpty) {
      return;
    }

    if (key == 'sender_id' && (value is String) && value.isEmpty) {
      return;
    }

    merged[key] = value;
  });

  if (mergedReactionsJson != null) {
    merged['reactions_json'] = mergedReactionsJson;
  }
  if (merged['deleted'] == 1 || merged['deleted'] == true) {
    merged['text'] = '';
  }

  return merged;
}
