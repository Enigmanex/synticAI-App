# Permission Fix Required

## ❌ Error Message

You got this error:
```
Error: Missing required permission on project readpro-c466c to deploy new HTTPS functions. 
The permission cloudfunctions.functions.setIamPolicy is required to deploy the following functions:
- sendPrayerTimeNotification
```

## ✅ How to Fix

You need to grant yourself (or your account) the **Cloud Functions Admin** role.

### Option 1: If You Are the Project Owner

1. Go to: https://console.cloud.google.com/iam-admin/iam?project=readpro-c466c
2. Find your email address in the list
3. Click the **pencil icon** (Edit) next to your name
4. Click **ADD ANOTHER ROLE**
5. Select **Cloud Functions Admin**
6. Click **SAVE**

### Option 2: Ask Project Owner to Grant Permission

1. Ask the project owner to go to: https://console.cloud.google.com/iam-admin/iam?project=readpro-c466c
2. Ask them to:
   - Find your email
   - Add the **Cloud Functions Admin** role
   - Save

### Option 3: Deploy from Firebase Console (Alternative)

If you can't get permissions, you can deploy via Firebase Console:

1. Go to: https://console.firebase.google.com/project/readpro-c466c/functions
2. Click **Deploy function manually** (if available)
3. Or ask someone with admin access to deploy

---

## After Fixing Permissions

Once you have the permission, try deploying again:

```bash
firebase deploy --only functions:sendPrayerTimeNotification
```

Then test with:

```bash
curl -X POST https://us-central1-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification \
  -H "Content-Type: application/json" \
  -d '{"prayerName":"Asr","message":"Asr time — remember Allah. (Test Notification)"}'
```

