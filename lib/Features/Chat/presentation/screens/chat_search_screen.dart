import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_tile.dart';
import '../widgets/search_bar_widget.dart';

class ChatSearchScreen extends ConsumerStatefulWidget {
  const ChatSearchScreen({super.key});

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          padding: const EdgeInsets.only(left: 16),
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: IOSSearchBar(
          controller: _searchController,
          autofocus: true,
          margin: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10, left: 8.0),
        ),
      ),
      body: const _SearchResultsBody(),
    );
  }
}

class _SearchResultsBody extends ConsumerWidget {
  const _SearchResultsBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allChats = ref.watch(chatProvider);
    final searchQuery = ref.watch(chatSearchProviders).toLowerCase();

    if (searchQuery.isEmpty) {
      return Center(
        child: Text(
          "Search for chats and messages",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
      );
    }

    final filteredChats = allChats.where((chat) {
      return chat.name.toLowerCase().contains(searchQuery);
    }).toList();

    if (filteredChats.isEmpty) {
      return Center(
        child: Text(
          "No results found",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: filteredChats.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(left: 68.0),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: theme.dividerColor.withOpacity(0.12),
        ),
      ),
      itemBuilder: (context, index) {
        // Use const or keys to ensure recycling efficiency where applicable.
        return ChatTile(key: ValueKey(filteredChats[index].name), chat: filteredChats[index]);
      },
    );
  }
}
