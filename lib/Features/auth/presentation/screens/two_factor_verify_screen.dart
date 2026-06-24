import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:messageapp/Features/auth/data/repositories/auth_repository.dart';
import 'package:messageapp/Features/Me/presentation/providers/two_factor_provider.dart';
import 'package:messageapp/components/FloatingErrorBar/floatingbar.dart';
import 'package:messageapp/components/SuccessBar/successbar.dart';
import 'package:messageapp/core/constants/app_constants.dart';
import 'package:messageapp/core/network/api_exceptions.dart';

import '../providers/auth_provider.dart';

class TwoFactorVerifyArgs {
  final String verificationTarget;
  final String type; // 'EMAIL_OTP', 'SMS_OTP' etc.
  final bool isLoginChallenge;
  final String? challengeId;

  const TwoFactorVerifyArgs({
    required this.verificationTarget,
    required this.type,
    this.isLoginChallenge = false,
    this.challengeId,
  });
}

class TwoFactorVerifyScreen extends ConsumerStatefulWidget {
  final TwoFactorVerifyArgs args;

  const TwoFactorVerifyScreen({super.key, required this.args});

  @override
  ConsumerState<TwoFactorVerifyScreen> createState() => _TwoFactorVerifyScreenState();
}

class _TwoFactorVerifyScreenState extends ConsumerState<TwoFactorVerifyScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isVerifying = false;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyCode(String code) async {
    if (code.length < 6) {
      FloatingErrorBar.show(context, message: "Please enter the full verification code");
      return;
    }

    bool success = false;
    String? errorMsg;

    if (widget.args.isLoginChallenge) {
      try {
        setState(() => _isVerifying = true);
        await ref.read(authRepositoryProvider).verifyTwoFactorChallenge(
          challengeId: widget.args.challengeId ?? '',
          type: widget.args.type,
          code: code,
        );
        ref.read(authProvider.notifier).setAuthenticated(widget.args.verificationTarget);
        success = true;
      } on ApiException catch (e) {
        errorMsg = e.message;
      } catch (_) {
        errorMsg = "Verification failed";
      } finally {
        if (mounted) setState(() => _isVerifying = false);
      }

      if (!mounted) return;

      if (success) {
        FloatingSuccessBar.show(context, message: "Welcome back!");
        context.go(AppPaths.bottom_manu);
      } else {
        FloatingErrorBar.show(context, message: errorMsg ?? "Verification failed");
      }
    } else {
      // Enrollment confirmation flow
      setState(() => _isVerifying = true);
      if (widget.args.type == 'email') {
        success = await ref.read(twoFactorNotifierProvider.notifier).confirmEmailEnrollment(code);
      } else {
        success = await ref.read(twoFactorNotifierProvider.notifier).confirmSmsEnrollment(code);
      }
      if (mounted) setState(() => _isVerifying = false);

      if (!mounted) return;

      if (success) {
        FloatingSuccessBar.show(context, message: "Two-Factor method enrolled successfully!");
        context.pop(); // Go back to TwoFactorSettingsScreen
      } else {
        final stateError = ref.read(twoFactorNotifierProvider).errorMessage ?? "Verification failed";
        FloatingErrorBar.show(context, message: stateError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoading = _isVerifying;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        color: theme.colorScheme.onBackground,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            width: 2,
          ),
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Two-Factor Verification"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onBackground,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.security_outlined,
                        size: 80,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Enter Security Code",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "We sent a verification code to \n${widget.args.verificationTarget}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Pinput(
                        length: 6,
                        controller: _pinController,
                        focusNode: _focusNode,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        showCursor: true,
                        cursor: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 9),
                              width: 22,
                              height: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        onCompleted: (pin) {
                          _verifyCode(pin);
                        },
                      ),
                      const SizedBox(height: 40),
                      if (isLoading)
                        const CupertinoActivityIndicator()
                      else
                        ElevatedButton(
                          onPressed: () {
                            _verifyCode(_pinController.text);
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Confirm"),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
