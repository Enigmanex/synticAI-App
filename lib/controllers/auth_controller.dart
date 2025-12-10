import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/local_storage.dart';
import '../services/notification_service.dart';
import '../routes/app_routes.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _fs = FirestoreService();

  RxBool loading = false.obs;

  Future<void> login(String email, String password) async {
    try {
      loading.value = true;

      // Hardcoded admin credentials
      const adminEmail = "synticaidev@gmail.com";
      const adminPassword = "synticai";

      final normalizedEmail = email.toLowerCase().trim();
      final isAdminEmail = normalizedEmail == adminEmail;

      UserCredential? cred;

      // Try to sign in first
      try {
        cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } catch (signInError) {
        // Check if it's a Firebase Auth exception
        if (signInError is FirebaseAuthException) {
          // If account doesn't exist and it's the admin email with correct password, create it
          if (isAdminEmail && password == adminPassword) {
            if (signInError.code == 'user-not-found' ||
                signInError.code == 'invalid-credential' ||
                signInError.code == 'wrong-password') {
              try {
                cred = await _auth.createUserWithEmailAndPassword(
                  email: email.trim(),
                  password: password,
                );
              } catch (createError) {
                Get.snackbar(
                  "Error",
                  "Failed to create admin account. Please try again.",
                );
                return;
              }
            } else {
              Get.snackbar(
                "Login Error",
                signInError.message ?? signInError.code,
              );
              return;
            }
          } else {
            // For non-admin or wrong password, show the error
            Get.snackbar(
              "Login Error",
              signInError.message ?? signInError.code,
            );
            return;
          }
        } else {
          // For non-admin or wrong password, show the error
          Get.snackbar("Login Error", signInError.toString());
          return;
        }
      }

      // At this point, cred should never be null (either sign in succeeded or account was created)
      final userCred = cred;

      // Check if this is admin login
      if (isAdminEmail && password == adminPassword) {
        // Ensure admin user exists in Firestore
        await _fs.ensureAdminUser(userCred.user!.uid, adminEmail);

        await LocalStorage.saveUser(
          userCred.user!.uid,
          adminEmail,
          true, // Admin
        );

        // Save FCM token
        final token = await NotificationService().getToken();
        if (token != null) {
          await NotificationService().saveUserToken(userCred.user!.uid, token);
        }

        Get.offAllNamed(AppRoutes.admin);
        return;
      }

      // Regular login for other users
      final employee = await _fs.getEmployee(userCred.user!.uid);

      if (employee == null) {
        Get.snackbar("Error", "Employee record not found");
        return;
      }

      await LocalStorage.saveUser(
        userCred.user!.uid,
        employee.email,
        employee.admin,
      );

      // Save FCM token
      final token = await NotificationService().getToken();
      if (token != null) {
        await NotificationService().saveUserToken(userCred.user!.uid, token);
      }

      // Check if user came from admin login screen
      final currentRoute = Get.currentRoute;
      final isAdminLogin = currentRoute == AppRoutes.adminLogin;

      // Verify admin status and route accordingly
      if (employee.admin) {
        Get.offAllNamed(AppRoutes.admin);
      } else {
        // If employee tries to login from admin screen, show error
        if (isAdminLogin) {
          Get.snackbar("Access Denied", "This account is not an admin account");
          return;
        }
        Get.offAllNamed(AppRoutes.dashboard);
      }
    } catch (e) {
      Get.snackbar("Login Error", e.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> register(
    String name,
    String email,
    String password, {
    String role = "employee",
  }) async {
    try {
      loading.value = true;

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create employee or intern based on selected role
      if (role == "intern") {
        await _fs.createIntern(cred.user!.uid, name, email);
      } else {
        await _fs.createEmployee(cred.user!.uid, name, email, role: role);
      }

      await LocalStorage.saveUser(cred.user!.uid, email, false);

      // Save FCM token
      final token = await NotificationService().getToken();
      if (token != null) {
        await NotificationService().saveUserToken(cred.user!.uid, token);
      }

      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      Get.snackbar("Register Error", e.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await LocalStorage.clear();
    Get.offAllNamed(AppRoutes.splash);
  }
}
