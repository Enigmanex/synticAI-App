# Deploy Push Notifications - Quick Start Guide

## ✅ Code is Ready!

All the code changes are complete. Now you just need to deploy the Cloud Function.

## Steps to Deploy:

### 1. Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
```

### 2. Login to Firebase
```bash
firebase login
```

### 3. Install Function Dependencies
```bash
cd functions
npm install
```

### 4. Deploy the Function
```bash
cd ..
firebase deploy --only functions
```

That's it! 🎉

## Verify It's Working:

1. **Check Firestore**: After creating a leave application or announcement, check the `notification_requests` collection in Firestore. You should see documents with `status: 'pending'` that get updated to `status: 'sent'`.

2. **Check Function Logs**: 
   ```bash
   firebase functions:log
   ```

3. **Test Notifications**:
   - Create a leave application → Admin should receive notification
   - Check in/out → Admin should receive notification  
   - Create announcement → Employees/Interns should receive notification
   - Approve/reject leave → Employee/Intern should receive notification

## Troubleshooting:

- **No notifications received?**
  - Check that FCM tokens are saved in the `employees` collection
  - Check the `notification_requests` collection for errors
  - Check function logs: `firebase functions:log`
  - Make sure notification permissions are granted on the device

- **Function deployment failed?**
  - Make sure you're logged in: `firebase login`
  - Check that you have the correct Firebase project selected: `firebase use --add`
  - Ensure Node.js 18+ is installed: `node --version`

## Important Notes:

- The function automatically handles invalid tokens (removes them from user documents)
- Notifications work for both Android and iOS
- Make sure Cloud Messaging API is enabled in Firebase Console
- For iOS, APNs certificates need to be configured in Firebase Console

