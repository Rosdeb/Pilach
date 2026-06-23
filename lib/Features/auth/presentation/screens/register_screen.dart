import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../../../components/AppText/appText.dart';
import '../../../../components/FloatingErrorBar/floatingbar.dart';

import '../../../../core/constants/asset_constants.dart';
import '../../../../core/utils/app_colour.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      FloatingErrorBar.show(context, message: "Passwords do not match");
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );

    if (mounted) {
      if (!success) {
        final errorMsg = ref.read(authProvider).errorMessage ?? "Registration failed";
        FloatingErrorBar.show(context, message: errorMsg);
      } else {
        // Router listener will automatically handle redirection
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [


          // Back arrow button
          // Positioned(
          //   top: MediaQuery.of(context).padding.top + 10,
          //   left: 16,
          //   child: ZoomTapAnimation(
          //     onTap: () => context.pop(),
          //     child: Container(
          //       padding: const EdgeInsets.all(12),
          //       decoration: BoxDecoration(
          //         color: Colors.black.withOpacity(0.05),
          //         shape: BoxShape.circle,
          //       ),
          //       child: const Icon(
          //         Icons.arrow_back_ios_new_rounded,
          //         color: AppColors.textDark,
          //         size: 18,
          //       ),
          //     ),
          //   ),
          // ),

          // Scrollable layout
          SafeArea(
            child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),

                      // Logo & Title
                      Center(
                        child: SvgPicture.asset(
                          Assets.logo,
                          height: 70,
                          width: 70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: AppText(
                          "Create Account",
                          color: AppColors.textDark,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: AppText(
                          "Connect with your friends today",
                          color: AppColors.textLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Name input
                      AuthTextField(
                        controller: _nameController,
                        hintText: "Full name",
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Full name is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email input
                      AuthTextField(
                        controller: _emailController,
                        hintText: "Email address",
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Email is required";
                          }
                          if (!val.contains('@')) {
                            return "Please enter a valid email";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password input
                      AuthTextField(
                        controller: _passwordController,
                        hintText: "Password",
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return "Password is required";
                          }
                          if (val.length < 6) {
                            return "Password must be at least 6 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password input
                      AuthTextField(
                        controller: _confirmPasswordController,
                        hintText: "Confirm password",
                        prefixIcon: Icons.lock_clock_outlined,
                        isPassword: true,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return "Confirm password is required";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Register Button
                      ZoomTapAnimation(
                        onTap: authState.status == AuthStatus.loading ? null : _handleRegister,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF1E40AF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: authState.status == AuthStatus.loading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const AppText(
                                    "Sign Up",
                                    color: AppColors.textWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Already have an account footer link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppText(
                            "Already have an account? ",
                            color: AppColors.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: const AppText(
                              "Log In",
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
