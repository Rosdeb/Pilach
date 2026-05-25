import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class ContactItem {
  final String id;
  final String name;
  final String status;
  final String? avatarUrl;

  ContactItem({required this.id, required this.name, required this.status, this.avatarUrl});

  // Helper to extract the first letter uppercase for alphabetical clustering
  String get firstLetter => name.isNotEmpty ? name[0].toUpperCase() : '#';
}

// 1. Search Query Provider
final contactSearchProvider = StateProvider<String>((ref) => '');

// 2. Master Contact List Provider
class ContactListNotifier extends StateNotifier<List<ContactItem>> {
  ContactListNotifier() : super([
    ContactItem(id: '1', name: 'Alex Rivera', status: 'Hey there! Using Koch Chat.', avatarUrl: 'https://i.pravatar.cc/150?img=60'),
    ContactItem(id: '2', name: 'Amara Okafor', status: 'Working remotely 🏡', avatarUrl: 'https://i.pravatar.cc/150?img=47'),
    ContactItem(id: '3', name: 'Ben Kingston', status: 'Available for calls', avatarUrl: null), // Will show initials background
    ContactItem(id: '4', name: 'Caleb Wright', status: 'In a meeting', avatarUrl: 'https://i.pravatar.cc/150?img=33'),
    ContactItem(id: '5', name: 'Chloe Wang', status: 'Busy 💻', avatarUrl: null),
    ContactItem(id: '6', name: 'Diana Prince', status: 'Always learning!', avatarUrl: 'https://i.pravatar.cc/150?img=41'),
  ]);
}

final masterContactsProvider = StateNotifierProvider<ContactListNotifier, List<ContactItem>>((ref) {
  return ContactListNotifier();
});

// 3. Filtered & Sorted Grouped Contacts Provider
final groupedContactsProvider = Provider<Map<String, List<ContactItem>>>((ref) {
  final contacts = ref.watch(masterContactsProvider);
  final searchQuery = ref.watch(contactSearchProvider).toLowerCase();

  // Filter based on search query
  final filteredList = contacts.where((contact) {
    return contact.name.toLowerCase().contains(searchQuery) ||
        contact.status.toLowerCase().contains(searchQuery);
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