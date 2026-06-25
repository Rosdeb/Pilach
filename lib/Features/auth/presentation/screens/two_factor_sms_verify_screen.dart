import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:messageapp/Features/Me/presentation/providers/two_factor_provider.dart';
import 'package:messageapp/Features/auth/data/repositories/auth_repository.dart';
import 'package:messageapp/Features/auth/presentation/providers/auth_provider.dart';
import 'package:messageapp/components/FloatingErrorBar/floatingbar.dart';
import 'package:messageapp/components/SuccessBar/successbar.dart';
import 'package:messageapp/core/constants/app_constants.dart';
import 'package:messageapp/core/network/api_exceptions.dart';

class TwoFactorSmsVerifyArgs {
  final String phone;
  final String? challengeId;

  const TwoFactorSmsVerifyArgs({
    required this.phone,
    this.challengeId,
  });
}

class TwoFactorSmsVerifyScreen extends ConsumerStatefulWidget {
  final TwoFactorSmsVerifyArgs args;

  const TwoFactorSmsVerifyScreen({super.key, required this.args});

  @override
  ConsumerState<TwoFactorSmsVerifyScreen> createState() => _TwoFactorSmsVerifyScreenState();
}

class _TwoFactorSmsVerifyScreenState extends ConsumerState<TwoFactorSmsVerifyScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isVerifying = false;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyOtp(String code) async {
    if (code.length < 6) {
      FloatingErrorBar.show(context, message: "Please enter the 6-digit code");
      return;
    }

    setState(() => _isVerifying = true);
    
    final challengeId = widget.args.challengeId;
    if (challengeId != null) {
      bool success = false;
      String? errorMsg;
      try {
        final verifyResult = await ref.read(authRepositoryProvider).verifyTwoFactorChallenge(
          challengeId: challengeId,
          type: "SMS_OTP",
          code: code,
        );
        final userData = verifyResult['data'];
        await ref.read(authProvider.notifier).setAuthenticated(
          userData?['email'] ?? widget.args.phone,
          id: userData?['id'],
          name: userData?['name'],
          profileImage: userData?['profilePicture'] ?? userData?['avatar'],
        );
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
      final success = await ref.read(twoFactorNotifierProvider.notifier).confirmSmsEnrollment(code);
      if (mounted) setState(() => _isVerifying = false);

      if (!mounted) return;

      if (success) {
        FloatingSuccessBar.show(context, message: "SMS 2FA enrolled successfully!");
        context.pop(); // Return to TwoFactorSettingsScreen
      } else {
        final errorMsg = ref.read(twoFactorNotifierProvider).errorMessage ?? "Verification failed";
        FloatingErrorBar.show(context, message: errorMsg);
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
      appBar: AppBar(
        title: Text(widget.args.challengeId != null ? "Two-Factor Verification" : "Verify SMS 2FA"),
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
                      const Text(
                        "Enter Verification Code",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "We sent a 6-digit code to \n${widget.args.phone}",
                        textAlign: TextAlign.center,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 32),
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
                          _verifyOtp(pin);
                        },
                      ),
                      const SizedBox(height: 32),
                      if (isLoading)
                        const CupertinoActivityIndicator()
                      else
                        ElevatedButton(
                          onPressed: () {
                            _verifyOtp(_pinController.text);
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Verify"),
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
