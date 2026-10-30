import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../Chat/data/models/chat_model.dart';
import '../../../Chat/presentation/providers/chat_provider.dart';

class ContactItem {
  final String id;
  final String name;
  final String status;
  final String? avatarUrl;
  final String? lastMessage;
  final String? conversationId;
  final bool isOnline;

  ContactItem({
    required this.id,
    required this.name,
    required this.status,
    this.avatarUrl,
    this.lastMessage,
    this.conversationId,
    this.isOnline = false,
  });

  // Helper to extract the first letter uppercase for alphabetical clustering
  String get firstLetter => name.isNotEmpty ? name[0].toUpperCase() : '#';
}

// 1. Search Query Provider
final contactSearchProvider = StateProvider<String>((ref) => '');

// 2. Backend-derived contacts from user's conversation list.
// For private conversations, the other user is an eligible contact/group member.
// Their member ID must be chat.userId. A conversation ID is a different UUID
// and must never be sent as CreateConversationDto.userIds[].
List<ContactItem> extractEligibleContacts(List<ChatModel> chats) {
  final contactsByMemberId = <String, ContactItem>{};

  for (final chat in chats) {
    if (chat.isGroup) continue;

    final memberId = chat.userId?.trim();
    if (memberId == null || memberId.isEmpty) continue;

    final displayName = chat.name.trim().isNotEmpty
        ? chat.name.trim()
        : (memberId.length > 8
              ? 'User ${memberId.substring(0, 8)}'
              : 'User $memberId');

    final lastMsg = chat.message.trim();
    final statusText = lastMsg.isNotEmpty
        ? lastMsg
        : (chat.isOnline ? 'Online' : (chat.lastActive ?? 'Available'));

    contactsByMemberId[memberId] = ContactItem(
      id: memberId,
      name: displayName,
      status: statusText,
      avatarUrl: chat.image,
      lastMessage: lastMsg.isNotEmpty ? lastMsg : null,
      conversationId: chat.id,
      isOnline: chat.isOnline,
    );
  }

  final contacts = contactsByMemberId.values.toList(growable: false);
  contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return contacts;
}

final masterContactsProvider = Provider<List<ContactItem>>((ref) {
  final chats = ref.watch(chatProvider);
  return extractEligibleContacts(chats);
});

// 3. Filtered & Sorted Grouped Contacts Provider
final groupedContactsProvider = Provider<Map<String, List<ContactItem>>>((ref) {
  final contacts = ref.watch(masterContactsProvider);
  final searchQuery = ref.watch(contactSearchProvider).toLowerCase();

  // Filter based on search query
  final filteredList = contacts.where((contact) {
    return contact.name.toLowerCase().contains(searchQuery) ||
        contact.status.toLowerCase().contains(searchQuery) ||
        contact.id.toLowerCase().contains(searchQuery);
  }).toList();

  // Sort alphabetically
  filteredList.sort((a, b) => a.name.compareTo(b.name));

  // Group by first letter
  final Map<String, List<ContactItem>> grouped = {};
  for (var contact in filteredList) {
    final letter = contact.firstLetter;
    if (!grouped.containsKey(letter)) {
      grouped[letter] = [];
    }
    grouped[letter]!.add(contact);
  }

  return grouped;
});
