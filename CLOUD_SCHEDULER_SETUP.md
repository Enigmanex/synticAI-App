# Cloud Scheduler Setup for Push Notifications

## Overview

This guide will help you set up Cloud Scheduler so that push notifications work even when the app is closed.

**Good News:** When you deploy the Cloud Function with `functions.pubsub.schedule()`, Firebase automatically creates the Cloud Scheduler job for you! You don't need to manually set it up.

---

## How It Works

1. **App creates scheduled notification requests** when prayer times change or on app startup
2. **Cloud Scheduler** runs every minute (automatically)
3. **Cloud Function** checks for due notifications and sends push notifications
4. **Push notifications work even when app is closed!** ✅

---

## Setup Steps

### Step 1: Deploy the Cloud Function

The Cloud Function `processScheduledPushNotifications` uses `functions.pubsub.schedule()` which automatically creates a Cloud Scheduler job when deployed.

```bash
cd functions
npm install  # Make sure dependencies are installed
firebase deploy --only functions:processScheduledPushNotifications
```

**What happens:**
- Firebase automatically creates a Cloud Scheduler job
- Job runs every 1 minute
- Job triggers the Cloud Function
- Function processes scheduled notifications

---

### Step 2: Verify Cloud Scheduler Job (Optional)

You can verify the Cloud Scheduler job was created:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project: `readpro-c466c`
3. Navigate to **Cloud Scheduler** in the menu
4. You should see a job named: `processScheduledPushNotifications`

**Note:** You need admin access to view Cloud Scheduler.

---

### Step 3: Test the Setup

1. **Change prayer time in Firestore** to 2 minutes from now
2. **Open your app once** → App creates scheduled notification requests
3. **Close your app completely**
4. **Wait for prayer time**
5. ✅ **You should receive push notification!**

---

## How It Works in Detail

### When Prayer Times Change:

1. You update prayer time in Firestore
2. App detects change → Creates scheduled notification requests in `scheduled_push_notifications` collection
3. Requests are scheduled for the next 30 days

### When Cloud Scheduler Runs (Every Minute):

1. Cloud Scheduler triggers `processScheduledPushNotifications` function
2. Function checks `scheduled_push_notifications` collection for due notifications
3. If found, sends push notifications to all users with FCM tokens
4. Marks notifications as sent to prevent duplicates

### Result:

✅ Push notifications work even when app is closed!

---

## Firestore Collections Used

### 1. `scheduled_push_notifications`
Stores notification requests scheduled for future delivery.

**Document Structure:**
```json
{
  "prayerName": "Asr",
  "message": "Asr time — remember Allah.",
  "scheduledFor": Timestamp,
  "status": "pending", // or "sent", "failed", "skipped"
  "createdAt": Timestamp,
  "type": "prayer_time"
}
```

### 2. `prayer_notifications_sent`
Tracks which notifications have already been sent today (prevents duplicates).

**Document Structure:**
```json
{
  "prayerName": "Asr",
  "date": Timestamp,
  "sentAt": Timestamp,
  "sentByDevice": "cloud_scheduler"
}
```

---

## Troubleshooting

### Push Notifications Not Working?

1. **Check Cloud Function logs:**
   ```bash
   firebase functions:log --only processScheduledPushNotifications
   ```

2. **Verify Cloud Scheduler job:**
   - Go to Cloud Console → Cloud Scheduler
   - Check if job exists and is enabled
   - Check last execution time

3. **Check Firestore:**
   - Verify `scheduled_push_notifications` collection has pending notifications
   - Check `prayer_notifications_sent` to see if notifications were sent

4. **Verify FCM tokens:**
   - Check `employees` collection
   - Ensure users have valid `fcmToken` field

### Cloud Scheduler Job Not Created?

If the job wasn't created automatically:

1. **Check Firebase CLI version:**
   ```bash
   firebase --version
   ```
   Should be latest version

2. **Check permissions:**
   - You need Cloud Scheduler Admin role
   - Or ask project owner to grant permissions

3. **Manual creation (if needed):**
   - See "Manual Cloud Scheduler Setup" section below

---

## Manual Cloud Scheduler Setup (If Needed)

If the automatic setup didn't work, you can create the Cloud Scheduler job manually:

### Option 1: Using Google Cloud Console

1. Go to [Cloud Console](https://console.cloud.google.com)
2. Navigate to **Cloud Scheduler**
3. Click **Create Job**
4. Fill in:
   - **Name:** `processScheduledPushNotifications`
   - **Region:** `us-central1` (or your function's region)
   - **Frequency:** `* * * * *` (every minute)
   - **Timezone:** `UTC`
   - **Target Type:** `HTTP`
   - **URL:** Your function's trigger URL (you'll get this after deploying)
   - **HTTP Method:** `GET`
5. Click **Create**

### Option 2: Using gcloud CLI

```bash
gcloud scheduler jobs create http processScheduledPushNotifications \
  --schedule="* * * * *" \
  --uri="https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/processScheduledPushNotifications" \
  --http-method=GET \
  --time-zone="UTC"
```

---

## Cost Considerations

**Cloud Scheduler:**
- 3 free jobs per month
- After that: $0.10 per job per month

**Cloud Functions:**
- 2 million invocations free per month
- After that: $0.40 per million invocations

**With 1 minute schedule:**
- ~43,200 invocations per month (30 days)
- Well within free tier!

---

## Summary

✅ **Automatic Setup:** Just deploy the function, Cloud Scheduler is created automatically  
✅ **Runs every minute:** Checks for due notifications  
✅ **Works when app closed:** Push notifications sent from server  
✅ **No manual setup needed:** Everything is automated!  

**Just deploy and it works!** 🚀

---

## Next Steps

1. ✅ Deploy the Cloud Function
2. ✅ Test with a prayer time change
3. ✅ Verify push notifications work when app is closed
4. ✅ Done! 🎉

