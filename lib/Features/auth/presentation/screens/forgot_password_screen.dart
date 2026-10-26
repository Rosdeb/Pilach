import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../../../components/AppText/appText.dart';
import '../../../../components/FloatingErrorBar/floatingbar.dart';
import '../../../../components/SuccessBar/successbar.dart';
import '../../../../core/constants/app_paths.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  int _step = 0; // 0 = email step, 1 = OTP + new password step
  bool _isLoading = false;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  void _handleSendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      FloatingErrorBar.show(context, message: "Email is required");
      return;
    }
    if (!email.contains('@')) {
      FloatingErrorBar.show(context, message: "Please enter a valid email");
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).forgotPassword(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      FloatingSuccessBar.show(context, message: "Reset code sent to your email!");
      setState(() => _step = 1);
      _startCooldown();
    } else {
      final errorMsg = ref.read(authProvider).errorMessage ?? "Failed to send reset code";
      FloatingErrorBar.show(context, message: errorMsg);
    }
  }

  void _handleResendCode() async {
    if (_resendCooldown > 0) return;
    final email = _emailController.text.trim();
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).forgotPassword(email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      FloatingSuccessBar.show(context, message: "Reset code resent!");
      _startCooldown();
    } else {
      final errorMsg = ref.read(authProvider).errorMessage ?? "Failed to resend code";
      FloatingErrorBar.show(context, message: errorMsg);
    }
  }

  void _handleResetPassword() async {
    final code = _pinController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.length < 4) {
      FloatingErrorBar.show(context, message: "Please enter the reset code");
      return;
    }
    if (newPassword.isEmpty) {
      FloatingErrorBar.show(context, message: "New password is required");
      return;
    }
    if (newPassword.length < 8) {
      FloatingErrorBar.show(context, message: "Password must be at least 8 characters");
      return;
    }
    if (newPassword != confirmPassword) {
      FloatingErrorBar.show(context, message: "Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).resetPasswordByOtp(
          _emailController.text.trim(),
          code,
          newPassword,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      FloatingSuccessBar.show(context, message: "Password reset successfully! Please log in.");
      context.go(AppPaths.login);
    } else {
      final errorMsg = ref.read(authProvider).errorMessage ?? "Password reset failed";
      FloatingErrorBar.show(context, message: errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 52,
      height: 52,
      textStyle: TextStyle(
        fontSize: 20,
        color: theme.colorScheme.onSurface,
        fontFamily: "Inter",
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary,
          width: 2,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title & Subtitle
                AppText(
                  _step == 0 ? "Reset Password" : "Create New Password",
                  textAlign: TextAlign.center,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(height: 10),
                AppText(
                  _step == 0
                      ? "Enter your email to receive a reset code"
                      : "Enter the code sent to ${_emailController.text.trim()} and your new password",
                  textAlign: TextAlign.center,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 36),

                // Step 0: Email input
                if (_step == 0) ...[
                  AuthTextField(
                    controller: _emailController,
                    hintText: "Email address",
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 28),

                  // Send Reset Code button
                  ZoomTapAnimation(
                    onTap: _isLoading ? null : _handleSendResetCode,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CupertinoActivityIndicator(color: Colors.white),
                              )
                            : const AppText(
                                "Send Reset Code",
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Step 1: OTP + new password

                  // OTP Pinput
                  Center(
                    child: Pinput(
                      length: 6,
                      controller: _pinController,
                      focusNode: _pinFocusNode,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      showCursor: true,
                      cursor: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            width: 20,
                            height: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Resend code
                  Center(
                    child: TextButton(
                      onPressed: (_resendCooldown > 0 || _isLoading) ? null : _handleResendCode,
                      child: AppText(
                        _resendCooldown > 0
                            ? "Resend code (${_resendCooldown}s)"
                            : "Resend code",
                        color: (_resendCooldown > 0 || _isLoading)
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
                            : theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // New password
                  AuthTextField(
                    controller: _newPasswordController,
                    hintText: "New Password",
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),

                  // Confirm new password
                  AuthTextField(
                    controller: _confirmPasswordController,
                    hintText: "Confirm New Password",
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                  ),
                  const SizedBox(height: 28),

                  // Reset Password button
                  ZoomTapAnimation(
                    onTap: _isLoading ? null : _handleResetPassword,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CupertinoActivityIndicator(color: Colors.white),
                              )
                            : const AppText(
                                "Reset Password",
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Back to Login footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText(
                      "Remember your password? ",
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: AppText(
                        "Back to Login",
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
