# Debug Steps: What's Not Working?

Let me help you figure out what's wrong. Please check these:

## 1. Are Scheduled Notifications Created in Firestore?

**Check:**
1. Open Firebase Console
2. Go to Firestore Database
3. Look for collection: `scheduled_push_notifications`
4. Do you see any documents?

**If NO documents:**
- The app hasn't created scheduled notifications yet
- Need to open app once after changing prayer time

**If YES, documents exist:**
- Check the `status` field - should be `"pending"`
- Check `scheduledFor` - should be a Timestamp in the future
- Continue to step 2

---

## 2. Is Cloud Scheduler Running?

**Check:**
1. Go to Google Cloud Console
2. Navigate to Cloud Scheduler
3. Find job: `processScheduledPushNotifications`
4. Is it **enabled**? (should be green/enabled)
5. Check "Last execution time" - when was it last run?

**If job doesn't exist:**
- Need to redeploy the function

**If job exists but not enabled:**
- Enable it manually

**If job is enabled:**
- Continue to step 3

---

## 3. What Error Do You See?

Please share:
- Are you receiving notifications at all?
- Are notifications arriving late?
- Are they not arriving when app is closed?
- What exactly happens?

---

## 4. Quick Test

Let's test step by step:

1. **Change prayer time** in Firestore to 2 minutes from now
   - Go to: `settings/prayer_times`
   - Update one prayer time

2. **Open your app once**
   - Check console logs
   - Look for: "Scheduling push notification requests"

3. **Check Firestore:**
   - Go to `scheduled_push_notifications` collection
   - Should see new document with your prayer name
   - Check `scheduledFor` timestamp

4. **Close app completely**

5. **Wait for prayer time**

6. **Check:**
   - Did you receive notification?
   - Check Cloud Function logs
   - Check Firestore `prayer_notifications_sent` collection

---

## What to Share

Please tell me:
1. ✅/❌ Do you see documents in `scheduled_push_notifications`?
2. ✅/❌ Is Cloud Scheduler job enabled?
3. ✅/❌ What happens when you test?
4. ❓ What error/issue do you see?

This will help me fix it quickly!

