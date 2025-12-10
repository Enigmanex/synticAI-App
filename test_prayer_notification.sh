#!/bin/bash

# Test Prayer Push Notification Script
# This script sends a test Asr prayer notification immediately

echo "=========================================="
echo "Testing Prayer Push Notification"
echo "=========================================="
echo ""

# Default region - replace with your actual region if different
# Common regions: us-central1, asia-south1, europe-west1
REGION="${1:-us-central1}"

echo "Using region: $REGION"
echo "Project: readpro-c466c"
echo ""

# Function URL
FUNCTION_URL="https://${REGION}-readpro-c466c.cloudfunctions.net/sendPrayerTimeNotification"

echo "Sending test notification for Asr..."
echo "Function URL: $FUNCTION_URL"
echo ""

# Send the notification
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "prayerName": "Asr",
    "message": "Asr time — remember Allah. (Test Notification)"
  }')

# Extract HTTP status and body
HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "Response:"
echo "----------------------------------------"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo "----------------------------------------"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ SUCCESS! Notification sent successfully!"
    echo ""
    echo "Check your device now - you should receive the notification!"
    echo ""
    echo "If you don't receive it, check:"
    echo "  1. FCM tokens are stored in Firestore (employees collection)"
    echo "  2. Notification permissions are granted"
    echo "  3. Device is not in Do Not Disturb mode"
    echo "  4. Check function logs: firebase functions:log --only sendPrayerTimeNotification"
else
    echo "❌ ERROR: HTTP Status $HTTP_STATUS"
    echo ""
    echo "Common issues:"
    echo "  1. Function not deployed - run: firebase deploy --only functions"
    echo "  2. Wrong region - check your function URL in Firebase Console"
    echo "  3. Function error - check logs: firebase functions:log"
    echo ""
    echo "To find your region:"
    echo "  1. Go to Firebase Console → Functions"
    echo "  2. Click on sendPrayerTimeNotification"
    echo "  3. Copy the region from the trigger URL"
    echo "  4. Run: ./test_prayer_notification.sh YOUR_REGION"
fi

echo ""
echo "=========================================="

