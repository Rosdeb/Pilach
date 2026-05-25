import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:messageapp/components/AppText/appText.dart';
import 'package:messageapp/core/constants/asset_constants.dart';
import 'package:messageapp/core/utils/app_colour.dart';
import 'package:messageapp/features/auth/presentation/providers/splash_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(splashProvider.notifier).startAnimation(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressColour = ref.watch(splashProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF000000),
              const Color(0xFF000000),
              const Color(0xFF000000),
            ],
            stops: const [0.0, 0.4, 0.75],
          ),
        ),
        padding: EdgeInsets.only(
          left: size.width * 0.1,
          top: size.height * 0.1,
          right: size.width * 0.1,
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),
            SvgPicture.asset(Assets.logo, height: 130, width: 130),
            AppText(
              "Pilach",
              color: AppColors.textWhite,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
            const Spacer(flex: 4),

            AppText("loading..", color: AppColors.textWhite, fontSize: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(12),
                valueColor: AlwaysStoppedAnimation(progressColour),
                backgroundColor: AppColors.primary,
              ),
            ),

            SizedBox(height: size.height * 0.07),
          ],
        ),
      ),
    );
  }
}
