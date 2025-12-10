const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function to send push notifications
 * Triggered when a new document is created in notification_requests collection
 */
exports.sendNotification = functions.firestore
    .document("notification_requests/{requestId}")
    .onCreate(async (snap, context) => {
      const request = snap.data();

      // Only process pending requests
      if (request.status !== "pending") {
        console.log("Request status is not pending, skipping:", request.status);
        return null;
      }

      // Validate required fields
      if (!request.fcmToken || !request.title || !request.body) {
        console.error("Missing required fields in notification request:", {
          hasToken: !!request.fcmToken,
          hasTitle: !!request.title,
          hasBody: !!request.body,
        });

        await snap.ref.update({
          status: "failed",
          error: "Missing required fields (fcmToken, title, or body)",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return null;
      }

      // Determine channel based on notification type
      const notificationType = (request.data && request.data.type) || "general";
      const channelId =
          notificationType === "prayer_time" ?
          "prayer_time_channel" :
          "attendance_app_channel";

      // Sanitize data - FCM requires all data values to be strings
      const sanitizedData = {};
      if (request.data) {
        for (const [key, value] of Object.entries(request.data)) {
          // Convert all values to strings
          if (value === null || value === undefined) {
            sanitizedData[key] = "";
          } else if (typeof value === "string") {
            sanitizedData[key] = value;
          } else {
            // Convert boolean, number, or any other type to string
            sanitizedData[key] = String(value);
          }
        }
      }
      // Ensure type is always a string
      sanitizedData.type = String(notificationType);

      const message = {
        notification: {
          title: request.title,
          body: request.body,
        },
        data: sanitizedData,
        token: request.fcmToken,
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: channelId,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
      // Send notification via FCM
        const response = await admin.messaging().send(message);
        console.log("Successfully sent message:", response);

        // Update request status
        await snap.ref.update({
          status: "sent",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          messageId: response,
        });

        return null;
      } catch (error) {
        console.error("Error sending message:", error);

        // Handle invalid token errors
        if (error.code === "messaging/invalid-registration-token" ||
          error.code === "messaging/registration-token-not-registered") {
          console.log(
              "Invalid or unregistered token, removing from user document");

          // Try to remove the invalid token from the user's document
          if (request.userId) {
            try {
              await admin.firestore()
                  .collection("employees")
                  .doc(request.userId)
                  .update({
                    fcmToken: admin.firestore.FieldValue.delete(),
                  });
            } catch (updateError) {
              console.error("Error removing invalid token:", updateError);
            }
          }
        }

        // Update request status to failed
        await snap.ref.update({
          status: "failed",
          error: error.message,
          errorCode: error.code,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return null;
      }
    });

/**
 * Cloud Function to send prayer time notifications to all users
 * This should be triggered by Cloud Scheduler at each prayer time
 * Example schedule: "28 5 * * *" for Fajr at 5:28 AM
 */
exports.sendPrayerTimeNotification =
    functions.https.onRequest(async (req, res) => {
      try {
        // Get prayer name from query parameter or request body
        const prayerName = req.query.prayerName || req.body.prayerName;
        const prayerMessage = req.query.message || req.body.message;

        if (!prayerName || !prayerMessage) {
          return res.status(400).json({
            error: "Missing required parameters: prayerName and message",
          });
        }

        console.log(`Sending prayer time notification: ${prayerName}`);
        console.log(`Message: ${prayerMessage}`);

        // Get all employees (including admins)
        const employeesSnapshot = await admin.firestore()
            .collection("employees")
            .get();

        console.log(`Total employees found: ${employeesSnapshot.size}`);

        const notificationPromises = [];
        let validTokenCount = 0;
        let noTokenCount = 0;

        employeesSnapshot.forEach((doc) => {
          const employeeData = doc.data();
          const fcmToken = employeeData.fcmToken;

          if (fcmToken && fcmToken.trim().length > 0) {
            validTokenCount++;
            const message = {
              notification: {
                title: prayerName,
                body: prayerMessage,
              },
              data: {
                type: "prayer_time",
                prayerName: prayerName,
              },
              token: fcmToken,
              android: {
                priority: "high",
                notification: {
                  sound: "default",
                  channelId: "prayer_time_channel",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            };

            notificationPromises.push(
                admin.messaging().send(message).catch((error) => {
                  const email = employeeData.email || "unknown";
                  console.error(
                      `Error sending to ${doc.id} (${email}):`,
                      error,
                  );
                  // Remove invalid tokens
                  if (error.code === "messaging/invalid-registration-token" ||
                  error.code ===
                  "messaging/registration-token-not-registered") {
                    console.log(`Removing invalid token for user ${doc.id}`);
                    return admin.firestore()
                        .collection("employees")
                        .doc(doc.id)
                        .update({
                          fcmToken: admin.firestore.FieldValue.delete(),
                        });
                  }
                }),
            );
          } else {
            noTokenCount++;
            const email = employeeData.email || "unknown";
            console.log(`No FCM token found for user ${doc.id} (${email})`);
          }
        });

        console.log(
            `Sending to ${validTokenCount} users with tokens, ` +
        `${noTokenCount} users without tokens`,
        );

        const results = await Promise.allSettled(notificationPromises);
        const successCount =
        results.filter((r) => r.status === "fulfilled").length;
        const failureCount =
        results.filter((r) => r.status === "rejected").length;

        console.log(
            `Prayer time notification sent: ${successCount} successful, ` +
        `${failureCount} failed`,
        );

        return res.status(200).json({
          success: true,
          message: `Prayer time notification sent: ${prayerName}`,
          recipients: notificationPromises.length,
          successCount: successCount,
          failureCount: failureCount,
          totalEmployees: employeesSnapshot.size,
          usersWithTokens: validTokenCount,
          usersWithoutTokens: noTokenCount,
        });
      } catch (error) {
        console.error("Error sending prayer time notification:", error);
        return res.status(500).json({
          error: "Failed to send prayer time notification",
          details: error.message,
        });
      }
    });

/**
 * Cloud Function to process scheduled push notifications
 * This runs every minute via Cloud Scheduler to check for due notifications
 * and send them even when app is closed
 */
exports.processScheduledPushNotifications = functions.pubsub
    .schedule("every 1 minutes")
    .timeZone("UTC")
    .onRun(async (context) => {
      try {
        console.log("=== Checking for scheduled push notifications ===");
        const now = admin.firestore.Timestamp.now();
        const nowDate = now.toDate();

        // Get all pending scheduled notifications that are due
        // Query for status == "pending" and scheduledFor <= now
        // Filter in memory for notifications within last 2 minutes
        const twoMinutesAgo = admin.firestore.Timestamp.fromDate(
            new Date(nowDate.getTime() - 2 * 60 * 1000),
        );

        // Get all pending notifications (simplified query to avoid index)
        // We'll filter in memory for notifications that are due
        const scheduledQuery = await admin.firestore()
            .collection("scheduled_push_notifications")
            .where("status", "==", "pending")
            .limit(100)
            .get();

        // Filter to only process notifications that are due
        // (scheduledFor <= now) and within last 2 minutes to catch missed ones
        const notificationsToProcess = scheduledQuery.docs.filter((doc) => {
          const scheduledFor = doc.data().scheduledFor;
          if (!scheduledFor) return false;
          const scheduledTime = scheduledFor.toDate();
          const isDue = scheduledTime <= nowDate;
          const isRecent = scheduledTime >= twoMinutesAgo.toDate();
          return isDue && isRecent;
        });

        console.log(
            `Found ${scheduledQuery.size} pending notifications, ` +
        `${notificationsToProcess.length} within last 2 minutes to process`,
        );

        if (notificationsToProcess.length === 0) {
          console.log("No scheduled notifications to process");
          return null;
        }

        // Get all employees with FCM tokens
        const employeesSnapshot = await admin.firestore()
            .collection("employees")
            .get();

        const employees = [];
        employeesSnapshot.forEach((doc) => {
          const data = doc.data();
          if (data.fcmToken && data.fcmToken.trim().length > 0) {
            employees.push({
              id: doc.id,
              fcmToken: data.fcmToken,
              email: data.email || "unknown",
            });
          }
        });

        console.log(`Found ${employees.length} employees with FCM tokens`);

        if (employees.length === 0) {
          console.log("No employees with FCM tokens found");
          return null;
        }

        const batch = admin.firestore().batch();
        let processedCount = 0;
        let successCount = 0;
        let failureCount = 0;

        // Process each scheduled notification
        for (const scheduledDoc of notificationsToProcess) {
          const scheduledData = scheduledDoc.data();
          const prayerName = scheduledData.prayerName;
          const message = scheduledData.message ||
            `${prayerName} time — remember Allah.`;

          console.log(`Processing scheduled notification: ${prayerName}`);

          // Check if already sent today (prevent duplicates)
          const today = new Date(nowDate);
          today.setHours(0, 0, 0, 0);
          const month = String(today.getMonth() + 1).padStart(2, "0");
          const day = String(today.getDate()).padStart(2, "0");
          const dateString = `${today.getFullYear()}-${month}-${day}`;
          const sentDocId = `${prayerName}_${dateString}`;
          const sentDocRef = admin.firestore()
              .collection("prayer_notifications_sent")
              .doc(sentDocId);

          const sentDoc = await sentDocRef.get();

          if (sentDoc.exists) {
            console.log(
                `Push notification for ${prayerName} ` +
                "already sent today, skipping",
            );
            // Mark as skipped
            batch.update(scheduledDoc.ref, {
              status: "skipped",
              reason: "Already sent today",
              processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            processedCount++;
            continue;
          }

          // Mark as sent first to prevent duplicates
          await sentDocRef.set({
            prayerName: prayerName,
            date: admin.firestore.Timestamp.fromDate(today),
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            sentByDevice: "cloud_scheduler",
          });

          // Send to all employees
          const notificationPromises = employees.map((employee) => {
            const notificationMessage = {
              notification: {
                title: prayerName,
                body: message,
              },
              data: {
                type: "prayer_time",
                prayerName: prayerName,
              },
              token: employee.fcmToken,
              android: {
                priority: "high",
                notification: {
                  sound: "default",
                  channelId: "prayer_time_channel",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            };

            return admin.messaging()
                .send(notificationMessage)
                .catch((error) => {
                  console.error(
                      `Error sending to ${employee.id} (${employee.email}):`,
                      error,
                  );
                  // Remove invalid tokens
                  if (
                    error.code === "messaging/invalid-registration-token" ||
                error.code === "messaging/registration-token-not-registered"
                  ) {
                    return admin.firestore()
                        .collection("employees")
                        .doc(employee.id)
                        .update({
                          fcmToken: admin.firestore.FieldValue.delete(),
                        });
                  }
                  return null;
                });
          });

          try {
            const results = await Promise.allSettled(notificationPromises);
            const success = results
                .filter((r) => r.status === "fulfilled").length;
            const failed = results
                .filter((r) => r.status === "rejected").length;

            successCount += success;
            failureCount += failed;

            console.log(
                `Sent ${prayerName} notification: ${success} successful, ` +
                `${failed} failed`,
            );

            // Mark as sent
            batch.update(scheduledDoc.ref, {
              status: "sent",
              sentAt: admin.firestore.FieldValue.serverTimestamp(),
              successCount: success,
              failureCount: failed,
            });
            processedCount++;
          } catch (error) {
            console.error(`Error processing ${prayerName}:`, error);
            batch.update(scheduledDoc.ref, {
              status: "failed",
              error: error.message,
              failedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            processedCount++;
            failureCount++;
          }
        }

        // Commit all updates
        if (processedCount > 0) {
          await batch.commit();
        }

        console.log(
            `=== Processed ${processedCount} scheduled notifications: ` +
        `${successCount} successful, ${failureCount} failed ===`,
        );

        return null;
      } catch (error) {
        console.error("Error processing scheduled notifications:", error);
        return null;
      }
    });

