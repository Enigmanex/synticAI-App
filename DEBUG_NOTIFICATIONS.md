# Debug Prayer Notifications

## Quick Fix: Reschedule Asr Notification

If you didn't receive the notification at 4:59 PM, you can manually reschedule it:

### Option 1: Restart the App
Simply restart the app - it will automatically reschedule all notifications.

### Option 2: Check Scheduled Notifications
Add this code temporarily to check what's scheduled:

```dart
final service = PrayerTimeService();
final scheduled = await service.getScheduledNotifications();
print('Scheduled: ${scheduled.length}');
for (var n in scheduled) {
  print('${n.title}: ${n.body}');
}
```

### Option 3: Manually Reschedule Asr
You can reschedule Asr specifically:

```dart
final service = PrayerTimeService();
await service.reschedulePrayerNow('Asr');
```

## Common Issues

### 1. Time Already Passed
If 4:59 PM has already passed today, the notification will be scheduled for tomorrow at 4:59 PM.

### 2. Check Permissions
- Settings → Apps → SynticAi → Notifications → Enable
- Settings → Apps → SynticAi → Special app access → Alarms & reminders → Enable (Android 12+)

### 3. Check Battery Optimization
- Settings → Apps → SynticAi → Battery → Unrestricted

### 4. Verify Notification is Scheduled
Run this in your code:
```dart
final service = PrayerTimeService();
final isScheduled = await service.isPrayerScheduled('Asr');
print('Asr scheduled: $isScheduled');
```

## Test Notification Immediately

To test if notifications work at all:

```dart
final service = PrayerTimeService();
await service.testNotification('Asr');
```

This will show a notification immediately.

## Set Asr to 3 Minutes From Now (For Testing)

```dart
final service = PrayerTimeService();
await service.setPrayerTimeForTesting('Asr', 3);
await service.reschedulePrayerNow('Asr');
```

This will:
1. Set Asr time to 3 minutes from now
2. Reschedule the notification
3. You should receive it in 3 minutes

## Check Logs

Look for these messages in your app logs:
- `✓ Successfully scheduled Asr notification`
- `Total scheduled notifications: 5`
- `Asr scheduled: true`

If you see warnings or errors, check the specific error message.

