// Quick test script to send a prayer notification RIGHT NOW
// Run this from your Flutter app or create a test button

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/prayer_time_service.dart';
import 'lib/services/notification_service.dart';
import 'lib/models/prayer_time.dart';

Future<void> testPrayerNotification() async {
  try {
    print('=== TESTING PRAYER NOTIFICATION ===');

    // Initialize Firebase if not already initialized
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Firebase already initialized or error: $e');
    }

    final prayerTimeService = PrayerTimeService();

    // Get prayer times
    final prayerTimes = await prayerTimeService.getPrayerTimes();

    if (prayerTimes.isEmpty) {
      print('❌ No prayer times found!');
      return;
    }

    // Use Asr prayer (or first available)
    final testPrayer = prayerTimes.firstWhere(
      (p) => p.name == 'Asr',
      orElse: () => prayerTimes.first,
    );

    print('📱 Sending test notification for: ${testPrayer.name}');
    print('   Message: ${testPrayer.message}');
    print('');

    // Send push notification to all users
    // await prayerTimeService.sendPrayerPushNotification(testPrayer);

    print('✅ Test notification sent!');
    print('');
    print('Check your device for the notification!');
    print('Also check Firestore:');
    print('  - notification_requests collection');
    print('  - Should see pending/sent status');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
}

// To use in your app, call:
// testPrayerNotification();
