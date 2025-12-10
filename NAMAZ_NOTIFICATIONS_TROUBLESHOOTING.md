# Namaz (Prayer) Notifications Troubleshooting Guide

## Issues Fixed

1. **Notification Channel Creation**: The `prayer_time_channel` is now created during notification service initialization, ensuring it exists before scheduling notifications.

2. **Initialization Order**: Fixed the order so notification service initializes before prayer time service schedules notifications.

3. **Better Error Handling**: Added comprehensive error handling and logging to help diagnose issues.

4. **Verification Method**: Added `verifyNotificationSetup()` method to check if notifications are properly configured.

## Common Issues and Solutions

### Issue 1: Notifications Not Appearing

**Possible Causes:**
- Notification permissions not granted
- Exact alarm permission not granted (Android 12+)
- Device battery optimization killing the app
- Notifications disabled in device settings

**Solutions:**

1. **Check Notification Permissions:**
   - Go to device Settings → Apps → SynticAi → Notifications
   - Ensure notifications are enabled
   - Check that "Prayer Time Notifications" channel is enabled

2. **Check Exact Alarm Permission (Android 12+):**
   - Go to device Settings → Apps → SynticAi → Special app access → Alarms & reminders
   - Enable "Allow" for exact alarms
   - Alternatively, the app should prompt you when scheduling

3. **Disable Battery Optimization:**
   - Go to device Settings → Apps → SynticAi → Battery
   - Set to "Unrestricted" or "Not optimized"

4. **Test Notifications:**
   - Use the test notification feature in the app (if available)
   - Check logs for scheduling errors

### Issue 2: Notifications Scheduled But Not Triggering

**Possible Causes:**
- Timezone issues
- Device time not synced
- App killed by system

**Solutions:**

1. **Check Timezone:**
   - Ensure device timezone is correct
   - The app uses device local timezone

2. **Check Device Time:**
   - Ensure device time is correct and synced
   - Go to Settings → Date & time → Enable "Automatic date & time"

3. **Keep App Running:**
   - Don't force close the app
   - Allow it to run in background

### Issue 3: Push Notifications Not Working

**Possible Causes:**
- Cloud Scheduler jobs not set up
- Cloud Function not deployed
- FCM tokens not stored

**Solutions:**

1. **Check Cloud Scheduler:**
   - Go to Google Cloud Console → Cloud Scheduler
   - Verify 5 jobs are created (one for each prayer time)
   - Ensure jobs are enabled and running

2. **Check Cloud Function:**
   - Go to Firebase Console → Functions
   - Verify `sendPrayerTimeNotification` function is deployed
   - Check function logs for errors

3. **Check FCM Tokens:**
   - Go to Firestore → `employees` collection
   - Verify each user has an `fcmToken` field
   - Tokens are saved when user logs in

## Testing Notifications

### Test Local Notifications

1. **Check Scheduled Notifications:**
   ```dart
   final service = PrayerTimeService();
   final scheduled = await service.getScheduledNotifications();
   print('Scheduled: ${scheduled.length}');
   ```

2. **Verify Setup:**
   ```dart
   final service = PrayerTimeService();
   final result = await service.verifyNotificationSetup();
   print('Setup status: $result');
   ```

3. **Test Notification:**
   ```dart
   final service = PrayerTimeService();
   await service.testNotification('Fajr');
   ```

### Test Push Notifications

1. **Manual Function Test:**
   ```bash
   curl -X POST https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendPrayerTimeNotification \
     -H "Content-Type: application/json" \
     -d '{"prayerName":"Test","message":"Test prayer notification"}'
   ```

2. **Check Firestore:**
   - Check `notification_requests` collection for pending/sent status
   - Check `notifications` collection for stored notifications

## Debugging Steps

1. **Check App Logs:**
   - Look for "Prayer notifications scheduled" messages
   - Check for any error messages
   - Verify timezone initialization

2. **Check Scheduled Notifications:**
   - Use `getScheduledNotifications()` to see what's scheduled
   - Verify notification IDs match prayer times

3. **Check Firestore:**
   - Verify `settings/prayer_times` document exists
   - Check prayer times are correct
   - Verify format is "HH:mm" (24-hour)

4. **Check Permissions:**
   - Android: Settings → Apps → SynticAi → Permissions
   - iOS: Settings → SynticAi → Notifications

## Expected Behavior

1. **On App Start:**
   - Notification service initializes
   - Prayer times are loaded from Firestore
   - Notifications are scheduled for all prayer times
   - Notifications repeat daily automatically

2. **Daily:**
   - Local notifications trigger at scheduled times
   - Push notifications sent via Cloud Scheduler (if configured)

3. **On Prayer Time Update:**
   - App detects change in Firestore
   - All notifications are rescheduled with new times

## Next Steps

If notifications still don't work after checking all the above:

1. **Check Device-Specific Issues:**
   - Some manufacturers (Xiaomi, Huawei, etc.) have aggressive battery optimization
   - May need to whitelist the app manually

2. **Check Android Version:**
   - Android 12+ requires exact alarm permission
   - Older versions may have different behavior

3. **Contact Support:**
   - Provide device model and Android version
   - Share app logs
   - Share verification results from `verifyNotificationSetup()`

