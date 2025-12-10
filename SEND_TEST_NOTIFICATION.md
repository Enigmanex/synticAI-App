# Send Test Prayer Notification RIGHT NOW! 🚀

## Quick Test - Choose One Method:

---

## Method 1: Add Test Button in Your App (Easiest)

Add this button anywhere in your app temporarily to test:

```dart
ElevatedButton(
  onPressed: () async {
    try {
      final service = PrayerTimeService();
      final prayerTimes = await service.getPrayerTimes();
      
      // Get Asr prayer (or any prayer)
      final testPrayer = prayerTimes.firstWhere(
        (p) => p.name == 'Asr',
        orElse: () => prayerTimes.first,
      );
      
      print('📱 Sending test push notification for: ${testPrayer.name}');
      
      // Send push notification to ALL users
      await service.sendPrayerPushNotification(testPrayer);
      
      print('✅ Push notification sent! Check Firestore and your device!');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Test notification sent! Check your device!')),
      );
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  },
  child: Text('🧪 Test Prayer Push Notification'),
)
```

---

## Method 2: Call from Flutter Console/Debugger

While your app is running, open Flutter console and run:

```dart
final service = PrayerTimeService();
final prayerTimes = await service.getPrayerTimes();
final testPrayer = prayerTimes.firstWhere((p) => p.name == 'Asr', orElse: () => prayerTimes.first);
await service.sendPrayerPushNotification(testPrayer);
print('✅ Sent!');
```

---

## Method 3: Direct Code Call (Add to main.dart temporarily)

Add this at the end of `main()` function in `lib/main.dart`:

```dart
// TEST: Send prayer notification immediately
Future.delayed(Duration(seconds: 3), () async {
  try {
    final service = PrayerTimeService();
    final prayerTimes = await service.getPrayerTimes();
    final testPrayer = prayerTimes.firstWhere(
      (p) => p.name == 'Asr',
      orElse: () => prayerTimes.first,
    );
    print('📱 Sending test push notification...');
    await service.sendPrayerPushNotification(testPrayer);
    print('✅ Push notification sent!');
  } catch (e) {
    print('❌ Error: $e');
  }
});
```

Then restart the app - it will send automatically after 3 seconds!

---

## Method 4: Use Auto-Send Feature

The auto-send feature will trigger if you set prayer time to "now":

```dart
// Set Asr to current time
final now = DateTime.now();
final testTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
final service = PrayerTimeService();
await service.updatePrayerTime('Asr', testTime);

// Wait a moment, then trigger auto-send
await Future.delayed(Duration(seconds: 2));
await service.autoSendPrayerPushNotifications();
```

---

## What Will Happen:

1. ✅ **Push notification sent** to all users in Firestore
2. ✅ **Firestore documents created**:
   - `notification_requests` collection - one per user
   - `prayer_notifications_sent` collection - marks as sent
3. ✅ **Cloud Function processes** the requests automatically
4. ✅ **Notifications delivered** to all devices with valid FCM tokens

---

## Check If It Worked:

### 1. Check Firestore:
- Go to: https://console.firebase.google.com/project/readpro-c466c/firestore
- Check `notification_requests` collection:
  - Should see documents with `status: 'pending'` or `'sent'`
  - One document per user
- Check `prayer_notifications_sent` collection:
  - Should see a document marking notification as sent

### 2. Check Your Device:
- ✅ You should receive a push notification!
- ✅ Title: Prayer name (e.g., "Asr")
- ✅ Body: Prayer message

### 3. Check Function Logs (if available):
```bash
firebase functions:log --only sendNotification
```

---

## Quickest Test Right Now:

**Just add this code anywhere in your app and press a button:**

```dart
final service = PrayerTimeService();
final prayers = await service.getPrayerTimes();
await service.sendPrayerPushNotification(prayers.first);
print('✅ Sent! Check your device!');
```

That's it! 🎉

---

## Troubleshooting:

### No notification received?

1. **Check Firestore**:
   - `notification_requests` should have documents
   - Check if status is 'pending' (waiting) or 'sent' (processed)

2. **Check FCM Tokens**:
   - Firestore → `employees` → your user doc
   - Should have `fcmToken` field
   - If missing, log out and log back in

3. **Check Cloud Function**:
   - Function `sendNotification` must be deployed
   - Check: `firebase functions:list`

4. **Check Device**:
   - Notification permissions enabled
   - Not in Do Not Disturb mode
   - App not killed by battery optimization

---

## Remove Test Code:

After testing, **remove the test code** from your app!

---

**Just run one of the methods above and you'll get a test notification!** 🚀

