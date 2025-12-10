# Quick Test - Send Asr Notification Right Now

## 🚀 Fastest Way to Test (3 Steps)

### Step 1: Find Your Function URL

Run this command to list your deployed functions:
```bash
firebase functions:list
```

Or go to Firebase Console:
1. Open [Firebase Console → Functions](https://console.firebase.google.com/project/readpro-c466c/functions)
2. Click on `sendPrayerTimeNotification`
3. Copy the **Trigger URL** (looks like: `https://REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification`)
4. Note the **REGION** (e.g., `us-central1`, `asia-south1`)

### Step 2: Send Test Notification

**Option A: Using the test script** (easiest):
```bash
# Replace YOUR_REGION with your actual region
./test_prayer_notification.sh YOUR_REGION

# Example:
./test_prayer_notification.sh us-central1
```

**Option B: Using curl directly**:
```bash
curl -X POST https://YOUR-REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

**Replace `YOUR-REGION`** with your actual region!

### Step 3: Check Your Device

- ✅ You should receive the notification immediately
- ✅ Check the notification appears on your device

---

## 📋 Quick Reference

### Common Regions:
- `us-central1` (US Central)
- `asia-south1` (Mumbai)
- `europe-west1` (Belgium)
- `asia-east1` (Taiwan)

### Full Example:
```bash
# If your function is in us-central1:
curl -X POST https://us-central1-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

### Expected Response:
```json
{
  "success": true,
  "message": "Prayer time notification sent: Asr",
  "recipients": 5,
  "successCount": 5,
  "failureCount": 0
}
```

---

## 🔍 If It Doesn't Work

### 1. Check Function is Deployed
```bash
firebase functions:list
```
If you don't see `sendPrayerTimeNotification`, deploy it:
```bash
firebase deploy --only functions:sendPrayerTimeNotification
```

### 2. Check Function Logs
```bash
firebase functions:log --only sendPrayerTimeNotification
```

### 3. Verify FCM Tokens
- Go to Firestore → `employees` collection
- Check your user document has `fcmToken` field
- If missing, log out and log back in

### 4. Check Notification Permissions
- Android: Settings → Apps → Attendance App → Notifications → Enable
- iOS: Settings → Attendance App → Notifications → Enable

---

## 💡 Pro Tips

1. **Test immediately**: This method sends notification RIGHT NOW, no need to wait for prayer time
2. **Multiple tests**: You can run the command multiple times to test
3. **Change message**: Modify the message in the JSON to test different content
4. **Check logs**: Always check function logs if something doesn't work

---

## 🎯 Next Steps After Testing

Once testing works:
1. ✅ Set up Cloud Scheduler for automatic notifications at prayer times
2. ✅ See `PRAYER_PUSH_NOTIFICATIONS_TROUBLESHOOTING.md` for full setup guide

