import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

// Global instance for background handler
final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  print('Notification title: ${message.notification?.title}');
  print('Notification body: ${message.notification?.body}');
  print('Data: ${message.data}');

  // Initialize notifications if not already initialized
  if (Platform.isAndroid) {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotificationsPlugin.initialize(initSettings);

    // Create notification channels
    const AndroidNotificationChannel prayerChannel = AndroidNotificationChannel(
      'prayer_time_channel',
      'Prayer Time Notifications',
      description: 'Notifications for prayer times',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel attendanceChannel =
        AndroidNotificationChannel(
      'attendance_app_channel',
      'Attendance App Notifications',
      description: 'Notifications for attendance, leave, and announcements',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(prayerChannel);

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(attendanceChannel);
  }

  // Determine which channel to use based on notification data
  final notificationType = message.data['type'] as String?;
  final channelId = notificationType == 'prayer_time'
      ? 'prayer_time_channel'
      : 'attendance_app_channel';
  final channelName = notificationType == 'prayer_time'
      ? 'Prayer Time Notifications'
      : 'Attendance App Notifications';

  // Show notification
  final notification = message.notification;
  if (notification != null) {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: notificationType == 'prayer_time'
          ? 'Notifications for prayer times'
          : 'Notifications for attendance, leave, and announcements',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      message.hashCode,
      notification.title ?? 'Notification',
      notification.body ?? '',
      details,
      payload: message.data.toString(),
    );

    print('Background notification displayed successfully');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('User granted provisional notification permission');
      } else {
        print('User declined notification permission');
        return;
      }

      // Initialize local notifications for foreground messages
      await _initializeLocalNotifications();

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
        print('FCM Token: $token');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a notification
      RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _initialized = true;
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (response.payload != null) {
          _handleNotificationTap(response.payload!);
        }
      },
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      // Create attendance app channel
      const AndroidNotificationChannel attendanceChannel = AndroidNotificationChannel(
        'attendance_app_channel',
        'Attendance App Notifications',
        description: 'Notifications for attendance, leave, and announcements',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(attendanceChannel);

      // Create prayer time channel
      const AndroidNotificationChannel prayerChannel = AndroidNotificationChannel(
        'prayer_time_channel',
        'Prayer Time Notifications',
        description: 'Notifications for prayer times',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(prayerChannel);
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      // Get current user ID from local storage or auth
      // This should be called after user login
      // For now, we'll store it when user logs in
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  /// Save token for specific user
  Future<void> saveUserToken(String userId, String token) async {
    try {
      // Use set with merge to handle cases where document might not exist yet
      await _db.collection('employees').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    print('Notification title: ${message.notification?.title}');
    print('Notification body: ${message.notification?.body}');
    print('Data: ${message.data}');

    // Determine if this is a prayer notification
    final notificationType = message.data['type'] as String?;
    final isPrayerNotification = notificationType == 'prayer_time';

    // Show local notification with appropriate channel
    _showLocalNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
      isPrayerNotification: isPrayerNotification,
    );
  }

  /// Handle message when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('App opened from notification: ${message.messageId}');
    _handleNotificationTap(message.data.toString());
  }

  /// Handle notification tap
  void _handleNotificationTap(String payload) {
    // Parse payload and navigate accordingly
    // This can be extended based on notification type
    print('Notification tapped: $payload');
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    bool isPrayerNotification = false,
  }) async {
    final channelId = isPrayerNotification
        ? 'prayer_time_channel'
        : 'attendance_app_channel';
    final channelName = isPrayerNotification
        ? 'Prayer Time Notifications'
        : 'Attendance App Notifications';
    final channelDescription = isPrayerNotification
        ? 'Notifications for prayer times'
        : 'Notifications for attendance, leave, and announcements';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('sendNotificationToUser called: userId=$userId, title=$title');
      
      // Get user's FCM token from Firestore
      final userDoc = await _db.collection('employees').doc(userId).get();
      if (!userDoc.exists) {
        print('ERROR: User document not found for userId: $userId');
        print('Attempting to send notification anyway...');
        // Still try to create notification request - maybe user will get token later
        // But we need at least a placeholder token or handle this differently
        await _storeNotification(userId, title, body, data);
        print('Notification stored in notifications collection (no FCM token available)');
        return;
      }

      final userData = userDoc.data();
      final fcmToken = userData?['fcmToken'] as String?;
      final userName = userData?['name'] as String? ?? 'Unknown';

      print('User found: $userName, FCM token present: ${fcmToken != null && fcmToken.isNotEmpty}');

      if (fcmToken == null || fcmToken.isEmpty) {
        print('WARNING: No FCM token found for user: $userId ($userName)');
        print('Storing notification for later delivery...');
        // Still store notification for when user gets token
        await _storeNotification(userId, title, body, data);
        print('Notification stored in notifications collection');
        return;
      }
      
      print('FCM token found, proceeding with notification request...');

      // Check for duplicate notification requests in the last 5 seconds
      // This prevents duplicate notifications from being sent
      // Note: For progress_remarks type, we allow duplicates if content is different
      final notificationType = data?['type'] as String?;
      final shouldCheckDuplicates = notificationType != 'progress_remarks';
      
      if (shouldCheckDuplicates) {
        final now = DateTime.now();
        final fiveSecondsAgo = now.subtract(const Duration(seconds: 5));
        
        try {
          final duplicateCheck = await _db
              .collection('notification_requests')
              .where('userId', isEqualTo: userId)
              .where('title', isEqualTo: title)
              .where('body', isEqualTo: body)
              .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveSecondsAgo))
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

          if (duplicateCheck.docs.isNotEmpty) {
            print('Duplicate notification detected, skipping: $title');
            return;
          }
        } catch (e) {
          // If duplicate check fails (e.g., missing index), continue anyway
          print('Warning: Could not check for duplicates: $e');
        }
      } else {
        print('Skipping duplicate check for progress_remarks notification');
      }

      // Store notification request in Firestore for Cloud Function to process
      // Cloud Function will pick this up and send the actual notification
      // IMPORTANT: FCM data payload requires all values to be strings
      final sanitizedData = _sanitizeDataForFCM(data);
      
      print('Creating notification request for userId: $userId, title: $title');
      print('FCM token length: ${fcmToken.length}');
      print('Original data: ${data?.toString()}');
      print('Sanitized data: ${sanitizedData.toString()}');
      print('Sanitized data types: ${sanitizedData.map((k, v) => MapEntry(k, v.runtimeType.toString()))}');
      
      // Convert sanitized data to Map<String, dynamic> for Firestore
      // This ensures Firestore stores values as strings, not auto-converting them
      final firestoreData = <String, dynamic>{};
      for (var entry in sanitizedData.entries) {
        firestoreData[entry.key] = entry.value; // Already a string from sanitization
      }
      
      try {
        final requestRef = await _db.collection('notification_requests').add({
          'userId': userId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': firestoreData, // Use explicitly converted map
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ Notification request created successfully with ID: ${requestRef.id}');
        print('Request will be processed by Cloud Function');
      } catch (e) {
        print('❌ ERROR creating notification request: $e');
        rethrow;
      }

      // Also store notification in notifications collection for tracking
      try {
        await _storeNotification(userId, title, body, data);
        print('✅ Notification stored in notifications collection for userId: $userId');
      } catch (e) {
        print('⚠️ Warning: Could not store notification in notifications collection: $e');
        // Don't rethrow - this is not critical
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  /// Sanitize data for FCM - convert all values to strings
  /// FCM data payload requires all values to be strings
  Map<String, String> _sanitizeDataForFCM(Map<String, dynamic>? data) {
    if (data == null) return {};
    
    final sanitized = <String, String>{};
    for (var entry in data.entries) {
      // Convert all values to strings
      if (entry.value == null) {
        sanitized[entry.key] = '';
      } else if (entry.value is String) {
        sanitized[entry.key] = entry.value as String;
      } else if (entry.value is bool) {
        sanitized[entry.key] = entry.value.toString();
      } else if (entry.value is num) {
        sanitized[entry.key] = entry.value.toString();
      } else {
        // For any other type, convert to string
        sanitized[entry.key] = entry.value.toString();
      }
    }
    return sanitized;
  }

  /// Store notification in Firestore
  Future<void> _storeNotification(
    String userId,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error storing notification: $e');
    }
  }

  /// Send notification to multiple users
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    for (String userId in userIds) {
      await sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  /// Send notification to all employees
  Future<void> sendNotificationToAllEmployees({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final employeesSnapshot = await _db.collection('employees').get();
      final employeeIds = employeesSnapshot.docs
          .where((doc) => doc.data()['role'] != 'admin')
          .map((doc) => doc.id)
          .toList();

      await sendNotificationToUsers(
        userIds: employeeIds,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('Error sending notification to all employees: $e');
    }
  }

  /// Send notification to employees in a department
  Future<void> sendNotificationToDepartment({
    required String department,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final employeesSnapshot = await _db
          .collection('employees')
          .where('department', isEqualTo: department)
          .get();

      final employeeIds =
          employeesSnapshot.docs.map((doc) => doc.id).toList();

      await sendNotificationToUsers(
        userIds: employeeIds,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('Error sending notification to department: $e');
    }
  }

  /// Get FCM token
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
}

