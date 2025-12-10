# Prayer Time Notifications Setup

This document explains how to set up prayer time notifications for the attendance app.

## Overview

The app sends prayer time notifications to all employees and admins at the following times:

- **Fajr**: 5:28 AM - "Fajr time — begin your day with prayer."
- **Zuhr**: 1:30 PM - "Zuhr time — pause for prayer."
- **Asr**: 4:00 PM - "Asr time — remember Allah."
- **Maghrib**: 5:16 PM - "Maghrib azan — complete your day with prayer."
- **Isha**: 6:45 PM - "Isha time — end your day with prayer."

## Features

1. **Local Notifications**: Scheduled on each device for the next 30 days
2. **Push Notifications**: Sent via Firebase Cloud Messaging to all users
3. **Firebase Storage**: Prayer times are stored in Firestore and can be updated

## Setup Instructions

### 1. Deploy Cloud Functions

First, deploy the updated Cloud Functions:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 2. Set Up Cloud Scheduler (Recommended)

Cloud Scheduler will trigger the Cloud Function at each prayer time. Set up 5 scheduled jobs:

#### Fajr (5:28 AM)
```bash
gcloud scheduler jobs create http send-prayer-fajr \
  --schedule="28 5 * * *" \
  --uri="https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Fajr","message":"Fajr time — begin your day with prayer."}' \
  --time-zone="Asia/Karachi" \
  --location=YOUR-REGION
```

#### Zuhr (1:30 PM)
```bash
gcloud scheduler jobs create http send-prayer-zuhr \
  --schedule="30 13 * * *" \
  --uri="https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Zuhr","message":"Zuhr time — pause for prayer."}' \
  --time-zone="Asia/Karachi" \
  --location=YOUR-REGION
```

#### Asr (4:00 PM)
```bash
gcloud scheduler jobs create http send-prayer-asr \
  --schedule="0 16 * * *" \
  --uri="https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Asr","message":"Asr time — remember Allah."}' \
  --time-zone="Asia/Karachi" \
  --location=YOUR-REGION
```

#### Maghrib (5:16 PM)
```bash
gcloud scheduler jobs create http send-prayer-maghrib \
  --schedule="16 17 * * *" \
  --uri="https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Maghrib","message":"Maghrib azan — complete your day with prayer."}' \
  --time-zone="Asia/Karachi" \
  --location=YOUR-REGION
```

#### Isha (6:45 PM)
```bash
gcloud scheduler jobs create http send-prayer-isha \
  --schedule="45 18 * * *" \
  --uri="https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendPrayerTimeNotification" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"prayerName":"Isha","message":"Isha time — end your day with prayer."}' \
  --time-zone="Asia/Karachi" \
  --location=YOUR-REGION
```

**Note**: Replace `YOUR-REGION` and `YOUR-PROJECT` with your actual Firebase project details. You can also set up these schedules through the Firebase Console under Cloud Scheduler.

### 3. Alternative: Manual Setup via Firebase Console

1. Go to Firebase Console → Cloud Functions
2. Find the `sendPrayerTimeNotification` function
3. Go to Cloud Scheduler in Google Cloud Console
4. Create 5 new jobs, one for each prayer time
5. Set the schedule using cron format:
   - Fajr: `28 5 * * *` (5:28 AM daily)
   - Zuhr: `30 13 * * *` (1:30 PM daily)
   - Asr: `0 16 * * *` (4:00 PM daily)
   - Maghrib: `16 17 * * *` (5:16 PM daily)
   - Isha: `45 18 * * *` (6:45 PM daily)
6. Set the target to HTTP and use the function URL
7. Add the request body with `prayerName` and `message`

### 4. Update Prayer Times (Optional)

Prayer times are stored in Firestore at: `settings/prayer_times`

You can update them programmatically or through the Firebase Console. The app will automatically reschedule local notifications when times are updated.

## How It Works

1. **On App Start**: The app initializes prayer times in Firebase (if not exists) and schedules local notifications for the next 30 days.

2. **Daily Local Notifications**: Each device receives local notifications at the scheduled prayer times.

3. **Push Notifications**: Cloud Scheduler triggers the Cloud Function at each prayer time, which sends push notifications to all users via FCM.

4. **Automatic Updates**: When prayer times are updated in Firebase, the app reschedules all local notifications.

## Testing

To test the prayer time notifications:

1. **Test Local Notifications**: 
   - Schedule a test notification for a few minutes from now
   - Verify it appears on the device

2. **Test Push Notifications**:
   - Manually trigger the Cloud Function:
   ```bash
   curl -X POST https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendPrayerTimeNotification \
     -H "Content-Type: application/json" \
     -d '{"prayerName":"Test","message":"Test prayer notification"}'
   ```

3. **Test Cloud Scheduler**:
   - Use "Run Now" in Cloud Scheduler to test each job

## Troubleshooting

- **Notifications not appearing**: Check notification permissions in device settings
- **Cloud Function not triggering**: Verify Cloud Scheduler jobs are enabled and properly configured
- **Push notifications not received**: Ensure FCM tokens are stored in Firestore for all users
- **Timezone issues**: Adjust the timezone in Cloud Scheduler to match your location

## Updating Prayer Times

To update prayer times, modify the `settings/prayer_times` document in Firestore. The structure is:

```json
{
  "prayerTimes": {
    "Fajr": {
      "name": "Fajr",
      "time": "05:28",
      "message": "Fajr time — begin your day with prayer."
    },
    ...
  },
  "updatedAt": "timestamp"
}
```

### Automatic Rescheduling

The app automatically detects changes to prayer times in Firebase and reschedules notifications:

1. **Real-time Updates**: If the app is running, it will detect changes immediately and reschedule notifications
2. **On App Start**: When users open the app, it checks for the latest prayer times and schedules accordingly
3. **Manual Update**: You can also call `PrayerTimeService().rescheduleNotifications()` programmatically if needed

### Important Notes

- **Notification Updates**: After updating prayer times in Firebase, notifications will be automatically rescheduled
- **If Notifications Don't Update**: 
  - Make sure the app is running or restart the app
  - Check that notification permissions are granted
  - Verify the time format is correct (24-hour format: "HH:mm")
- **Testing**: After updating a prayer time, wait a few seconds for the app to detect the change, or restart the app to ensure notifications are rescheduled

