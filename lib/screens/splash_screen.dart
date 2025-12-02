import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/local_storage.dart';
import '../routes/app_routes.dart';
import '../utils/app_colors.dart';

/// Initial screen that checks authentication and routes accordingly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    _setupLogoAnimation();
    _checkAuthAndRoute();
  }

  Future<void> _checkAuthAndRoute() async {
    // Wait a bit for splash effect
    await Future.delayed(const Duration(seconds: 1));

    try {
      final user = await LocalStorage.getUser();
      final isLoggedIn = user["uid"] != null && user["uid"]!.isNotEmpty;
      final isAdmin = user["admin"] == true;

      if (isLoggedIn) {
        // User is logged in, route based on role
        if (isAdmin) {
          Get.offAllNamed(AppRoutes.admin);
        } else {
          Get.offAllNamed(AppRoutes.dashboard);
        }
    } else {
      // User not logged in, go to role selection
      Get.offAllNamed(AppRoutes.roleSelection);
    }
    } catch (e) {
      // If there's an error, go to role selection
      Get.offAllNamed(AppRoutes.roleSelection);
    }
  }

  void _setupLogoAnimation() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    final curved =
        CurvedAnimation(parent: _logoController, curve: Curves.easeInOut);
    _logoScale = Tween<double>(begin: 0.9, end: 1.05).animate(curved);
    _logoOpacity = Tween<double>(begin: 0.65, end: 1.0).animate(curved);
    _logoController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/images/syntic ai logo-02.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 30),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

