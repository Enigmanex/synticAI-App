# Quick Test Code - Copy and Paste

## Method 1: Add as a Button in Your App

Copy and paste this button code into any screen in your app:

```dart
ElevatedButton(
  onPressed: () async {
    try {
      print('=== SENDING TEST PRAYER NOTIFICATION ===');
      
      final service = PrayerTimeService();
      
      // Get prayer times
      final prayerTimes = await service.getPrayerTimes();
      
      if (prayerTimes.isEmpty) {
        print('❌ No prayer times found!');
        return;
      }
      
      // Get Asr prayer (or first available)
      final testPrayer = prayerTimes.firstWhere(
        (p) => p.name == 'Asr',
        orElse: () => prayerTimes.first,
      );
      
      print('📱 Sending push notification for: ${testPrayer.name}');
      print('   Message: ${testPrayer.message}');
      print('');
      
      // Send push notification to ALL users
      await service.sendPrayerPushNotification(testPrayer);
      
      print('✅ Push notification sent successfully!');
      print('');
      print('Check:');
      print('1. Firestore → notification_requests collection');
      print('2. Your device for the notification!');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Test notification sent! Check your device!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
    } catch (e, stackTrace) {
      print('❌ ERROR: $e');
      print('Stack trace: $stackTrace');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    padding: EdgeInsets.all(16),
  ),
  child: Text(
    '🧪 TEST PRAYER PUSH NOTIFICATION',
    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  ),
)
```

## Method 2: Add to main.dart (Auto-sends on app start)

Add this code at the end of `main()` function in `lib/main.dart`:

```dart
// OR add this code at the end of main() function in lib/main.dart:
// (It will send automatically when app starts)
Future.delayed(Duration(seconds: 5), () async {
  try {
    print('=== AUTO-SENDING TEST NOTIFICATION ===');
    final service = PrayerTimeService();
    final prayerTimes = await service.getPrayerTimes();
    final testPrayer = prayerTimes.firstWhere(
      (p) => p.name == 'Asr',
      orElse: () => prayerTimes.first,
    );
    await service.sendPrayerPushNotification(testPrayer);
    print('✅ Auto-sent test notification!');
  } catch (e) {
    print('❌ Auto-send error: $e');
  }
});
```

## Usage

1. Copy the code block you want to use
2. Paste it into your app file (don't forget to add proper imports)
3. Test the notification!

## Required Imports

If using Method 1 (button), make sure you have these imports in your screen file:

```dart
import 'package:flutter/material.dart';
import '../services/prayer_time_service.dart';
```

