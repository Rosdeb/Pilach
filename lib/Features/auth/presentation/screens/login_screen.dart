import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../../../components/AppText/appText.dart';
import '../../../../components/FloatingErrorBar/floatingbar.dart';
import '../../../../components/SuccessBar/successbar.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/asset_constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import 'package:messageapp/Features/auth/data/repositories/auth_repository.dart';
import 'package:messageapp/Features/auth/presentation/screens/two_factor_email_verify_screen.dart';
import 'package:messageapp/Features/auth/presentation/screens/two_factor_sms_verify_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await ref.read(authProvider.notifier).login(
          _emailController.text,
          _passwordController.text,
        );

    if (mounted) {
      if (result == null) {
        final errorMsg = ref.read(authProvider).errorMessage ?? "Authentication failed";
        FloatingErrorBar.show(context, message: errorMsg);
        return;
      }

      if (result['is2faRequired'] == true) {
        final challengeId = result['challengeId'] as String;
        final methods = result['methods'] as List<dynamic>;
        final String selectedMethod = methods.isNotEmpty ? methods.first.toString() : 'EMAIL_OTP';

        FloatingSuccessBar.show(context, message: "Sending 2FA security code...");

        try {
          await ref.read(authRepositoryProvider).sendTwoFactorChallenge(
                challengeId: challengeId,
                type: selectedMethod,
              );

          if (!mounted) return;

          if (selectedMethod == 'SMS_OTP') {
            context.push(
              AppPaths.two_factor_sms_verify,
              extra: TwoFactorSmsVerifyArgs(
                phone: _emailController.text,
                challengeId: challengeId,
              ),
            );
          } else {
            context.push(
              AppPaths.two_factor_email_verify,
              extra: TwoFactorEmailVerifyArgs(
                email: _emailController.text,
                challengeId: challengeId,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            FloatingErrorBar.show(context, message: e.toString());
          }
        }
      } else {
        FloatingSuccessBar.show(context, message: "Logged in successfully!");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Logo & Title
                  Center(
                    child: Hero(
                      tag: 'app_logo',
                      child: SvgPicture.asset(
                        Assets.logo,
                        height: 80,
                        width: 80,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: AppText(
                      "Welcome Back",
                      color: theme.colorScheme.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: AppText(
                      "Sign in to stay connected with your friends",
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

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
                      return null;
                    },
                  ),

                  // Forgot password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Add forgot password screen routing if needed
                      },
                      child: AppText(
                        "Forgot Password?",
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Login Button
                  ZoomTapAnimation(
                    onTap: authState.status == AuthStatus.loading ? null : _handleLogin,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.2),
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
                                child: CupertinoActivityIndicator(color: Colors.white),
                              )
                            : const AppText(
                                "Log In",
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Divider "Or continue with"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.onSurface.withOpacity(0.08),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: AppText(
                          "or sign in with",
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.onSurface.withOpacity(0.08),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Social Login
                  Row(
                    children: [
                      // Google
                      Expanded(
                        child: ZoomTapAnimation(
                          onTap: () {},
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.g_mobiledata_rounded, color: theme.colorScheme.onSurface, size: 28),
                                const SizedBox(width: 8),
                                AppText(
                                  "Google",
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Apple
                      Expanded(
                        child: ZoomTapAnimation(
                          onTap: () {},
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.apple_rounded, color: theme.colorScheme.onSurface, size: 22),
                                const SizedBox(width: 8),
                                AppText(
                                  "Apple",
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Sign Up Footer Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText(
                        "Don't have an account? ",
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      GestureDetector(
                        onTap: () => context.push(AppPaths.register),
                        child: AppText(
                          "Sign Up",
                          color: theme.colorScheme.primary,
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
      ),
    );
  }
}
