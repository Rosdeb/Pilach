import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/constants/app_constants.dart';
import '../providers/chat_provider.dart';

class IOSSearchBar extends ConsumerWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final EdgeInsetsGeometry? margin;

  const IOSSearchBar({
    super.key,
    this.controller,
    this.hintText = "Search",
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(chatSearchProviders);
    final theme = Theme.of(context);

    return Container(
      height: 38,
      margin: margin ?? EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium,vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.12),
          width: 1
        )
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
              readOnly: readOnly,
              onTap: onTap,
              autofocus: autofocus,
              onChanged: (value) {
                ref.read(chatSearchProviders.notifier).state = value;
                onChanged?.call(value);
              },
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: hintText,
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
                ref.read(chatSearchProviders.notifier).state = '';
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