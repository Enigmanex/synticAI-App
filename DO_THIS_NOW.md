# DO THIS NOW - Simple Steps

## 🎯 Your Region is: `us-central1`

I can see your function is in `us-central1` region.

---

## Step 1: Deploy the Function (2 minutes)

Run these commands:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions:sendPrayerTimeNotification
```

**Wait for it to finish** - you'll see "✔ Deploy complete!"

---

## Step 2: Test the Notification (30 seconds)

Once deployment is done, run this command:

```bash
curl -X POST https://us-central1-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

Or use the test script:
```bash
./test_prayer_notification.sh us-central1
```

---

## Step 3: Check Your Device

- ✅ You should receive the notification immediately!
- ✅ Title: "Asr"
- ✅ Message: "Asr time — remember Allah. (Test Notification)"

---

## ⚠️ If You Don't Receive Notification

### Quick Checks:

1. **Do you have FCM token?**
   - Log out and log back in to the app (token is saved on login)
   - Or check Firestore → `employees` → your user doc → should have `fcmToken`

2. **Are notifications enabled?**
   - Android: Settings → Apps → Attendance App → Notifications → Enable
   - iOS: Settings → Attendance App → Notifications → Enable

3. **Check the response:**
   - After running the curl command, you should see a JSON response
   - If it says "success: true", the function worked!
   - Check `recipients` count - should be > 0

4. **Check logs:**
   ```bash
   firebase functions:log --only sendPrayerTimeNotification
   ```

---

## That's It!

Once you receive the test notification, you're all set! 🎉

Then you can set up Cloud Scheduler for automatic notifications at prayer times (optional).

