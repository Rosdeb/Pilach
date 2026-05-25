import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_colour.dart';
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

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.textWhite,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.search,
            color: AppColors.textLight,
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
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                hintText: "Search",
                hintStyle: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 15,
                ),
                fillColor: AppColors.textWhite,
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
              child: const Icon(
                CupertinoIcons.clear_circled_solid,
                color: AppColors.textLight,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}