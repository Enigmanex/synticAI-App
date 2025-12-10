# Notification Behavior: App Open vs Closed

## Two Types of Notifications:

### 1. **Local Notifications** (Scheduled on Device)
✅ **Work when app is CLOSED!**
- Scheduled on your device
- Triggered by the device's notification system
- Work even if app is completely closed
- Automatically rescheduled when you change prayer times in Firestore

### 2. **Push Notifications** (Sent from Server)
⚠️ **Only work when app is RUNNING** (without Cloud Scheduler)
- Need something to trigger them
- Currently triggered by periodic check in the app
- App must be running for the check to happen
- OR need Cloud Scheduler (requires admin access)

---

## Current Situation:

When you change prayer time in Firestore:

### ✅ Local Notifications:
- Automatically rescheduled
- Work at the new time
- Work even when app is closed
- **These should work!**

### ⚠️ Push Notifications:
- Use the new prayer time
- Only send if app is running at that time
- Don't send if app is closed (no way to trigger them)

---

## The Problem:

You're expecting **push notifications** to work when the app is closed, but they can't because:
- The periodic timer stops when app is closed
- No way to trigger them without Cloud Scheduler or app running

---

## Solutions:

### Option 1: Use Local Notifications (Recommended)
**They already work when app is closed!**
- Local notifications are scheduled on each device
- They trigger automatically at prayer time
- Work even when app is completely closed
- This is what most apps use!

**Check if local notifications are working:**
- Update prayer time in Firestore
- Close the app completely
- Wait for prayer time
- You should receive the notification!

### Option 2: Cloud Scheduler (Requires Admin Access)
- Set up Cloud Scheduler to trigger push notifications
- Works even when app is closed
- Requires admin access to set up

### Option 3: Keep App Running in Background
- Push notifications will work if app is in background
- But app must be running (not closed)

---

## What You Should Do:

### For Local Notifications (Recommended):
1. ✅ They already work when app is closed
2. ✅ Update prayer time in Firestore
3. ✅ Close the app
4. ✅ Wait for prayer time
5. ✅ You should receive notification!

**If local notifications don't work when app is closed, check:**
- Notification permissions granted?
- Battery optimization disabled?
- Exact alarm permission granted (Android 12+)?
- Device settings allow notifications when app is closed?

### For Push Notifications:
- Need app to be running OR Cloud Scheduler
- Without admin access, only works when app is running

---

## Recommendation:

**Use Local Notifications** - they're designed to work when the app is closed!

Push notifications are typically used for:
- Real-time messages
- Server-initiated notifications
- When you want to send to all users from server

Local notifications are perfect for:
- Scheduled reminders (like prayer times)
- Works offline
- Works when app is closed
- More reliable for time-based notifications

---

## Quick Test:

1. **Update prayer time** in Firestore (e.g., set to 5 minutes from now)
2. **Close the app completely**
3. **Wait for the prayer time**
4. **Check your device** - you should receive the local notification!

If local notifications work but push notifications don't when app is closed, that's expected behavior. Local notifications are the better solution for prayer time reminders!

