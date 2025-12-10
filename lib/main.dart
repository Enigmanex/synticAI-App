import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'routes/app_routes.dart';
import 'controllers/auth_controller.dart';
import 'services/notification_service.dart';
import 'services/prayer_time_service.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize notification service FIRST (this creates channels and initializes local notifications)
  print('=== Initializing Notification Service ===');
  final notificationService = NotificationService();
  await notificationService.initialize();
  print('Notification service initialized');

  // Wait a bit to ensure notification service is fully initialized
  // await Future.delayed(const Duration(milliseconds: 1000));

  // // Initialize prayer times and schedule notifications
  // print('=== Initializing Prayer Time Service ===');
  // final prayerTimeService = PrayerTimeService();
  // await prayerTimeService.initializePrayerTimes();
  // print('Prayer times initialized');

  // // Schedule local notifications for prayer times
  // print('=== Scheduling Prayer Notifications ===');
  // try {
  //   await prayerTimeService.scheduleAllPrayerNotifications();
  //   print('✓ Prayer notifications scheduled successfully');
  // } catch (e) {
  //   print('Error scheduling prayer notifications: $e');
  // }

  // // Start listening for prayer time changes in Firebase
  // prayerTimeService.startListeningForPrayerTimeChanges();

  print('=== App Initialization Complete ===');

  Get.put(AuthController());
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: "Attendance App",
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.routes,
      theme: ThemeData(
        // Using brand colors to match Syntic AI logo (#0175C2)
        primarySwatch: AppColors.primarySwatch,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryDark,
          tertiary: AppColors.primaryLight,
        ),
        scaffoldBackgroundColor: Colors.white,
        // Apply Poppins font family globally
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: GoogleFonts.poppins(),
          hintStyle: GoogleFonts.poppins(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}
