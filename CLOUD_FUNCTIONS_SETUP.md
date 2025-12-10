# Cloud Functions Setup for Push Notifications

This app uses Firebase Cloud Messaging (FCM) for push notifications. To actually send notifications, you need to set up a Cloud Function that processes notification requests from Firestore.

## Setup Instructions

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
firebase login
```

### 2. Initialize Firebase Functions
```bash
cd your-project-root
firebase init functions
```

### 3. Install Dependencies
```bash
cd functions
npm install firebase-admin
```

### 4. Create the Cloud Function

Create `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.firestore
  .document('notification_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const request = snap.data();
    
    // Only process pending requests
    if (request.status !== 'pending') {
      return null;
    }

    const message = {
      notification: {
        title: request.title,
        body: request.body,
      },
      data: {
        ...request.data,
        type: request.data?.type || 'general',
      },
      token: request.fcmToken,
    };

    try {
      // Send notification via FCM
      const response = await admin.messaging().send(message);
      console.log('Successfully sent message:', response);

      // Update request status
      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response,
      });

      return null;
    } catch (error) {
      console.error('Error sending message:', error);
      
      // Update request status to failed
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return null;
    }
  });
```

### 5. Deploy the Function
```bash
firebase deploy --only functions
```

## How It Works

1. When a notification needs to be sent, the app creates a document in the `notification_requests` collection in Firestore.
2. The Cloud Function listens for new documents in this collection.
3. When a new request is created, the function:
   - Reads the FCM token and notification data
   - Sends the notification via Firebase Admin SDK
   - Updates the request status to 'sent' or 'failed'

## Testing

After deployment, notifications will be automatically sent when:
- Employees check in/check out (admin receives notification)
- Leave applications are approved/rejected (employee receives notification)
- New announcements are created (employees receive notification)

## Alternative: Using HTTP API

If you prefer not to use Cloud Functions, you can set up a backend server that:
1. Listens to the `notification_requests` collection
2. Uses Firebase Admin SDK to send notifications
3. Updates the request status

## Notes

- Make sure your Firebase project has Cloud Messaging API enabled
- For iOS, you need to configure APNs certificates in Firebase Console
- For Android, FCM works automatically with your Firebase project

