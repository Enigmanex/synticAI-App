# Fix: Notifications Not Working When App is Closed

## Understanding the Problem:

There are **TWO types** of notifications:

### 1. **Local Notifications** (Scheduled on Device)
✅ **SHOULD work when app is closed!**
- Scheduled directly on your device
- Triggered by device's notification system
- Work even if app is completely closed
- **This is what you want for prayer times!**

### 2. **Push Notifications** (Auto-send from app)
⚠️ **Only work when app is RUNNING**
- Triggered by periodic timer in the app
- Timer stops when app is closed
- Won't work when app is closed

---

## The Issue:

When you change prayer time in Firestore:
- ✅ **Local notifications** are rescheduled and SHOULD work when app is closed
- ❌ **Push notifications** won't work when app is closed (timer stops)

---

## Solution: Ensure Local Notifications Work

Local notifications are already scheduled and SHOULD work when app is closed. Let's verify:

### Check 1: Are Local Notifications Scheduled?

The app schedules local notifications for the next 30 days when:
- App starts
- Prayer times change in Firestore

### Check 2: Do They Work When App is Closed?

They should! Local notifications are scheduled on the device and work independently of the app.

---

## If Local Notifications Don't Work When App is Closed:

### Possible Issues:

1. **Notification Permissions Not Granted**
   - Android: Settings → Apps → Your App → Notifications → Enable
   - iOS: Settings → Your App → Notifications → Enable

2. **Battery Optimization Killing Notifications**
   - Android: Settings → Apps → Your App → Battery → Unrestricted
   - Some devices are aggressive about killing background tasks

3. **Exact Alarm Permission Not Granted (Android 12+)**
   - Settings → Apps → Your App → Special app access → Alarms & reminders → Enable

4. **Do Not Disturb Mode**
   - Make sure device is not in Do Not Disturb mode

5. **Device-Specific Issues**
   - Some manufacturers (Xiaomi, Huawei, etc.) have aggressive battery optimization
   - May need to manually whitelist the app

---

## What Should Happen:

1. **Update prayer time in Firestore** → App detects change (if running) or on next app start
2. **Local notifications are rescheduled** → New times are scheduled on device
3. **Close the app completely**
4. **Wait for prayer time**
5. **Device triggers notification** → Works independently of app!

---

## Testing:

### Test Local Notifications When App is Closed:

1. **Set prayer time** to 5 minutes from now in Firestore
2. **Open the app** (to reschedule notifications)
3. **Close the app completely** (force stop if needed)
4. **Wait 5 minutes**
5. **Check your device** - you should receive notification!

If you receive the notification → Local notifications work! ✅  
If you don't receive it → Check permissions and device settings

---

## For Push Notifications When App is Closed:

Push notifications need either:
1. **Cloud Scheduler** (requires admin access) - sends from server
2. **App running** (current solution) - sends from app

Without Cloud Scheduler, push notifications can't work when app is closed.

---

## Recommendation:

**Use Local Notifications** - they're perfect for prayer times:
- ✅ Work when app is closed
- ✅ More reliable
- ✅ Don't need internet
- ✅ Already implemented in your app!

Push notifications are better for:
- Real-time messages
- Server-initiated notifications
- When you need to send from server to all users at once

---

## Quick Check:

1. **Open the app** → This reschedules local notifications
2. **Close the app completely**
3. **Set prayer time to 5 minutes from now** in Firestore
4. **Open app again** (to trigger rescheduling)
5. **Close app**
6. **Wait for prayer time** → Should receive notification!

If it works → Local notifications are working! ✅  
If not → Check device settings and permissions

---

## Summary:

- **Local notifications** → Should work when app is closed (check permissions)
- **Push notifications** → Need app running OR Cloud Scheduler
- **Best solution** → Use local notifications for prayer times!

