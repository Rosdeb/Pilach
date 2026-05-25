import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/Features/Me/data/models/block_userlist.dart';

import '../../../../core/utils/app_colour.dart';
import 'block_listTile.dart';

class BlockedUserList extends ConsumerWidget {
  final List<BlockedUser> blockedUsers;

  const BlockedUserList({
    super.key,
    required this.blockedUsers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (blockedUsers.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.textWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: blockedUsers.length,
        separatorBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(left: 68),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: AppColors.background,
            ),
          );
        },
        itemBuilder: (context, index) {
          final user = blockedUsers[index];

          return BlockedUserTile(user: user);
        },
      ),
    );
  }
}