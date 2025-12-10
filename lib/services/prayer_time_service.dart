import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/prayer_time.dart';

class PrayerTimeService {
  static final PrayerTimeService _instance = PrayerTimeService._internal();
  factory PrayerTimeService() => _instance;
  PrayerTimeService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _timezoneInitialized = false;
  bool _localNotificationsInitialized = false;
  StreamSubscription<DocumentSnapshot>? _prayerTimesListener;

  // Default prayer times
  static const List<PrayerTime> defaultPrayerTimes = [
    PrayerTime(
      name: 'Fajr',
      time: '05:28',
      message: 'Fajr time — begin your day with prayer.',
    ),
    PrayerTime(
      name: 'Zuhr',
      time: '13:30',
      message: 'Zuhr time — pause for prayer.',
    ),
    PrayerTime(
      name: 'Asr',
      time: '16:59',
      message: 'Asr time — remember Allah.',
    ),
    PrayerTime(
      name: 'Maghrib',
      time: '17:16',
      message: 'Maghrib azan — complete your day with prayer.',
    ),
    PrayerTime(
      name: 'Isha',
      time: '18:45',
      message: 'Isha time — end your day with prayer.',
    ),
  ];

  /// Initialize prayer times in Firebase (call this once)
  Future<void> initializePrayerTimes() async {
    try {
      final docRef = _db.collection('settings').doc('prayer_times');
      final doc = await docRef.get();

      if (!doc.exists) {
        // Store default prayer times
        final prayerTimesMap = {
          for (var prayer in defaultPrayerTimes) prayer.name: prayer.toMap(),
        };

        await docRef.set({
          'prayerTimes': prayerTimesMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Prayer times initialized in Firebase');
      } else {
        print('Prayer times already exist in Firebase');
      }
    } catch (e) {
      print('Error initializing prayer times: $e');
    }
  }

  /// Get prayer times from Firebase
  Future<List<PrayerTime>> getPrayerTimes() async {
    try {
      final doc = await _db.collection('settings').doc('prayer_times').get();
      if (!doc.exists) {
        // If not exists, initialize and return defaults
        await initializePrayerTimes();
        return defaultPrayerTimes;
      }

      final data = doc.data();
      final prayerTimesMap = data?['prayerTimes'] as Map<String, dynamic>?;

      if (prayerTimesMap == null) {
        return defaultPrayerTimes;
      }

      return prayerTimesMap.values
          .map((map) => PrayerTime.fromMap(Map<String, dynamic>.from(map)))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    } catch (e) {
      print('Error getting prayer times: $e');
      return defaultPrayerTimes;
    }
  }

  /// Update prayer times in Firebase
  Future<void> updatePrayerTimes(List<PrayerTime> prayerTimes) async {
    try {
      final prayerTimesMap = {
        for (var prayer in prayerTimes) prayer.name: prayer.toMap(),
      };

      await _db.collection('settings').doc('prayer_times').set({
        'prayerTimes': prayerTimesMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Reschedule notifications with new times
      await scheduleAllPrayerNotifications();
    } catch (e) {
      print('Error updating prayer times: $e');
    }
  }

  /// Initialize timezone data
  Future<void> _initializeTimezone() async {
    if (_timezoneInitialized) return;
    try {
      tz.initializeTimeZones();
      _timezoneInitialized = true;
      print('Timezone initialized successfully');
    } catch (e) {
      print('Error initializing timezone: $e');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsInitialized) return;

    try {
      print('Initializing local notifications plugin for prayer times...');

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

      final initialized = await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('Prayer notification tapped: ${response.payload}');
        },
      );

      // Auto-send push notifications will be handled via scheduled checks

      if (initialized == true) {
        _localNotificationsInitialized = true;
        print('Local notifications plugin initialized successfully');
      } else {
        print(
          'WARNING: Local notifications plugin initialization returned false or null',
        );
        // Still mark as initialized if we got here without exception
        _localNotificationsInitialized = true;
      }
    } catch (e) {
      print('Error initializing local notifications plugin: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Start listening for prayer time changes in Firebase
  void startListeningForPrayerTimeChanges() {
    // Cancel existing listener if any
    _prayerTimesListener?.cancel();

    print('Starting listener for prayer time changes...');

    // Listen for changes to prayer times document
    _prayerTimesListener = _db
        .collection('settings')
        .doc('prayer_times')
        .snapshots()
        .listen(
          (snapshot) async {
            if (snapshot.exists) {
              print(
                'Prayer times updated in Firebase, rescheduling notifications...',
              );
              print('Updated data: ${snapshot.data()}');
              await scheduleAllPrayerNotifications();
            } else {
              print('Prayer times document does not exist');
            }
          },
          onError: (error) {
            print('Error listening to prayer times: $error');
          },
        );
  }

  /// Stop listening for prayer time changes
  void stopListeningForPrayerTimeChanges() {
    _prayerTimesListener?.cancel();
    _prayerTimesListener = null;
  }

  /// Schedule all prayer notifications (repeats daily automatically)
  Future<void> scheduleAllPrayerNotifications() async {
    try {
      // Initialize timezone first
      await _initializeTimezone();

      // Ensure local notifications are initialized
      await _ensureLocalNotificationsInitialized();

      if (_localNotificationsInitialized == false) {
        print(
          'ERROR: Local notifications plugin not initialized. Cannot schedule notifications.',
        );
        return;
      }

      // Verify local notifications are initialized
      // Note: In release builds with R8, pendingNotificationRequests() may fail
      // due to ProGuard stripping type information. We'll catch and continue.
      int pendingCount = 0;
      try {
        final pendingNotifications = await _localNotifications
            .pendingNotificationRequests();
        pendingCount = pendingNotifications.length;
        print('Current pending notifications: $pendingCount');
      } catch (e) {
        print(
          'Note: Could not check pending notifications (ProGuard/R8 issue): $e',
        );
        print(
          'This is normal in release builds. Continuing to schedule notifications...',
        );
      }

      // Cancel all existing prayer notifications
      await cancelAllPrayerNotifications();

      final prayerTimes = await getPrayerTimes();
      print('Found ${prayerTimes.length} prayer times to schedule');

      int successCount = 0;
      int failCount = 0;

      // Schedule notifications for the next 30 days to ensure reliability
      // matchDateTimeComponents doesn't always work reliably on all devices
      for (var prayer in prayerTimes) {
        print('Scheduling ${prayer.name} at ${prayer.time} for next 30 days');
        try {
          // Schedule for next 30 days
          for (int day = 0; day < 30; day++) {
            try {
              await _schedulePrayerNotification(prayer, day);
            } catch (e) {
              print('Failed to schedule ${prayer.name} for day $day: $e');
            }
          }
          successCount++;
        } catch (e) {
          print('Failed to schedule ${prayer.name}: $e');
          failCount++;
        }
      }

      print(
        'Prayer notifications scheduled: $successCount successful, $failCount failed',
      );

      // Verify scheduled notifications (may fail in release builds due to ProGuard/R8)
      List<PendingNotificationRequest> scheduled = [];
      try {
        scheduled = await _localNotifications.pendingNotificationRequests();
        print('Total scheduled notifications: ${scheduled.length}');

        // Print details of scheduled notifications
        if (scheduled.isNotEmpty) {
          print('=== Scheduled Notification Details ===');
          for (var notif in scheduled) {
            print('  - ${notif.title} (ID: ${notif.id})');
            print('    Body: ${notif.body}');
          }
        }

        // Check if each prayer is scheduled
        for (var prayer in prayerTimes) {
          final isScheduled = scheduled.any((n) => n.title == prayer.name);
          if (!isScheduled) {
            print('⚠️ WARNING: ${prayer.name} notification is NOT scheduled!');
          }
        }
      } catch (e) {
        print(
          'Note: Could not verify scheduled notifications (ProGuard/R8 issue): $e',
        );
        print(
          'Notifications were scheduled, but we cannot verify them in release builds.',
        );
        print(
          'This is expected due to code shrinking. Notifications should still work.',
        );
      }

      if (scheduled.isEmpty && prayerTimes.isNotEmpty) {
        print('⚠️ WARNING: Could not verify if notifications were scheduled!');
        print('Possible reasons:');
        print('  1. ProGuard/R8 code shrinking (release builds)');
        print('  2. Notification permissions not granted');
        print('  3. Exact alarm permission not granted (Android 12+)');
        print('  4. Local notifications plugin not initialized');
        print('  5. All prayer times are in the past');
        print(
          'Note: Notifications may still be scheduled even if verification fails.',
        );
      }
    } catch (e) {
      print('Error scheduling prayer notifications: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Schedule a single prayer notification
  Future<void> _schedulePrayerNotification(
    PrayerTime prayer,
    int daysFromNow,
  ) async {
    try {
      if (!_localNotificationsInitialized) {
        print(
          'ERROR: Cannot schedule ${prayer.name} - local notifications not initialized',
        );
        return;
      }

      final now = DateTime.now();
      final targetDate = now.add(Duration(days: daysFromNow));

      // Create scheduled time
      var scheduledTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        prayer.hour,
        prayer.minute,
      );

      print(
        'Prayer: ${prayer.name}, Time: ${prayer.time}, Scheduled: ${scheduledTime.toString()}, Now: ${now.toString()}',
      );

      // If the time has already passed today, schedule for tomorrow
      // With matchDateTimeComponents, it will repeat daily, but we need to schedule
      // for a future time to ensure it triggers
      if (daysFromNow == 0 && scheduledTime.isBefore(now)) {
        print('Time has passed today, scheduling for tomorrow: ${prayer.name}');
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      await _scheduleNotificationAtTime(prayer, scheduledTime, daysFromNow);
    } catch (e) {
      print('Error scheduling prayer notification: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Schedule notification at specific time
  Future<void> _scheduleNotificationAtTime(
    PrayerTime prayer,
    DateTime scheduledTime,
    int daysFromNow,
  ) async {
    try {
      // Create unique ID for this prayer and day
      final id = _getPrayerNotificationId(prayer.name, scheduledTime);

      // Ensure notification channel is created (should already be created by NotificationService)
      // But we'll create it here as a fallback
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'prayer_time_channel',
          'Prayer Time Notifications',
          description: 'Notifications for prayer times',
          importance: Importance.high,
          playSound: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'prayer_time_channel',
            'Prayer Time Notifications',
            channelDescription: 'Notifications for prayer times',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Convert to TZDateTime - ensure we're using the local timezone
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      // Verify the scheduled time is in the future
      final now = tz.TZDateTime.now(tz.local);
      final timeDiff = tzScheduledTime.difference(now);

      print(
        'Scheduling ${prayer.name} notification for ${tzScheduledTime.toString()} (ID: $id)',
      );
      print('Current time: ${now.toString()}');
      print(
        'Time difference: ${timeDiff.inMinutes} minutes (${timeDiff.inSeconds} seconds)',
      );

      if (tzScheduledTime.isBefore(now)) {
        print('⚠️ WARNING: Scheduled time ${tzScheduledTime} is in the past!');
        print(
          'This notification may not trigger. Scheduling for tomorrow instead...',
        );
        // Schedule for tomorrow at the same time
        final tomorrow = tzScheduledTime.add(const Duration(days: 1));
        return await _scheduleNotificationAtTime(
          prayer,
          tomorrow.toLocal(),
          daysFromNow,
        );
      }

      // If time is too close (less than 1 second), schedule for tomorrow
      if (timeDiff.inSeconds < 1) {
        print('⚠️ Time is too close, scheduling for tomorrow');
        final tomorrow = tzScheduledTime.add(const Duration(days: 1));
        return await _scheduleNotificationAtTime(
          prayer,
          tomorrow.toLocal(),
          daysFromNow,
        );
      }

      // Try to schedule with exact alarm, fallback to inexact if permission not granted
      bool scheduled = false;

      try {
        // Schedule notification at the specific time with exact alarm
        // Don't use matchDateTimeComponents - we schedule multiple days explicitly
        await _localNotifications.zonedSchedule(
          id,
          prayer.name,
          prayer.message,
          tzScheduledTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          // Removed matchDateTimeComponents - scheduling multiple days explicitly is more reliable
        );

        print(
          '✓ Successfully scheduled ${prayer.name} notification (exact) for ${tzScheduledTime.toString()}',
        );
        scheduled = true;
      } on PlatformException catch (e) {
        if (e.code == 'exact_alarms_not_permitted') {
          print(
            'Exact alarms not permitted, falling back to inexact scheduling for ${prayer.name}',
          );
          try {
            // Fallback to inexact scheduling
            await _localNotifications.zonedSchedule(
              id,
              prayer.name,
              prayer.message,
              tzScheduledTime,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
            print(
              '✓ Successfully scheduled ${prayer.name} notification (inexact) for ${tzScheduledTime.toString()}',
            );
            scheduled = true;
          } catch (fallbackError) {
            print('Error with inexact scheduling: $fallbackError');
            // Try with regular inexact mode
            try {
              await _localNotifications.zonedSchedule(
                id,
                prayer.name,
                prayer.message,
                tzScheduledTime,
                details,
                androidScheduleMode: AndroidScheduleMode.inexact,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
              print(
                '✓ Successfully scheduled ${prayer.name} notification (inexact regular) for ${tzScheduledTime.toString()}',
              );
              scheduled = true;
            } catch (finalError) {
              print('Error with all scheduling modes: $finalError');
            }
          }
        } else {
          print('PlatformException with code ${e.code}: ${e.message}');
        }
      } catch (e) {
        print('Error scheduling notification at time: $e');
        print('Stack trace: ${StackTrace.current}');
      }

      if (!scheduled) {
        print(
          '✗ ERROR: Failed to schedule ${prayer.name} notification after trying all methods',
        );
        print('  - Prayer: ${prayer.name}');
        print('  - Time: ${prayer.time}');
        print('  - Scheduled time: ${tzScheduledTime.toString()}');
        print('  - Notification ID: $id');
        print('  - Please check:');
        print('    1. Notification permissions are granted');
        print('    2. Exact alarm permission is granted (Android 12+)');
        print('    3. Battery optimization is disabled for the app');
      }
    } catch (e) {
      print('Error in _scheduleNotificationAtTime: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Generate unique notification ID for prayer and day
  /// Each prayer gets a unique ID per day to allow multiple days to be scheduled
  int _getPrayerNotificationId(String prayerName, DateTime date) {
    // Create unique ID based on prayer name and day
    // This allows us to schedule multiple days ahead
    final prayerBaseIds = {
      'Fajr': 1000,
      'Zuhr': 2000,
      'Asr': 3000,
      'Maghrib': 4000,
      'Isha': 5000,
    };

    final baseId =
        prayerBaseIds[prayerName] ?? prayerName.hashCode.abs() % 10000;
    // Calculate days from today (0-29 for 30 days)
    final today = DateTime.now();
    final daysFromToday = date
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return baseId + (daysFromToday % 30);
  }

  /// Cancel all prayer notifications
  Future<void> cancelAllPrayerNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('All prayer notifications cancelled');
    } catch (e) {
      print('Error cancelling prayer notifications: $e');
    }
  }

  /// Manually reschedule all prayer notifications (useful for testing or manual updates)
  Future<void> rescheduleNotifications() async {
    print('Manually rescheduling prayer notifications...');
    await scheduleAllPrayerNotifications();
  }

  /// Test notification - send immediately (for debugging)
  Future<void> testNotification(String prayerName) async {
    try {
      print('=== TEST NOTIFICATION START ===');

      // Ensure notifications are initialized
      if (!_localNotificationsInitialized) {
        print('Initializing notifications for test...');
        await _ensureLocalNotificationsInitialized();
      }

      // Ensure channel is created
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'prayer_time_channel',
          'Prayer Time Notifications',
          description: 'Notifications for prayer times',
          importance: Importance.high,
          playSound: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
        print('Notification channel created/verified');
      }

      final prayerTimes = await getPrayerTimes();
      final prayer = prayerTimes.firstWhere(
        (p) => p.name == prayerName,
        orElse: () => prayerTimes.first,
      );

      print('Sending test notification for: ${prayer.name}');
      print('Message: ${prayer.message}');

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'prayer_time_channel',
            'Prayer Time Notifications',
            channelDescription: 'Notifications for prayer times',
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

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      print('Notification ID: $notificationId');

      await _localNotifications.show(
        notificationId,
        prayer.name,
        prayer.message,
        details,
      );

      print('Notification show() called successfully');
      print('=== TEST NOTIFICATION SENT ===');
      print('If you don\'t see the notification, check:');
      print('1. Notification permissions in device settings');
      print('2. App is not in Do Not Disturb mode');
      print('3. Notification channel is enabled');
    } catch (e, stackTrace) {
      print('✗ ERROR sending test notification: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all scheduled notifications (for debugging)
  Future<List<PendingNotificationRequest>> getScheduledNotifications() async {
    try {
      final notifications = await _localNotifications
          .pendingNotificationRequests();
      print('=== Scheduled Notifications (${notifications.length}) ===');
      for (var notif in notifications) {
        print('  ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
      }
      return notifications;
    } catch (e) {
      // In release builds, this may fail due to ProGuard/R8
      print(
        'Note: Could not get scheduled notifications (ProGuard/R8 issue): $e',
      );
      print(
        'This is normal in release builds. Notifications may still be scheduled.',
      );
      return [];
    }
  }

  /// Check if a specific prayer notification is scheduled
  Future<bool> isPrayerScheduled(String prayerName) async {
    try {
      final notifications = await getScheduledNotifications();
      return notifications.any((n) => n.title == prayerName);
    } catch (e) {
      print('Error checking if prayer is scheduled: $e');
      return false;
    }
  }

  /// Reschedule a specific prayer notification immediately
  Future<void> reschedulePrayerNow(String prayerName) async {
    try {
      final prayerTimes = await getPrayerTimes();
      final prayer = prayerTimes.firstWhere(
        (p) => p.name == prayerName,
        orElse: () => throw Exception('Prayer $prayerName not found'),
      );

      print('Rescheduling $prayerName notification...');

      // Cancel existing notification for this prayer
      // Note: In release builds, we may not be able to get scheduled notifications
      // So we'll cancel by ID range instead
      try {
        final notifications = await getScheduledNotifications();
        for (var notif in notifications) {
          if (notif.title == prayerName) {
            await _localNotifications.cancel(notif.id);
            print(
              'Cancelled existing ${prayerName} notification (ID: ${notif.id})',
            );
          }
        }
      } catch (e) {
        // If we can't get notifications, cancel by ID range (for this prayer)
        print(
          'Could not get notifications to cancel, cancelling by ID range...',
        );
        final prayerBaseIds = {
          'Fajr': 1000,
          'Zuhr': 2000,
          'Asr': 3000,
          'Maghrib': 4000,
          'Isha': 5000,
        };
        final baseId = prayerBaseIds[prayerName] ?? 0;
        // Cancel IDs in the range for this prayer (0-29 days)
        for (int i = 0; i < 30; i++) {
          try {
            await _localNotifications.cancel(baseId + i);
          } catch (_) {
            // Ignore errors when cancelling
          }
        }
      }

      // Schedule for today if time hasn't passed, otherwise tomorrow
      await _schedulePrayerNotification(prayer, 0);

      // Verify it was scheduled
      final isScheduled = await isPrayerScheduled(prayerName);
      if (isScheduled) {
        print('✓ $prayerName notification rescheduled successfully');
      } else {
        print('✗ Failed to reschedule $prayerName notification');
      }
    } catch (e) {
      print('Error rescheduling prayer: $e');
      rethrow;
    }
  }

  /// Check notification permissions (Android)
  Future<bool> checkNotificationPermissions() async {
    if (Platform.isAndroid) {
      try {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (androidImplementation != null) {
          final granted = await androidImplementation
              .requestNotificationsPermission();
          print('Notification permission granted: $granted');
          return granted ?? false;
        }
      } catch (e) {
        print('Error checking notification permissions: $e');
      }
    }
    return true; // iOS permissions are handled differently
  }

  /// Verify notification setup and permissions
  Future<Map<String, dynamic>> verifyNotificationSetup() async {
    final result = <String, dynamic>{
      'timezoneInitialized': _timezoneInitialized,
      'scheduledCount': 0,
      'prayerTimesCount': 0,
      'hasErrors': false,
      'errors': <String>[],
    };

    try {
      // Check timezone
      if (!_timezoneInitialized) {
        result['errors']!.add('Timezone not initialized');
        result['hasErrors'] = true;
      }

      // Check scheduled notifications
      final scheduled = await getScheduledNotifications();
      result['scheduledCount'] = scheduled.length;

      // Check prayer times
      final prayerTimes = await getPrayerTimes();
      result['prayerTimesCount'] = prayerTimes.length;

      if (prayerTimes.isNotEmpty && scheduled.isEmpty) {
        result['errors']!.add(
          'Prayer times exist but no notifications scheduled',
        );
        result['hasErrors'] = true;
      }

      // Check if we have notifications for all prayer times
      if (scheduled.length < prayerTimes.length) {
        result['errors']!.add(
          'Not all prayer times have scheduled notifications',
        );
        result['hasErrors'] = true;
      }

      print('Notification setup verification:');
      print('  - Timezone initialized: ${result['timezoneInitialized']}');
      print('  - Prayer times: ${result['prayerTimesCount']}');
      print('  - Scheduled notifications: ${result['scheduledCount']}');
      if (result['hasErrors'] as bool) {
        print('  - Errors: ${result['errors']}');
      }
    } catch (e) {
      result['errors']!.add('Error during verification: $e');
      result['hasErrors'] = true;
    }

    return result;
  }

  /// Update a specific prayer time (useful for testing or quick updates)
  Future<void> updatePrayerTime(String prayerName, String time) async {
    try {
      final prayerTimes = await getPrayerTimes();
      final updatedPrayerTimes = prayerTimes.map((prayer) {
        if (prayer.name == prayerName) {
          return PrayerTime(
            name: prayer.name,
            time: time,
            message: prayer.message,
          );
        }
        return prayer;
      }).toList();

      await updatePrayerTimes(updatedPrayerTimes);
      print('Updated $prayerName time to $time');
    } catch (e) {
      print('Error updating prayer time: $e');
      rethrow;
    }
  }

  /// Set prayer time to current time + minutes (for testing)
  Future<void> setPrayerTimeForTesting(
    String prayerName,
    int minutesFromNow,
  ) async {
    try {
      final now = DateTime.now();
      final testTime = now.add(Duration(minutes: minutesFromNow));
      final timeString =
          '${testTime.hour.toString().padLeft(2, '0')}:${testTime.minute.toString().padLeft(2, '0')}';

      print(
        'Setting $prayerName to $timeString (${minutesFromNow} minutes from now) for testing',
      );
      await updatePrayerTime(prayerName, timeString);
    } catch (e) {
      print('Error setting test prayer time: $e');
      rethrow;
    }
  }
}
