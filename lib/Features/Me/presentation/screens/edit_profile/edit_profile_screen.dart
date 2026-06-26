import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/components/AppText/appText.dart';
import '../../../../../core/utils/app_colour.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  String? _avatarUrl;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final initialProfile = ref.read(profileNotifierProvider).value;
    _nameController = TextEditingController(text: initialProfile?.name ?? '');
    _bioController = TextEditingController(text: initialProfile?.bio ?? '');
    _emailController = TextEditingController(text: initialProfile?.userId ?? ''); // Using userId or email placeholder
    _avatarUrl = initialProfile?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final uploadedUrl = await ref.read(profileNotifierProvider.notifier).uploadAvatar(pickedFile.path);
      if (uploadedUrl != null) {
        setState(() {
          _avatarUrl = uploadedUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar uploaded successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload avatar')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await ref.read(profileNotifierProvider.notifier).updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _avatarUrl,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileState = ref.watch(profileNotifierProvider);

    // Listen for transitions from loading to data
    ref.listen<AsyncValue>(profileNotifierProvider, (previous, next) {
      if (previous == null || previous.isLoading) {
        next.whenData((profile) {
          if (profile != null) {
            _nameController.text = profile.name;
            _bioController.text = profile.bio ?? '';
            _emailController.text = profile.userId;
            setState(() {
              _avatarUrl = profile.avatarUrl;
            });
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: profileState.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (err, stack) => Scaffold(
          appBar: AppBar(
            title: const Text('Edit Profile'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading profile: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(profileNotifierProvider.notifier).fetchProfile(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- APP BAR ---
              SliverAppBar(
                pinned: true,
                floating: false,
                snap: false,
                expandedHeight: 60.0,
                toolbarHeight: 60.0,
                automaticallyImplyLeading: false,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 10,
                      sigmaY: 10,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            // Back Button
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                color: theme.colorScheme.onSurface,
                                size: 20,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            // Title
                            AppText(
                              'Edit Profile',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: TextButton.styleFrom(
                                shape: const CircleBorder(),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.all(12),
                                overlayColor: theme.colorScheme.primary.withOpacity(0.15),
                              ),
                              child: _isSaving
                                  ? const CupertinoActivityIndicator()
                                  : Text(
                                'Save',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            )

                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- BODY ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // --- PROFILE IMAGE ---
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: AppColors.background_s2,
                              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(_avatarUrl!)
                                  : null,
                              child: _avatarUrl == null || _avatarUrl!.isEmpty
                                  ? Icon(Icons.person, size: 50, color: theme.colorScheme.primary)
                                  : null,
                            ),
                            if (_isUploadingImage)
                              const Positioned.fill(
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white54,
                                  child: CupertinoActivityIndicator(color: Colors.green,),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _isUploadingImage ? null : _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.camera_fill,
                                    color: theme.colorScheme.onPrimary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                        child: Text(
                          'Change Profile Photo',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // --- FORM CARD ---
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildInputField(
                              context,
                              label: 'Name',
                              controller: _nameController,
                            ),
                            _buildDivider(context),
                            _buildInputField(
                              context,
                              label: 'User ID',
                              controller: _emailController,
                              readOnly: true,
                            ),
                            _buildDivider(context),
                            _buildInputField(
                              context,
                              label: 'Bio',
                              controller: _bioController,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              readOnly: readOnly,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(readOnly ? 0.4 : 0.7),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                fillColor: theme.colorScheme.surface,
                hintText: readOnly ? 'N/A' : 'Enter $label',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(context).dividerColor,
      ),
    );
  }
}
