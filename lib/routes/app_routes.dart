import 'package:get/get.dart';
import '../screens/role_selection_screen.dart';
import '../screens/admin_login_screen.dart';
import '../screens/employee_login_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/splash_screen.dart';
import '../middleware/auth_middleware.dart';

class AppRoutes {
  static const splash = '/splash';
  static const roleSelection = '/role-selection';
  static const adminLogin = '/admin-login';
  static const employeeLogin = '/employee-login';
  static const dashboard = '/dashboard';
  static const admin = '/admin';

  static final routes = [
    // Splash screen - checks auth and routes accordingly
    GetPage(name: splash, page: () => const SplashScreen()),
    // Role selection screen - choose admin or employee
    GetPage(
      name: roleSelection,
      page: () => const RoleSelectionScreen(),
      middlewares: [AuthMiddleware(requireAuth: false)],
    ),
    // Admin login screen
    GetPage(
      name: adminLogin,
      page: () => const AdminLoginScreen(),
      middlewares: [AuthMiddleware(requireAuth: false)],
    ),
    // Employee login/register screen
    GetPage(
      name: employeeLogin,
      page: () => const EmployeeLoginScreen(),
      middlewares: [AuthMiddleware(requireAuth: false)],
    ),
    // Employee dashboard - requires auth, not admin
    GetPage(
      name: dashboard,
      page: () => const MainNavigationScreen(),
      middlewares: [AuthMiddleware(requireAuth: true, requireAdmin: false)],
    ),
    // Admin screen - requires auth and admin role
    GetPage(
      name: admin,
      page: () => const AdminScreen(),
      middlewares: [AuthMiddleware(requireAuth: true, requireAdmin: true)],
    ),
  ];
}
