# Troubleshooting: Push Notifications Not Working

## Common Issues & Solutions

### 1. Check if Scheduled Notifications are Created

**Check Firestore:**
1. Go to Firebase Console → Firestore
2. Look for collection: `scheduled_push_notifications`
3. Should have documents with:
   - `status: "pending"`
   - `scheduledFor: Timestamp` (in future)
   - `prayerName: String`

**If empty:**
- App hasn't created scheduled notifications yet
- Open app once after changing prayer time
- Check app console logs for "Scheduling push notification requests"

---

### 2. Check Cloud Function Logs

```bash
firebase functions:log --only processScheduledPushNotifications
```

**Look for:**
- "=== Checking for scheduled push notifications ==="
- "Found X scheduled notifications to process"
- Any error messages

**If no logs:**
- Cloud Scheduler might not be running
- Check Cloud Console → Cloud Scheduler

---

### 3. Check Cloud Scheduler

**In Google Cloud Console:**
1. Go to Cloud Scheduler
2. Look for job: `processScheduledPushNotifications`
3. Check if it's **enabled**
4. Check **last execution time**
5. Check for any errors

**If not found:**
- Function deployment might have failed
- Redeploy the function

---

### 4. Verify FCM Tokens

**Check Firestore:**
1. Go to `employees` collection
2. Check if users have `fcmToken` field
3. Tokens should be non-empty strings

**If no tokens:**
- Users need to open app at least once
- App saves FCM token on login

---

### 5. Check Prayer Times

**Verify in Firestore:**
1. Go to `settings/prayer_times`
2. Check if prayer times are set correctly
3. Times should be in format: `HH:MM`

---

## Step-by-Step Debugging

### Step 1: Create Test Scheduled Notification

Create a document in Firestore manually:

**Collection:** `scheduled_push_notifications`  
**Document ID:** `Test_2024-01-15` (any unique ID)

**Fields:**
```json
{
  "prayerName": "Test",
  "message": "Test notification",
  "scheduledFor": Timestamp (set to 2 minutes from now),
  "status": "pending",
  "type": "prayer_time",
  "createdAt": Timestamp (now)
}
```

Wait 2 minutes and check:
- Cloud Function logs
- If notification was sent

---

### Step 2: Check if Function is Running

Manually trigger the function (if you have admin access):

```bash
curl -X GET "https://us-central1-readpro-c466c.cloudfunctions.net/processScheduledPushNotifications"
```

Or check Cloud Scheduler execution history.

---

### Step 3: Verify App Creates Scheduled Notifications

1. **Change prayer time** in Firestore to 2 minutes from now
2. **Open your app**
3. **Check console logs** for:
   - "=== Scheduling push notification requests for next 30 days ==="
   - "✓ Scheduled push notification for..."
4. **Check Firestore** `scheduled_push_notifications` collection

---

## Quick Test

1. **Set prayer time** to 2 minutes from now
2. **Open app once** → Creates scheduled notification
3. **Close app completely**
4. **Wait 2 minutes**
5. **Check:**
   - Did you receive notification?
   - Check Cloud Function logs
   - Check Firestore `prayer_notifications_sent` collection

---

## Common Problems

### Problem: No scheduled notifications in Firestore
**Solution:** App might not be calling `schedulePushNotificationsForNext30Days()`
- Check `lib/main.dart` - should call it on startup
- Check `lib/services/prayer_time_service.dart` - should call it when prayer times change

### Problem: Cloud Function not running
**Solution:** Check Cloud Scheduler status
- Go to Cloud Console
- Verify job is enabled
- Check execution history

### Problem: Notifications created but not sent
**Solution:** Check Cloud Function logs for errors
- Might be FCM token issues
- Might be Firestore permissions
- Check error messages in logs

---

## Need Help?

Share:
1. Cloud Function logs
2. Firestore screenshots (scheduled_push_notifications collection)
3. Cloud Scheduler status
4. App console logs

This will help identify the exact issue!

