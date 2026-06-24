import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/components/AppText/appText.dart';
import 'package:messageapp/core/constants/app_constants.dart';
import 'package:messageapp/core/utils/app_colour.dart';
import 'package:messageapp/components/PasswordTextField/password_text_field.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _currentPasswordError;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidPassword(String password) {
    // Min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char
    final regex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[\W_]).{8,}$');
    return regex.hasMatch(password);
  }

  void _submit() async {
    setState(() {
      _currentPasswordError = null;
    });

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Simulate a network request to validate current password and update
      await Future.delayed(const Duration(seconds: 1));

      setState(() => _isLoading = false);

      // --- MOCK VALIDATION: Replace with actual backend call ---
      // For demonstration, let's assume the user's current password is "CurrentPass123!"
      if (_currentPasswordController.text != "CurrentPass123!") {
        setState(() {
          _currentPasswordError = "Current password is incorrect.";
        });
        _formKey.currentState!.validate();
        return;
      }
      // --------------------------------------------------------

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password changed successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- GLASS EFFECT APP BAR ---
          SliverAppBar(
            pinned: true,
            expandedHeight: 60.0,
            toolbarHeight: 60.0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: AppText(
              "Change Password",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // --- BODY CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your new password must be unique and meet our security requirements.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // --- CURRENT PASSWORD ---
                    PasswordTextField(
                      label: 'Current Password',
                      hintText: 'Enter your current password',
                      controller: _currentPasswordController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Current password cannot be empty.';
                        }
                        if (_currentPasswordError != null) {
                          return _currentPasswordError;
                        }
                        return null;
                      },
                      onChanged: (val) {
                        if (_currentPasswordError != null) {
                          setState(() => _currentPasswordError = null);
                          _formKey.currentState!.validate();
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- NEW PASSWORD ---
                    PasswordTextField(
                      label: 'New Password',
                      hintText: 'Enter a strong new password',
                      controller: _newPasswordController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'New password cannot be empty.';
                        }
                        if (value == _currentPasswordController.text) {
                          return 'New password must be different from your current password.';
                        }
                        if (!_isValidPassword(value)) {
                          return 'Must be at least 8 chars, include an uppercase,\nlowercase, number, and special character.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- CONFIRM NEW PASSWORD ---
                    PasswordTextField(
                      label: 'Confirm New Password',
                      hintText: 'Re-enter your new password',
                      controller: _confirmPasswordController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password.';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 48),

                    // --- SUBMIT BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


}
