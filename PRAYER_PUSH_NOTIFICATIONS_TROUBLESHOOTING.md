# Prayer Time Push Notifications Troubleshooting Guide

This guide helps you diagnose and fix issues with prayer time push notifications not being received.

## Quick Diagnosis Checklist

### ✅ Step 1: Check if Cloud Scheduler is Set Up

**This is the most common issue!** Push notifications are sent via Cloud Scheduler triggering a Cloud Function at each prayer time. If Cloud Scheduler jobs are not set up, no push notifications will be sent.

1. Go to [Google Cloud Console - Cloud Scheduler](https://console.cloud.google.com/cloudscheduler)
2. Select your project: `readpro-c466c`
3. Check if you have 5 scheduled jobs (one for each prayer):
   - `send-prayer-fajr`
   - `send-prayer-zuhr`
   - `send-prayer-asr`
   - `send-prayer-maghrib`
   - `send-prayer-isha`

**If jobs don't exist**, see [Setting Up Cloud Scheduler](#setting-up-cloud-scheduler) below.

**If jobs exist**, verify:
- ✅ Jobs are **enabled** (not paused)
- ✅ Jobs are configured with correct schedule (cron format)
- ✅ Jobs point to the correct Cloud Function URL
- ✅ Jobs have the correct request body with `prayerName` and `message`

### ✅ Step 2: Check if Cloud Function is Deployed

1. Go to [Firebase Console - Functions](https://console.firebase.google.com/project/readpro-c466c/functions)
2. Verify `sendPrayerTimeNotification` function exists and is deployed
3. Check function logs for errors:
   ```bash
   firebase functions:log --only sendPrayerTimeNotification
   ```

**If function is not deployed**:
```bash
cd functions
npm install
cd ..
firebase deploy --only functions:sendPrayerTimeNotification
```

### ✅ Step 3: Verify FCM Tokens are Stored

1. Go to [Firestore Console](https://console.firebase.google.com/project/readpro-c466c/firestore)
2. Open `employees` collection
3. Check that each user document has:
   - `fcmToken` field with a valid token (long string)
   - `fcmTokenUpdatedAt` timestamp

**If tokens are missing**:
- Users need to log in again (tokens are saved on login)
- Check app logs for "FCM Token:" messages
- Verify notification permissions are granted

### ✅ Step 4: Test the Cloud Function Manually

Test if the function works by calling it directly:

```bash
curl -X POST https://YOUR-REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Test","message":"Test prayer notification"}'
```

Replace `YOUR-REGION` with your function's region (e.g., `us-central1`, `asia-south1`).

**To find your function URL**:
1. Go to Firebase Console → Functions
2. Click on `sendPrayerTimeNotification`
3. Copy the trigger URL

**Expected response**:
```json
{
  "success": true,
  "message": "Prayer time notification sent: Test",
  "recipients": 5
}
```

If you get an error, check the function logs.

### ✅ Step 5: Check Device Settings

**Android**:
1. Settings → Apps → Attendance App → Notifications
   - ✅ Enable notifications
   - ✅ Enable "Prayer Time Notifications" channel
2. Settings → Apps → Attendance App → Battery
   - ✅ Set to "Unrestricted" or "Not optimized"
3. Settings → Apps → Attendance App → Special app access → Alarms & reminders
   - ✅ Enable (Android 12+)

**iOS**:
1. Settings → Attendance App → Notifications
   - ✅ Enable "Allow Notifications"
   - ✅ Enable "Sounds"
   - ✅ Enable "Badges"
   - ✅ Enable "Alerts"

### ✅ Step 6: Check App Logs

Look for these messages in your app logs:

**Good signs**:
- `FCM Token: [token]`
- `User granted notification permission`
- `Received foreground message: [messageId]`

**Bad signs**:
- `User declined notification permission`
- `No FCM token found for user`
- `Error sending notification: [error]`

## Setting Up Cloud Scheduler

If Cloud Scheduler jobs are not set up, follow these steps:

### Prerequisites

1. **Get your Cloud Function URL**:
   - Go to Firebase Console → Functions
   - Click on `sendPrayerTimeNotification`
   - Copy the trigger URL (e.g., `https://us-central1-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification`)

2. **Determine your region**:
   - The region is in your function URL (e.g., `us-central1`, `asia-south1`)

3. **Get current prayer times**:
   - Check Firestore: `settings/prayer_times`
   - Or check the app's default times

### Option 1: Using gcloud CLI

```bash
# Install gcloud CLI if not installed
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Set your project
gcloud config set project readpro-c466c

# Set your region (replace with your actual region)
export REGION=us-central1

# Create Fajr job (5:28 AM)
gcloud scheduler jobs create http send-prayer-fajr \
  --schedule="28 5 * * *" \
  --uri="https://${REGION}-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Fajr","message":"Fajr time — begin your day with prayer."}' \
  --time-zone="Asia/Karachi" \
  --location=${REGION}

# Create Zuhr job (1:30 PM)
gcloud scheduler jobs create http send-prayer-zuhr \
  --schedule="30 13 * * *" \
  --uri="https://${REGION}-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Zuhr","message":"Zuhr time — pause for prayer."}' \
  --time-zone="Asia/Karachi" \
  --location=${REGION}

# Create Asr job (4:59 PM)
gcloud scheduler jobs create http send-prayer-asr \
  --schedule="59 16 * * *" \
  --uri="https://${REGION}-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Asr","message":"Asr time — remember Allah."}' \
  --time-zone="Asia/Karachi" \
  --location=${REGION}

# Create Maghrib job (5:16 PM)
gcloud scheduler jobs create http send-prayer-maghrib \
  --schedule="16 17 * * *" \
  --uri="https://${REGION}-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Maghrib","message":"Maghrib azan — complete your day with prayer."}' \
  --time-zone="Asia/Karachi" \
  --location=${REGION}

# Create Isha job (6:45 PM)
gcloud scheduler jobs create http send-prayer-isha \
  --schedule="45 18 * * *" \
  --uri="https://${REGION}-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Isha","message":"Isha time — end your day with prayer."}' \
  --time-zone="Asia/Karachi" \
  --location=${REGION}
```

### Option 2: Using Google Cloud Console (Web UI)

1. Go to [Cloud Scheduler](https://console.cloud.google.com/cloudscheduler)
2. Click **CREATE JOB**
3. Fill in the details:

   **Job Name**: `send-prayer-fajr` (or zuhr, asr, etc.)
   
   **Region**: Select your region (e.g., `us-central1`)
   
   **Frequency**: Use cron format:
   - Fajr: `28 5 * * *` (5:28 AM daily)
   - Zuhr: `30 13 * * *` (1:30 PM daily)
   - Asr: `59 16 * * *` (4:59 PM daily)
   - Maghrib: `16 17 * * *` (5:16 PM daily)
   - Isha: `45 18 * * *` (6:45 PM daily)
   
   **Timezone**: `Asia/Karachi` (or your timezone)
   
   **Target Type**: HTTP
   
   **URL**: Your function URL (e.g., `https://us-central1-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification`)
   
   **HTTP Method**: POST
   
   **Headers**: 
   ```
   Content-Type: application/json
   ```
   
   **Body**: 
   ```json
   {
     "prayerName": "Fajr",
     "message": "Fajr time — begin your day with prayer."
   }
   ```
   (Update `prayerName` and `message` for each prayer)

4. Click **CREATE**
5. Repeat for all 5 prayers

### Option 3: Using Firebase Console

Unfortunately, Cloud Scheduler cannot be configured directly from Firebase Console. You need to use Google Cloud Console or gcloud CLI.

## Testing Push Notifications

### Test 1: Manual Function Call

Call the function directly to test if it works:

```bash
curl -X POST https://YOUR-REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Test","message":"This is a test notification"}'
```

You should receive a notification on all devices with valid FCM tokens.

### Test 2: Test Cloud Scheduler Job

1. Go to Cloud Scheduler
2. Find one of the prayer jobs (e.g., `send-prayer-fajr`)
3. Click the three dots menu → **RUN NOW**
4. Check function logs to see if it executed successfully
5. Check your device for the notification

### Test 3: Check Function Logs

```bash
firebase functions:log --only sendPrayerTimeNotification
```

Look for:
- ✅ `Successfully sent message:`
- ✅ `Prayer time notification sent to X users`
- ❌ Error messages

## Common Issues and Solutions

### Issue 1: "No notifications received"

**Possible causes**:
1. Cloud Scheduler jobs not set up
2. FCM tokens not stored in Firestore
3. Cloud Function not deployed
4. Notification permissions not granted
5. Device battery optimization killing the app

**Solutions**:
- Follow the checklist above
- Verify Cloud Scheduler jobs exist and are enabled
- Check FCM tokens in Firestore
- Test function manually
- Check device notification settings

### Issue 2: "Notifications received but not showing"

**Possible causes**:
1. Notification channel disabled on Android
2. Do Not Disturb mode enabled
3. App notifications disabled in device settings

**Solutions**:
- Check notification channel settings (Android)
- Disable Do Not Disturb
- Enable notifications in device settings

### Issue 3: "Function errors in logs"

**Common errors**:
- `messaging/invalid-registration-token`: Token is invalid, should be auto-removed
- `messaging/registration-token-not-registered`: Token not registered, should be auto-removed
- `Missing required parameters`: Check request body format

**Solutions**:
- Check function logs for specific error
- Verify request body format matches expected format
- Invalid tokens are automatically removed from Firestore

### Issue 4: "Cloud Scheduler job fails"

**Common errors**:
- HTTP 404: Function URL is incorrect
- HTTP 400: Request body format is incorrect
- HTTP 500: Function error (check function logs)

**Solutions**:
- Verify function URL is correct
- Check request body format
- Review function logs for errors

## Updating Prayer Times

If you need to update prayer times:

1. **Update in Firestore**:
   - Go to Firestore → `settings/prayer_times`
   - Update the times for each prayer

2. **Update Cloud Scheduler jobs**:
   - Go to Cloud Scheduler
   - Edit each job
   - Update the schedule (cron format) to match new times
   - Update the request body `message` if needed

**Note**: Local notifications are automatically updated when Firestore prayer times change. Push notifications require updating Cloud Scheduler schedules.

## Monitoring and Debugging

### Check Function Logs

```bash
firebase functions:log --only sendPrayerTimeNotification
```

### Check Cloud Scheduler Job History

1. Go to Cloud Scheduler
2. Click on a job
3. View "Job execution history"
4. Check if jobs ran successfully

### Check FCM Token Status

1. Go to Firestore → `employees` collection
2. Check each user's `fcmToken` field
3. Verify `fcmTokenUpdatedAt` is recent
4. If token is missing, user needs to log in again

### Test Notification Delivery

Use Firebase Console to send a test notification:
1. Go to Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Enter an FCM token from Firestore
4. Send test notification

## Still Not Working?

If push notifications still don't work after following this guide:

1. **Check all steps** in the Quick Diagnosis Checklist
2. **Review function logs** for errors
3. **Test manually** using curl command
4. **Verify Cloud Scheduler** jobs are enabled and running
5. **Check device settings** for notification permissions
6. **Verify FCM tokens** are stored and valid

## Additional Resources

- [Cloud Scheduler Documentation](https://cloud.google.com/scheduler/docs)
- [Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [FCM Documentation](https://firebase.google.com/docs/cloud-messaging)
- [PRAYER_TIME_SETUP.md](./PRAYER_TIME_SETUP.md) - Local notifications setup
- [NAMAZ_NOTIFICATIONS_TROUBLESHOOTING.md](./NAMAZ_NOTIFICATIONS_TROUBLESHOOTING.md) - Local notifications troubleshooting

## Summary

Prayer time push notifications require:
1. ✅ Cloud Function deployed (`sendPrayerTimeNotification`)
2. ✅ Cloud Scheduler jobs set up (5 jobs, one per prayer)
3. ✅ FCM tokens stored in Firestore for all users
4. ✅ Notification permissions granted on devices
5. ✅ Battery optimization disabled

The most common issue is **Cloud Scheduler jobs not being set up**. Always check this first!

