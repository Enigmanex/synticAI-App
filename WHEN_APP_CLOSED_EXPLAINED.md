# Notifications When App is Closed - Explained

## Simple Answer:

### Local Notifications (Scheduled on Device):
✅ **Work when app is closed** (once scheduled)
- Scheduled directly on your device
- Work independently of the app
- Triggered by device's notification system

### Push Notifications (Auto-send):
❌ **Don't work when app is closed**
- Need app running to trigger
- Timer stops when app is closed
- Need Cloud Scheduler (requires admin) to work when app is closed

---

## What Happens When You Change Prayer Time:

### Scenario 1: App is OPEN when you change time
1. You change prayer time in Firestore
2. App detects change immediately (listener active)
3. App reschedules local notifications
4. ✅ Local notifications work at new time (even when app closed!)

### Scenario 2: App is CLOSED when you change time
1. You change prayer time in Firestore
2. App doesn't know (listener not active)
3. **Next time you open app** → Detects change → Reschedules
4. ✅ Local notifications work at new time (after app opens once)

---

## The Key Point:

**Local notifications work when app is closed, BUT:**
- They need to be rescheduled after prayer time changes
- Rescheduling happens when app opens
- After rescheduling, they work independently!

---

## Solution:

### Simple Workflow:
1. **Change prayer time** in Firestore
2. **Open the app** (just open and close it - takes 5 seconds)
3. **App detects change** and reschedules notifications
4. **Close the app**
5. ✅ **Notifications work at new time!** (even when app closed)

---

## Why Push Notifications Don't Work When App is Closed:

The auto-send push notification uses a timer that:
- Runs every 30 seconds
- Only works when app is running
- Stops when app is closed

**This is expected behavior** - timers can't run when app is closed.

---

## Best Solution:

**Use Local Notifications** - they're designed for this!
- ✅ Work when app is closed
- ✅ More reliable
- ✅ Don't need internet
- ✅ Already implemented in your app

Just remember: **Open app once after changing prayer time** to reschedule!

---

## Summary:

**Current Behavior:**
- Local notifications: ✅ Work when app closed (after rescheduling)
- Push notifications: ❌ Need app running

**What to do:**
- Change prayer time in Firestore
- Open app (triggers rescheduling)
- Close app
- ✅ Notifications work!

This is normal and expected behavior! 🎯

