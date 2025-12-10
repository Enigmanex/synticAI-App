# Step-by-Step: Test Prayer Notification RIGHT NOW

Follow these steps in order:

## ✅ Step 1: Check if Cloud Function is Deployed

Run this command:
```bash
firebase functions:list
```

**What to look for:**
- You should see `sendPrayerTimeNotification` in the list
- Note the region (e.g., `us-central1`, `asia-south1`)

**If function is NOT listed**, deploy it first:
```bash
cd functions
npm install
cd ..
firebase deploy --only functions:sendPrayerTimeNotification
```

---

## ✅ Step 2: Get Your Function URL

You need to know your function URL. Two ways:

### Option A: From Terminal
After running `firebase functions:list`, you'll see the URL format.

### Option B: From Firebase Console
1. Go to: https://console.firebase.google.com/project/readpro-c466c/functions
2. Click on `sendPrayerTimeNotification`
3. Copy the **Trigger URL** (it looks like: `https://REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification`)
4. **Note the REGION** from the URL (e.g., `us-central1`)

---

## ✅ Step 3: Test the Notification

### Easy Way: Use the Test Script

```bash
./test_prayer_notification.sh YOUR_REGION
```

**Example** (replace with your actual region):
```bash
./test_prayer_notification.sh us-central1
```

### Or Use Curl Directly

Replace `YOUR-REGION` with your actual region:

```bash
curl -X POST https://YOUR-REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

**Example:**
```bash
curl -X POST https://us-central1-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

---

## ✅ Step 4: Check Your Device

After running the command:
- ✅ **You should receive a notification immediately** on your device
- ✅ Notification title: "Asr"
- ✅ Notification message: "Asr time — remember Allah. (Test Notification)"

---

## ❌ If You Don't Receive Notification

### Check 1: Function Response

After running the curl command, you should see a JSON response like:
```json
{
  "success": true,
  "message": "Prayer time notification sent: Asr",
  "recipients": 5
}
```

If you see an error, note what it says.

### Check 2: FCM Token

Make sure your FCM token is saved:
1. Go to: https://console.firebase.google.com/project/readpro-c466c/firestore
2. Open `employees` collection
3. Find your user document
4. Check if it has `fcmToken` field

**If no token:**
- Log out of the app
- Log back in (token is saved on login)

### Check 3: Notification Permissions

**Android:**
- Settings → Apps → Attendance App → Notifications → Enable

**iOS:**
- Settings → Attendance App → Notifications → Enable

### Check 4: Function Logs

```bash
firebase functions:log --only sendPrayerTimeNotification
```

Look for errors or success messages.

---

## 📋 Quick Checklist

Before testing, make sure:
- [ ] Cloud Function is deployed (`firebase functions:list` shows it)
- [ ] You know your function region
- [ ] You have FCM token in Firestore (log out/in if needed)
- [ ] Notification permissions granted on device

Then:
- [ ] Run the test command
- [ ] Check your device for notification
- [ ] Check function logs if no notification

---

## 🎯 What Happens Next?

Once testing works:
1. Set up Cloud Scheduler for automatic notifications at prayer times
2. See `PRAYER_PUSH_NOTIFICATIONS_TROUBLESHOOTING.md` for full setup

---

## 💡 Quick Commands Reference

```bash
# List functions (find region)
firebase functions:list

# Deploy function (if needed)
firebase deploy --only functions:sendPrayerTimeNotification

# Test notification (replace REGION)
./test_prayer_notification.sh REGION

# Check logs
firebase functions:log --only sendPrayerTimeNotification

# Test with curl (replace REGION)
curl -X POST https://REGION-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

