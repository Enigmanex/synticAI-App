# Test Prayer Push Notification - Quick Guide

## Method 1: Direct Cloud Function Call (Fastest - Recommended)

This method calls the Cloud Function directly, bypassing the need to set prayer times. Perfect for immediate testing!

### Step 1: Find Your Cloud Function URL

1. Go to [Firebase Console](https://console.firebase.google.com/project/readpro-c466c/functions)
2. Click on `sendPrayerTimeNotification` function
3. Copy the **Trigger URL** (it looks like: `https://us-central1-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification`)
4. Note the **region** in the URL (e.g., `us-central1`, `asia-south1`)

### Step 2: Test with curl Command

Open your terminal and run:

```bash
curl -X POST https://YOUR-REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

**Replace `YOUR-REGION`** with your actual region (e.g., `us-central1`).

**Example:**
```bash
curl -X POST https://us-central1-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

### Step 3: Check the Response

You should see a JSON response like:
```json
{
  "success": true,
  "message": "Prayer time notification sent: Asr",
  "recipients": 5,
  "successCount": 5,
  "failureCount": 0,
  "totalEmployees": 5,
  "usersWithTokens": 5,
  "usersWithoutTokens": 0
}
```

### Step 4: Check Your Device

- ✅ You should receive a push notification immediately on your device
- ✅ Notification should say "Asr" as title
- ✅ Body should say "Asr time — remember Allah. (Test Notification)"

### Troubleshooting

**No notification received?**

1. **Check function logs**:
   ```bash
   firebase functions:log --only sendPrayerTimeNotification
   ```

2. **Verify FCM tokens**:
   - Go to Firestore → `employees` collection
   - Check that your user document has an `fcmToken` field
   - If missing, log out and log back in

3. **Check notification permissions**:
   - Android: Settings → Apps → Attendance App → Notifications → Enable
   - iOS: Settings → Attendance App → Notifications → Enable

4. **Check device settings**:
   - Make sure device is not in Do Not Disturb mode
   - Check battery optimization is disabled for the app

**Function returns error?**

1. Check the error message in the response
2. Common errors:
   - `404`: Function URL is wrong or function not deployed
   - `500`: Function error - check logs
   - `400`: Request body format is wrong

## Method 2: Using Firebase Console (Alternative)

1. Go to [Firebase Console → Functions](https://console.firebase.google.com/project/readpro-c466c/functions)
2. Click on `sendPrayerTimeNotification`
3. Go to "Testing" tab
4. Use this request body:
   ```json
   {
     "prayerName": "Asr",
     "message": "Asr time — remember Allah. (Test Notification)"
   }
   ```
5. Click "Test the function"
6. Check your device for the notification

## Method 3: Test from App (If you want to add a test button)

You can also create a test button in your app. Here's how:

### Option A: Direct Cloud Function Call from App

Add this to a test screen or admin panel:

```dart
// Test prayer push notification
Future<void> testPrayerPushNotification() async {
  try {
    // Get your function URL
    final functionUrl = 'https://YOUR-REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification';
    
    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'prayerName': 'Asr',
        'message': 'Asr time — remember Allah. (Test Notification)',
      }),
    );
    
    print('Response: ${response.body}');
    if (response.statusCode == 200) {
      print('✅ Test notification sent successfully!');
    } else {
      print('❌ Error: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('❌ Error sending test notification: $e');
  }
}
```

### Option B: Using PrayerTimeService Method

```dart
// Test using the service method
final prayerTimeService = PrayerTimeService();
final prayerTimes = await prayerTimeService.getPrayerTimes();
final asrPrayer = prayerTimes.firstWhere((p) => p.name == 'Asr');
await prayerTimeService.sendPrayerPushNotification(asrPrayer);
print('✅ Prayer push notification sent!');
```

## Quick Test Script

Save this as `test_prayer_notification.sh`:

```bash
#!/bin/bash

# Replace with your actual region
REGION="us-central1"

echo "Testing prayer push notification..."
echo "Region: $REGION"
echo ""

curl -X POST "https://${REGION}-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification" \
  -H "Content-Type: application/json" \
  -d '{
    "prayerName": "Asr",
    "message": "Asr time — remember Allah. (Test Notification)"
  }' \
  | jq '.'

echo ""
echo "✅ If you see a success response above, check your device for the notification!"
```

Make it executable and run:
```bash
chmod +x test_prayer_notification.sh
./test_prayer_notification.sh
```

## Verify Everything Works

After testing, check:

1. ✅ **Notification received** on device
2. ✅ **Function logs** show success:
   ```bash
   firebase functions:log --only sendPrayerTimeNotification
   ```
3. ✅ **Notification appears** with correct:
   - Title: "Asr"
   - Body: "Asr time — remember Allah. (Test Notification)"
   - Sound plays
   - Correct notification channel (prayer_time_channel on Android)

## Next Steps

Once testing works:

1. ✅ Set up Cloud Scheduler for automatic notifications at prayer times
2. ✅ Verify all prayer times are correct in Firestore
3. ✅ Test each prayer time individually
4. ✅ Monitor function logs for a few days to ensure reliability

## Need Help?

- Check function logs: `firebase functions:log --only sendPrayerTimeNotification`
- Check FCM tokens in Firestore: `employees` collection
- Review troubleshooting guide: `PRAYER_PUSH_NOTIFICATIONS_TROUBLESHOOTING.md`

