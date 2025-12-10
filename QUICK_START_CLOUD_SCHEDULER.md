# Quick Start: Cloud Scheduler Setup

## What You Need to Do

### Step 1: Deploy the Cloud Function

```bash
cd functions
npm install
firebase deploy --only functions:processScheduledPushNotifications
```

**That's it!** Firebase automatically creates the Cloud Scheduler job for you.

---

## How It Works

1. ✅ **You change prayer time in Firestore**
2. ✅ **You open app once** → App creates scheduled notification requests
3. ✅ **You close app**
4. ✅ **Cloud Scheduler runs every minute** → Checks for due notifications
5. ✅ **Push notifications sent automatically** → Even when app is closed!

---

## Testing

1. Change prayer time to 2 minutes from now in Firestore
2. Open your app once
3. Close your app completely
4. Wait for prayer time
5. ✅ **You should receive push notification!**

---

## Verify It's Working

Check Cloud Function logs:
```bash
firebase functions:log --only processScheduledPushNotifications
```

You should see logs like:
```
=== Checking for scheduled push notifications ===
Found X scheduled notifications to process
Processing scheduled notification: Asr
Sent Asr notification: 5 successful, 0 failed
```

---

## That's All!

**Just deploy and it works!** 🚀

For more details, see `CLOUD_SCHEDULER_SETUP.md`

