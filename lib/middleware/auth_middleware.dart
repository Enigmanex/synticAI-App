import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Middleware to protect routes
/// Note: Actual auth checking and routing is handled in SplashScreen
class AuthMiddleware extends GetMiddleware {
  final bool requireAuth;
  final bool requireAdmin;

  AuthMiddleware({
    this.requireAuth = true,
    this.requireAdmin = false,
  });

  @override
  RouteSettings? redirect(String? route) {
    // The actual auth checking and routing is handled in SplashScreen
    // This middleware just marks routes as protected
    // SplashScreen will handle the actual routing logic
    return null;
  }
}

