import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/local_storage.dart';
import '../routes/app_routes.dart';

/// Widget that protects routes by checking authentication and role
class RouteGuard extends StatelessWidget {
  final Widget child;
  final bool requireAdmin;

  const RouteGuard({
    super.key,
    required this.child,
    this.requireAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: LocalStorage.getUser(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!;
        final isLoggedIn = user["uid"] != null && user["uid"]!.isNotEmpty;
        final isAdmin = user["admin"] == true;

        // If not logged in, redirect to role selection
        if (!isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed(AppRoutes.roleSelection);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If route requires admin but user is not admin
        if (requireAdmin && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed(AppRoutes.dashboard);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If route is for employees but user is admin
        if (!requireAdmin && isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed(AppRoutes.admin);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return child;
      },
    );
  }
}

