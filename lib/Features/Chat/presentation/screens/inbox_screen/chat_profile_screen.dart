import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:app/core/constants/app_paths.dart';
import 'package:app/core/utils/app_toast.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat_avatar.dart';
import '../../../../Contact/presentation/widgets/add_group_members_sheet.dart';
import '../../../../Me/data/repositories/security_repository.dart';
import 'package:app/core/network/chat_repository.dart';

class ChatProfileScreen extends ConsumerStatefulWidget {
  final ChatModel chat;

  const ChatProfileScreen({super.key, required this.chat});

  @override
  ConsumerState<ChatProfileScreen> createState() => _ChatProfileScreenState();
}

class _ChatProfileScreenState extends ConsumerState<ChatProfileScreen> {
  late ChatModel _chat;
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = false;
  bool _isUploadingPhoto = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    _loadCurrentUserId();
    if (_chat.isGroup) {
      _fetchMembers();
    }
  }

  Future<void> _pickAndUploadGroupPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final file = File(pickedFile.path);
      final uploadedUrl =
          await ref.read(chatProvider.notifier).uploadGroupAvatar(file);

      if (uploadedUrl != null && mounted) {
        final ok = await ref
            .read(chatProvider.notifier)
            .updateGroupInfo(_chat.id, avatarUrl: uploadedUrl);
        if (ok && mounted) {
          setState(() {
            _chat = _chat.copyWith(image: uploadedUrl);
          });
          AppToast.show(
            context,
            'Group photo updated',
            type: ToastType.success,
          );
        } else if (mounted) {
          AppToast.show(
            context,
            'Failed to update group metadata',
            type: ToastType.error,
          );
        }
      } else if (mounted) {
        AppToast.show(context, 'Failed to upload photo', type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Error updating group photo: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('user_id') ?? '';
      });
    }
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final members = await ref.read(chatProvider.notifier).getGroupMembers(_chat.id);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  bool get _isCurrentUserAdminOrOwner {
    if (_currentUserId.isEmpty) return false;
    final myMember = _members.firstWhere(
      (m) => (m['userId'] ?? m['user']?['id']) == _currentUserId,
      orElse: () => const {},
    );
    final role = myMember['role']?.toString().toUpperCase();
    return role == 'OWNER' || role == 'ADMIN';
  }

  bool get _isCurrentUserOwner {
    if (_currentUserId.isEmpty) return false;
    final myMember = _members.firstWhere(
      (m) => (m['userId'] ?? m['user']?['id']) == _currentUserId,
      orElse: () => const {},
    );
    return myMember['role']?.toString().toUpperCase() == 'OWNER';
  }

  void _showAddMemberSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddGroupMembersBottomSheet(
        conversationId: _chat.id,
        groupTitle: _chat.name,
      ),
    );
    _fetchMembers();
  }

  void _showEditGroupNameDialog() {
    final controller = TextEditingController(text: _chat.name);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Edit Group Name'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Group Name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(chatProvider.notifier)
                  .updateGroupInfo(_chat.id, title: newName);
              if (success && mounted) {
                setState(() {
                  _chat = _chat.copyWith(name: newName);
                });
                AppToast.show(context, 'Group name updated', type: ToastType.success);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showMemberActionSheet(Map<String, dynamic> member) {
    final memberUserId = (member['userId'] ?? member['user']?['id'])?.toString() ?? '';
    final memberName = member['user']?['profile']?['name'] ??
        member['user']?['username'] ??
        'Member';
    final role = member['role']?.toString().toUpperCase() ?? 'MEMBER';

    if (memberUserId == _currentUserId) return;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(memberName),
        message: Text('Role: $role'),
        actions: [
          if (_isCurrentUserOwner && role != 'OWNER')
            CupertinoActionSheetAction(
              child: const Text('Transfer Ownership'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _confirmTransferOwnership(memberUserId, memberName);
              },
            ),
          if (role == 'MEMBER')
            CupertinoActionSheetAction(
              child: const Text('Promote to Admin'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final ok = await ref
                    .read(chatProvider.notifier)
                    .updateMemberRoleInConversation(_chat.id, memberUserId, role: 'ADMIN');
                if (ok && mounted) {
                  AppToast.show(context, 'Promoted $memberName to Admin', type: ToastType.success);
                  _fetchMembers();
                }
              },
            )
          else if (role == 'ADMIN' && _isCurrentUserOwner)
            CupertinoActionSheetAction(
              child: const Text('Demote to Member'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final ok = await ref
                    .read(chatProvider.notifier)
                    .updateMemberRoleInConversation(_chat.id, memberUserId, role: 'MEMBER');
                if (ok && mounted) {
                  AppToast.show(context, 'Demoted $memberName to Member', type: ToastType.success);
                  _fetchMembers();
                }
              },
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Remove from Group'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmRemoveMember(memberUserId, memberName);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _confirmRemoveMember(String userId, String memberName) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Remove $memberName?'),
        content: Text('Are you sure you want to remove $memberName from "${_chat.name}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Remove'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(chatProvider.notifier)
                  .removeMemberFromConversation(_chat.id, userId);
              if (success && mounted) {
                AppToast.show(context, 'Removed $memberName from group', type: ToastType.success);
                _fetchMembers();
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmTransferOwnership(String userId, String memberName) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Transfer Ownership to $memberName?'),
        content: Text(
          'You will no longer be the owner of "${_chat.name}". This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Transfer'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(chatRepositoryProvider).transferOwnership(_chat.id, userId);
                if (mounted) {
                  AppToast.show(context, 'Ownership transferred to $memberName', type: ToastType.success);
                  _fetchMembers();
                }
              } catch (_) {
                if (mounted) {
                  AppToast.show(context, 'Failed to transfer ownership', type: ToastType.error);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Leave "${_chat.name}"?'),
        content: const Text(
          'Are you sure you want to leave this group? You will no longer receive any messages or updates.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Leave'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref.read(chatProvider.notifier).leaveGroupConversation(_chat.id);
              if (ok && mounted) {
                AppToast.show(context, 'You left the group', type: ToastType.success);
                context.pop();
                context.pop(); // Pop back to chat list
              }
            },
          ),
        ],
      ),
    );
  }

  void _toggleMute() {
    final nextMute = !_chat.isMuted;
    ref.read(chatProvider.notifier).muteConversation(_chat.id, nextMute);
    setState(() {
      _chat = _chat.copyWith(isMuted: nextMute);
    });
    AppToast.show(
      context,
      nextMute ? 'Conversation muted' : 'Conversation unmuted',
      type: ToastType.info,
    );
  }

  void _confirmBlockUser() {
    final otherId = _chat.userId;
    if (otherId == null || otherId.isEmpty) return;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Block ${_chat.name}?'),
        content: Text(
          'Blocked contacts will no longer be able to message or call you.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Block'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(securityRepositoryProvider).blockUser(otherId);
                if (mounted) {
                  AppToast.show(context, 'Blocked ${_chat.name}', type: ToastType.success);
                }
              } catch (_) {
                if (mounted) {
                  AppToast.show(context, 'Failed to block user', type: ToastType.error);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_chat.isGroup && _isCurrentUserAdminOrOwner)
            IconButton(
              icon: Icon(CupertinoIcons.pencil, color: theme.colorScheme.primary, size: 20),
              tooltip: 'Edit Group Name',
              onPressed: _showEditGroupNameDialog,
            ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // --- Avatar & Identity ---
                Center(
                  child: Stack(
                    children: [
                      ChatAvatar(
                        radius: 50,
                        imageUrl: _chat.image,
                        memberAvatars: _chat.memberAvatars,
                        isGroup: _chat.isGroup,
                        isOnline: _chat.isOnline && !_chat.isGroup,
                        onlineColor: const Color(0xFF34C759),
                        borderColor: theme.scaffoldBackgroundColor,
                      ),
                      if (_isUploadingPhoto)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CupertinoActivityIndicator(
                                radius: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (_chat.isGroup &&
                          _isCurrentUserAdminOrOwner &&
                          !_isUploadingPhoto)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadGroupPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.camera_fill,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppText(
                  _chat.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  _chat.isGroup
                      ? '${_members.isNotEmpty ? _members.length : _chat.memberAvatars.length} members'
                      : 'Active now',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Action Buttons ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_chat.isGroup)
                      _buildActionButton(
                        context,
                        CupertinoIcons.person_badge_plus,
                        'Add Member',
                        _showAddMemberSheet,
                      )
                    else
                      _buildActionButton(
                        context,
                        CupertinoIcons.search,
                        'Search',
                        () => context.push(AppPaths.chat_search),
                      ),
                    _buildActionButton(
                      context,
                      _chat.isMuted ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
                      _chat.isMuted ? 'Unmute' : 'Mute',
                      _toggleMute,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // --- Group Members Roster Section ---
          if (_chat.isGroup) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      'Group Members (${_members.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (_isLoadingMembers)
                      const CupertinoActivityIndicator(radius: 8)
                    else
                      GestureDetector(
                        onTap: _showAddMemberSheet,
                        child: Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSectionGroup(
                context,
                [
                  if (_members.isEmpty && !_isLoadingMembers)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No members found',
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  for (final member in _members) _buildMemberTile(context, member),
                ],
              ),
            ),
          ],

          // --- Customization Settings ---
          SliverToBoxAdapter(
            child: _buildSectionGroup(context, [
              if (_chat.isGroup && _isCurrentUserAdminOrOwner) ...[
                _buildSettingTile(
                  context,
                  CupertinoIcons.camera_fill,
                  'Change Group Photo',
                  Colors.teal,
                  onTap: _pickAndUploadGroupPhoto,
                ),
                _buildSettingTile(
                  context,
                  CupertinoIcons.pencil,
                  'Edit Group Name',
                  Colors.blue,
                  onTap: _showEditGroupNameDialog,
                ),
              ],
              _buildSettingTile(
                context,
                _chat.isMuted ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
                _chat.isMuted ? 'Unmute Conversation' : 'Mute Conversation',
                _chat.isMuted ? Colors.green : Colors.orange,
                onTap: _toggleMute,
              ),
              _buildSettingTile(
                context,
                CupertinoIcons.search,
                'Search in Conversation',
                theme.colorScheme.onSurface,
                onTap: () => context.push(AppPaths.chat_search),
              ),
            ]),
          ),

          // --- Media ---
          SliverToBoxAdapter(
            child: _buildSectionGroup(context, [
              _buildSettingTile(
                context,
                CupertinoIcons.photo_on_rectangle,
                'View Photos & Videos',
                Colors.teal,
                onTap: () => AppToast.show(
                  context,
                  'Photos & Videos gallery available in chat',
                  type: ToastType.info,
                ),
              ),
              _buildSettingTile(
                context,
                CupertinoIcons.folder_fill,
                'Files & Links',
                Colors.indigo,
                onTap: () => AppToast.show(
                  context,
                  'Files & Links available in chat',
                  type: ToastType.info,
                ),
              ),
            ]),
          ),

          // --- Leave Group / Block ---
          SliverToBoxAdapter(
            child: _buildSectionGroup(context, [
              if (_chat.isGroup)
                _buildSettingTile(
                  context,
                  CupertinoIcons.square_arrow_right,
                  'Leave Group',
                  Colors.red,
                  isDestructive: true,
                  onTap: _confirmLeaveGroup,
                )
              else ...[
                _buildSettingTile(
                  context,
                  CupertinoIcons.nosign,
                  'Block ${_chat.name}',
                  Colors.red,
                  isDestructive: true,
                  onTap: _confirmBlockUser,
                ),
                _buildSettingTile(
                  context,
                  CupertinoIcons.flag_fill,
                  'Report User',
                  Colors.red,
                  isDestructive: true,
                  onTap: () => AppToast.show(context, 'Report submitted', type: ToastType.info),
                ),
              ],
            ]),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, Map<String, dynamic> member) {
    final theme = Theme.of(context);
    final memberUserId = (member['userId'] ?? member['user']?['id'])?.toString() ?? '';
    final memberName = member['user']?['profile']?['name'] ??
        member['user']?['username'] ??
        'Group Member';
    final avatarUrl = member['user']?['profile']?['avatarUrl'] as String?;
    final role = member['role']?.toString().toUpperCase() ?? 'MEMBER';
    final isMe = memberUserId == _currentUserId;
    final canManageThisMember = _isCurrentUserAdminOrOwner && !isMe;

    Color badgeColor;
    String badgeText;
    switch (role) {
      case 'OWNER':
        badgeColor = const Color(0xFFFF9500);
        badgeText = 'Owner';
        break;
      case 'ADMIN':
        badgeColor = const Color(0xFF007AFF);
        badgeText = 'Admin';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = 'Member';
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? NetworkImage(avatarUrl)
            : null,
        child: (avatarUrl == null || avatarUrl.isEmpty)
            ? Text(
                memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isMe ? '$memberName (You)' : memberName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (role == 'OWNER' || role == 'ADMIN') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: member['user']?['username'] != null
          ? Text(
              '@${member['user']!['username']}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: canManageThisMember
          ? IconButton(
              icon: Icon(
                CupertinoIcons.ellipsis,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 18,
              ),
              onPressed: () => _showMemberActionSheet(member),
            )
          : null,
      onTap: canManageThisMember ? () => _showMemberActionSheet(member) : null,
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          AppText(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionGroup(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    IconData icon,
    String title,
    Color iconColor, {
    String? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final textColor = isDestructive ? Colors.red : theme.colorScheme.onSurface;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: AppText(
        title,
        style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.w400),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            AppText(
              trailing,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          if (trailing != null) const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }
}
