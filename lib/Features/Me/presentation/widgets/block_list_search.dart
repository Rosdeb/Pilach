import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/block_userlist_providers.dart';

class IOSSearchBar extends ConsumerWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const IOSSearchBar({
    super.key,
    this.controller,
    this.hintText = "Search",
    this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchbarProvider);
    final theme = Theme.of(context);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          const SizedBox(width: 6),

          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (value) {
                ref.read(searchbarProvider.notifier).state = value;

                onChanged?.call(value);
              },
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: "Search",
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 15,
                ),
                fillColor: theme.colorScheme.surface,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller?.clear();
                ref.read(searchbarProvider.notifier).state = '';
                onChanged?.call('');
              },
              child: Icon(
                CupertinoIcons.clear_circled_solid,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}