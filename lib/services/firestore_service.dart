import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import 'notification_service.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<Employee?> getEmployee(String uid) async {
    final doc = await _db.collection("employees").doc(uid).get();
    if (!doc.exists) return null;
    return Employee.fromMap(uid, doc.data()!);
  }

  Future<void> createEmployee(
    String uid,
    String name,
    String email, {
    String role = "employee",
  }) async {
    await _db.collection("employees").doc(uid).set({
      "name": name,
      "email": email,
      "role": role, // "employee" or "intern"
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> createIntern(String uid, String name, String email) async {
    await createEmployee(uid, name, email, role: "intern");
  }

  /// Ensures admin user exists in Firestore with admin role
  Future<void> ensureAdminUser(String uid, String email) async {
    final docRef = _db.collection("employees").doc(uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      // Create admin user if doesn't exist
      await docRef.set({
        "name": "Admin",
        "email": email,
        "role": "admin",
        "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      // Update existing user to admin if not already
      final data = doc.data()!;
      if (data["role"] != "admin") {
        await docRef.update({
          "role": "admin",
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> recordAttendance(
    String uid,
    String type,
    String? address,
  ) async {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    Map<String, dynamic> recordData = {
      "employeeId": uid,
      "type": type,
      "timestamp": FieldValue.serverTimestamp(),
    };

    if (address != null && address.isNotEmpty) {
      recordData["address"] = address;
    }

    await _db
        .collection("attendance")
        .doc(date)
        .collection("records")
        .add(recordData);

    // Send notification to admin about attendance
    try {
      final employee = await getEmployee(uid);
      if (employee != null) {
        // Get all admin users
        final adminsSnapshot = await _db
            .collection("employees")
            .where("role", isEqualTo: "admin")
            .get();

        final notificationService = NotificationService();
        final action = type == "check_in" ? "checked in" : "checked out";

        for (var adminDoc in adminsSnapshot.docs) {
          await notificationService.sendNotificationToUser(
            userId: adminDoc.id,
            title: "Attendance Update",
            body: "${employee.name} has $action",
            data: {
              'type': 'attendance',
              'employeeId': uid,
              'employeeName': employee.name,
              'action': type,
            },
          );
        }
      }
    } catch (e) {
      print('Error sending attendance notification: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> todayRecords() {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _db
        .collection("attendance")
        .doc(date)
        .collection("records")
        .orderBy("timestamp")
        .snapshots();
  }

  /// Check if employee has an open check-in (checked in but not checked out) for today
  Future<bool> hasOpenCheckIn(String employeeId) async {
    try {
      String date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Try with orderBy first, but if it fails, get all and filter in memory
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
      try {
        final snap = await _db
            .collection("attendance")
            .doc(date)
            .collection("records")
            .where("employeeId", isEqualTo: employeeId)
            .orderBy("timestamp")
            .get();
        docs = snap.docs;
      } catch (e) {
        // If orderBy fails (missing index), get all records and filter
        print('OrderBy query failed, using alternative method: $e');
        final allSnap = await _db
            .collection("attendance")
            .doc(date)
            .collection("records")
            .get();

        // Filter in memory
        docs = allSnap.docs.where((doc) {
          final data = doc.data();
          final empId = data["employeeId"];
          final empIdString = empId is String ? empId : empId?.toString() ?? "";
          return empIdString == employeeId;
        }).toList();
      }

      if (docs.isEmpty) {
        print(
          'hasOpenCheckIn: No records found for employee $employeeId on $date',
        );
        return false;
      }

      // Get all records for today and check the last one
      final records = docs.map((d) => d.data()).toList();

      // Sort by timestamp to ensure correct order
      records.sort((a, b) {
        try {
          final timeA = a["timestamp"]?.toDate() ?? DateTime(1970);
          final timeB = b["timestamp"]?.toDate() ?? DateTime(1970);
          return timeA.compareTo(timeB);
        } catch (e) {
          return 0;
        }
      });

      if (records.isEmpty) {
        print('hasOpenCheckIn: Records list is empty after processing');
        return false;
      }

      // Check the last record - if it's a check_in, then there's an open check-in
      final lastRecord = records.last;
      final lastType = lastRecord["type"] as String?;
      final hasOpen = lastType == "check_in";
      print(
        'hasOpenCheckIn: Found ${records.length} records, last type: $lastType, hasOpen: $hasOpen',
      );
      return hasOpen;
    } catch (e) {
      print('Error checking open check-in: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Auto-checkout employee at end of day (11:59 PM) if they forgot to check out
  Future<void> autoCheckoutAtEndOfDay(String employeeId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // Determine which date to check - if it's past 11:59 PM, check yesterday
      DateTime dateToCheck;
      DateTime checkoutTime;

      if (now.isAfter(endOfDay)) {
        // It's past 11:59 PM, so check yesterday for open check-ins
        dateToCheck = today.subtract(const Duration(days: 1));
        checkoutTime = DateTime(
          dateToCheck.year,
          dateToCheck.month,
          dateToCheck.day,
          23,
          59,
          59,
        );
      } else {
        // It's before 11:59 PM, check today but only process if we're very close to end of day
        // This handles the case where we're checking right at 11:59 PM
        dateToCheck = today;
        checkoutTime = endOfDay;

        // Only proceed if we're within the last minute of the day
        if (now.isBefore(
          DateTime(today.year, today.month, today.day, 23, 58, 0),
        )) {
          return; // Too early, don't auto-checkout yet
        }
      }

      // Check for open check-in on the target date
      String dateStr = DateFormat('yyyy-MM-dd').format(dateToCheck);
      final snap = await _db
          .collection("attendance")
          .doc(dateStr)
          .collection("records")
          .where("employeeId", isEqualTo: employeeId)
          .orderBy("timestamp")
          .get();

      final records = snap.docs.map((d) => d.data()).toList();
      if (records.isEmpty) return;

      records.sort((a, b) {
        try {
          final timeA = a["timestamp"]?.toDate() ?? DateTime(1970);
          final timeB = b["timestamp"]?.toDate() ?? DateTime(1970);
          return timeA.compareTo(timeB);
        } catch (e) {
          return 0;
        }
      });

      // Check if last record is check_in
      final lastRecord = records.last;
      if (lastRecord["type"] != "check_in") {
        return; // Already checked out or no check-in
      }

      // Check if we already have an auto-checkout for this date
      final hasAutoCheckout = records.any(
        (record) =>
            record["type"] == "check_out" && record["autoCheckout"] == true,
      );

      if (hasAutoCheckout) {
        return; // Already auto-checked out
      }

      // Create auto-checkout record at 11:59 PM of the target date
      await _db
          .collection("attendance")
          .doc(dateStr)
          .collection("records")
          .add({
            "employeeId": employeeId,
            "type": "check_out",
            "timestamp": Timestamp.fromDate(checkoutTime),
            "address": "Auto-checkout at end of day",
            "autoCheckout": true,
          });

      print(
        'Auto-checkout completed for employee $employeeId at end of day $dateStr',
      );
    } catch (e) {
      print('Error in auto-checkout: $e');
    }
  }

  Future<List<Employee>> getAllEmployees() async {
    final snap = await _db.collection("employees").get();
    return snap.docs.map((d) => Employee.fromMap(d.id, d.data())).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> recordsByDate(DateTime date) {
    String day = DateFormat('yyyy-MM-dd').format(date);
    return _db
        .collection("attendance")
        .doc(day)
        .collection("records")
        .orderBy("timestamp")
        .snapshots();
  }

  Future<void> updateProfile(String uid, String name, String? imageUrl) async {
    Map<String, dynamic> updateData = {
      "name": name,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (imageUrl != null) {
      updateData["profileImage"] = imageUrl;
    }

    await _db.collection("employees").doc(uid).update(updateData);
  }

  // Announcements methods
  Stream<QuerySnapshot<Map<String, dynamic>>> getAnnouncements() {
    return _db
        .collection("announcements")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Future<void> createAnnouncement({
    required String title,
    required String text,
    String? imageUrl,
    String? pdfUrl,
    String? adminId,
    String category = "General",
    String targetType = "all",
    String? targetDepartment,
    List<String>? targetEmployeeIds,
    bool sendPushNotification =
        true, // Default to true - always send notifications
  }) async {
    await _db.collection("announcements").add({
      "title": title,
      "text": text,
      "imageUrl": imageUrl ?? "",
      "pdfUrl": pdfUrl ?? "",
      "adminId": adminId ?? "",
      "category": category,
      "targetType": targetType,
      "targetDepartment": targetDepartment ?? "",
      "targetEmployeeIds": targetEmployeeIds ?? [],
      "seenBy": [],
      "sendPushNotification": sendPushNotification,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Always send push notifications when admin creates announcement
    try {
      final notificationService = NotificationService();

      if (targetType == "all") {
        // Send to all employees and interns (non-admin users)
        await notificationService.sendNotificationToAllEmployees(
          title: "New Announcement: $title",
          body: text.isNotEmpty ? text : "A new announcement has been posted",
          data: {'type': 'announcement', 'category': category},
        );
      } else if (targetType == "department" && targetDepartment != null) {
        // Send to specific department
        await notificationService.sendNotificationToDepartment(
          department: targetDepartment,
          title: "New Announcement: $title",
          body: text.isNotEmpty ? text : "A new announcement has been posted",
          data: {'type': 'announcement', 'category': category},
        );
      } else if (targetType == "employees" && targetEmployeeIds != null) {
        // Send to specific employees
        await notificationService.sendNotificationToUsers(
          userIds: targetEmployeeIds,
          title: "New Announcement: $title",
          body: text.isNotEmpty ? text : "A new announcement has been posted",
          data: {'type': 'announcement', 'category': category},
        );
      }
    } catch (e) {
      print('Error sending announcement notification: $e');
    }
  }

  Future<void> updateAnnouncement(
    String announcementId, {
    required String title,
    required String text,
    String? imageUrl,
    String? pdfUrl,
    String? category,
    String? targetType,
    String? targetDepartment,
    List<String>? targetEmployeeIds,
    bool? sendPushNotification,
  }) async {
    final Map<String, dynamic> updateData = {
      "title": title,
      "text": text,
      "imageUrl": imageUrl ?? "",
      "pdfUrl": pdfUrl ?? "",
    };

    if (category != null) updateData["category"] = category;
    if (targetType != null) updateData["targetType"] = targetType;
    if (targetDepartment != null)
      updateData["targetDepartment"] = targetDepartment;
    if (targetEmployeeIds != null) {
      updateData["targetEmployeeIds"] = targetEmployeeIds;
    }
    if (sendPushNotification != null) {
      updateData["sendPushNotification"] = sendPushNotification;
    }

    await _db
        .collection("announcements")
        .doc(announcementId)
        .update(updateData);
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await _db.collection("announcements").doc(announcementId).delete();
  }

  Future<void> markAnnouncementAsRead(
    String announcementId,
    String userId,
  ) async {
    await _db.collection("announcements").doc(announcementId).update({
      "seenBy": FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> markAnnouncementAsUnread(
    String announcementId,
    String userId,
  ) async {
    await _db.collection("announcements").doc(announcementId).update({
      "seenBy": FieldValue.arrayRemove([userId]),
    });
  }

  // Leave Applications methods
  Future<void> createLeaveApplication({
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required String reason,
    String? imageUrl,
    required DateTime startDate,
    required DateTime endDate,
    String? leaveType,
    String? leaveSubType,
    String? documentUrl,
    String? documentName,
  }) async {
    await _db.collection("leave_applications").add({
      "employeeId": employeeId,
      "employeeName": employeeName,
      "employeeEmail": employeeEmail,
      "reason": reason,
      "imageUrl": imageUrl ?? "",
      "startDate": Timestamp.fromDate(startDate),
      "endDate": Timestamp.fromDate(endDate),
      if (leaveType != null) "leaveType": leaveType,
      if (leaveSubType != null) "leaveSubType": leaveSubType,
      if (documentUrl != null) "documentUrl": documentUrl,
      if (documentName != null) "documentName": documentName,
      "status": "pending", // pending, approved, rejected
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Send notification to all admins about new leave application
    try {
      final adminsSnapshot = await _db
          .collection("employees")
          .where("role", isEqualTo: "admin")
          .get();

      final notificationService = NotificationService();
      final dateRange =
          "${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}";

      for (var adminDoc in adminsSnapshot.docs) {
        await notificationService.sendNotificationToUser(
          userId: adminDoc.id,
          title: "New Leave Application",
          body:
              "$employeeName has submitted a leave application for $dateRange",
          data: {
            'type': 'leave_application',
            'employeeId': employeeId,
            'employeeName': employeeName,
            'status': 'pending',
          },
        );
      }
    } catch (e) {
      print('Error sending leave application notification to admin: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getLeaveApplications() {
    return _db
        .collection("leave_applications")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getEmployeeLeaveApplications(
    String employeeId,
  ) {
    // Query without orderBy to avoid composite index requirement
    // Sorting will be done in the UI
    return _db
        .collection("leave_applications")
        .where("employeeId", isEqualTo: employeeId)
        .snapshots();
  }

  Future<void> updateLeaveApplicationStatus(
    String applicationId,
    String status,
  ) async {
    // Get leave application data first
    final leaveAppDoc = await _db
        .collection("leave_applications")
        .doc(applicationId)
        .get();

    if (!leaveAppDoc.exists) return;

    final leaveData = leaveAppDoc.data()!;
    final employeeId = leaveData["employeeId"] as String?;
    final startDate = leaveData["startDate"];
    final endDate = leaveData["endDate"];

    await _db.collection("leave_applications").doc(applicationId).update({
      "status": status,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // Send notification to employee about status change
    if (employeeId != null) {
      try {
        final notificationService = NotificationService();
        String statusText = status == "approved" ? "approved" : "rejected";
        String dateRange = "";

        if (startDate != null && endDate != null) {
          try {
            final start = startDate is Timestamp
                ? startDate.toDate()
                : DateTime.parse(startDate.toString());
            final end = endDate is Timestamp
                ? endDate.toDate()
                : DateTime.parse(endDate.toString());
            dateRange =
                " (${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)})";
          } catch (e) {
            // Ignore date parsing errors
          }
        }

        await notificationService.sendNotificationToUser(
          userId: employeeId,
          title: "Leave Application $statusText",
          body:
              "Your leave application$dateRange has been $statusText by the admin",
          data: {
            'type': 'leave_application',
            'applicationId': applicationId,
            'status': status,
          },
        );
      } catch (e) {
        print('Error sending leave application notification: $e');
      }
    }
  }

  // Admin methods for employee attendance
  Future<List<Map<String, dynamic>>> getTodayEmployeeAttendance() async {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snap = await _db
        .collection("attendance")
        .doc(date)
        .collection("records")
        .orderBy("timestamp")
        .get();

    final records = snap.docs.map((d) => d.data()).toList();
    return records;
  }

  Future<List<Map<String, dynamic>>> getEmployeeAttendanceForMonth(
    String employeeId,
    DateTime month,
  ) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final allRecords = <Map<String, dynamic>>[];

      for (
        var date = startDate;
        date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        String dateStr = DateFormat('yyyy-MM-dd').format(date);

        try {
          // Fetch all records for the date and filter in memory
          // This avoids composite index requirements
          final snap = await _db
              .collection("attendance")
              .doc(dateStr)
              .collection("records")
              .get();

          for (var doc in snap.docs) {
            final data = doc.data();
            // Filter by employeeId in memory (handle both String and dynamic types)
            final recordEmployeeId = data["employeeId"];
            String recordEmployeeIdStr;
            if (recordEmployeeId == null) {
              recordEmployeeIdStr = "";
            } else if (recordEmployeeId is String) {
              recordEmployeeIdStr = recordEmployeeId;
            } else {
              recordEmployeeIdStr = recordEmployeeId.toString().trim();
            }

            if (recordEmployeeIdStr == employeeId.trim()) {
              allRecords.add({...data, 'date': dateStr});
            }
          }
        } catch (e) {
          // If document doesn't exist, continue to next date
          // This is normal for dates with no attendance records
          continue;
        }
      }

      // Sort by timestamp
      allRecords.sort((a, b) {
        final timeA = a["timestamp"]?.toDate() ?? DateTime(1970);
        final timeB = b["timestamp"]?.toDate() ?? DateTime(1970);
        return timeA.compareTo(timeB);
      });

      print(
        'getEmployeeAttendanceForMonth: Found ${allRecords.length} records for employee $employeeId in month ${month.year}-${month.month}',
      );
      return allRecords;
    } catch (e) {
      print('Error in getEmployeeAttendanceForMonth: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllEmployeeAttendance(
    String employeeId,
  ) async {
    try {
      final allRecords = <Map<String, dynamic>>[];
      int totalRecordsChecked = 0;
      int matchingRecords = 0;

      print(
        'getAllEmployeeAttendance: Looking for employeeId="$employeeId" (type: ${employeeId.runtimeType})',
      );

      // Use CollectionGroup to query all "records" subcollections across all attendance documents
      // This is more efficient and works even if we can't list the parent collection
      try {
        final recordsSnapshot = await _db.collectionGroup("records").get();

        totalRecordsChecked = recordsSnapshot.docs.length;
        print(
          'getAllEmployeeAttendance: Found $totalRecordsChecked total records across all dates',
        );

        for (var recordDoc in recordsSnapshot.docs) {
          try {
            final data = recordDoc.data();

            // Ensure we have the required fields
            if (!data.containsKey("employeeId") ||
                !data.containsKey("timestamp")) {
              continue;
            }

            // Filter by employeeId in memory (handle both String and dynamic types)
            final recordEmployeeId = data["employeeId"];

            // Handle different types of employeeId - be more flexible
            String recordEmployeeIdStr;
            if (recordEmployeeId == null) {
              continue; // Skip records without employeeId
            } else if (recordEmployeeId is String) {
              recordEmployeeIdStr = recordEmployeeId.trim();
            } else {
              recordEmployeeIdStr = recordEmployeeId.toString().trim();
            }

            final employeeIdStr = employeeId.trim();

            // Debug: Print first few comparisons to see what's happening
            if (matchingRecords < 3 && totalRecordsChecked <= 10) {
              print(
                'getAllEmployeeAttendance: Comparing recordEmployeeId="$recordEmployeeIdStr" (original type: ${recordEmployeeId.runtimeType}) with employeeId="$employeeIdStr" - Match: ${recordEmployeeIdStr == employeeIdStr}',
              );
            }

            // Use both exact match and case-insensitive comparison
            if (recordEmployeeIdStr == employeeIdStr ||
                recordEmployeeIdStr.toLowerCase() ==
                    employeeIdStr.toLowerCase()) {
              matchingRecords++;

              // Extract date from the document path
              // Path format: attendance/{date}/records/{recordId}
              String? dateStr;
              try {
                final pathParts = recordDoc.reference.path.split('/');
                if (pathParts.length >= 2 && pathParts[0] == 'attendance') {
                  dateStr = pathParts[1];
                }
              } catch (e) {
                // If we can't extract date, try to get it from the data or use a default
                dateStr = data["date"] as String?;
              }

              // Ensure timestamp is properly included
              final recordData = {
                ...data,
                if (dateStr != null) 'date': dateStr,
              };

              // Verify timestamp exists and is valid
              if (recordData["timestamp"] != null) {
                allRecords.add(recordData);
                if (matchingRecords <= 3) {
                  print(
                    'getAllEmployeeAttendance: Added record for employee $employeeId from date ${dateStr ?? "unknown"}',
                  );
                }
              } else {
                print(
                  'Warning: Record found but timestamp is null for employee $employeeId',
                );
              }
            }
          } catch (e) {
            print('Error processing record: $e');
            continue;
          }
        }
      } catch (e) {
        print('Error using collectionGroup query: $e');
        // Fallback: Try the old method if collectionGroup fails
        print('Falling back to date-based iteration method...');

        // Get a wide date range (last 2 years to future 1 year)
        final now = DateTime.now();
        final startDate = DateTime(now.year - 2, 1, 1);
        final endDate = DateTime(now.year + 1, 12, 31);

        for (
          var date = startDate;
          date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
          date = date.add(const Duration(days: 1))
        ) {
          String dateStr = DateFormat('yyyy-MM-dd').format(date);

          try {
            final snap = await _db
                .collection("attendance")
                .doc(dateStr)
                .collection("records")
                .get();

            totalRecordsChecked += snap.docs.length;

            for (var doc in snap.docs) {
              final data = doc.data();
              final recordEmployeeId = data["employeeId"];

              String recordEmployeeIdStr;
              if (recordEmployeeId == null) {
                continue;
              } else if (recordEmployeeId is String) {
                recordEmployeeIdStr = recordEmployeeId.trim();
              } else {
                recordEmployeeIdStr = recordEmployeeId.toString().trim();
              }

              if (recordEmployeeIdStr == employeeId.trim()) {
                matchingRecords++;
                allRecords.add({...data, 'date': dateStr});
              }
            }
          } catch (e) {
            continue;
          }
        }
      }

      // Sort by timestamp
      allRecords.sort((a, b) {
        try {
          final timeA = a["timestamp"]?.toDate() ?? DateTime(1970);
          final timeB = b["timestamp"]?.toDate() ?? DateTime(1970);
          return timeA.compareTo(timeB);
        } catch (e) {
          return 0;
        }
      });

      print(
        'getAllEmployeeAttendance: Checked $totalRecordsChecked total records, found $matchingRecords matching records for employee "$employeeId"',
      );
      print('getAllEmployeeAttendance: Returning ${allRecords.length} records');

      if (allRecords.isEmpty && totalRecordsChecked > 0) {
        print(
          'WARNING: getAllEmployeeAttendance found $totalRecordsChecked records but none matched employeeId="$employeeId"',
        );
      }

      return allRecords;
    } catch (e, stackTrace) {
      print('Error in getAllEmployeeAttendance: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Daily Progress Submission methods for Interns
  Future<void> submitDailyProgress({
    required String internId,
    required String internName,
    required String internEmail,
    required String topicName,
    required DateTime date,
    String? documentUrl,
    String? documentName,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await _db.collection("daily_progress").add({
      "internId": internId,
      "internName": internName,
      "internEmail": internEmail,
      "topicName": topicName,
      "date": dateStr,
      "documentUrl": documentUrl ?? "",
      "documentName": documentName ?? "",
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Send notification to admin about new progress submission
    try {
      // Get all admin users
      final adminsSnapshot = await _db
          .collection("employees")
          .where("role", isEqualTo: "admin")
          .get();

      final notificationService = NotificationService();

      for (var adminDoc in adminsSnapshot.docs) {
        await notificationService.sendNotificationToUser(
          userId: adminDoc.id,
          title: "New Progress Submission",
          body: "$internName submitted progress: $topicName",
          data: {
            'type': 'progress_submission',
            'internId': internId,
            'internName': internName,
            'topicName': topicName,
            'date': dateStr,
          },
        );
      }
    } catch (e) {
      print('Error sending progress submission notification to admin: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAllInternProgress() {
    return _db
        .collection("daily_progress")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// Get today's intern progress submissions
  /// Note: Returns all records - filtering by today should be done in the UI to avoid composite index
  Stream<QuerySnapshot<Map<String, dynamic>>> getTodayInternProgress() {
    // Return all records - the UI will filter by today
    // This avoids composite index requirements
    return _db
        .collection("daily_progress")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// Get intern progress for a specific month
  /// Note: Returns all records - filtering by month should be done in the UI
  Stream<QuerySnapshot<Map<String, dynamic>>> getInternProgressForMonth(
    DateTime month,
  ) {
    // Return all records - the UI will filter by month
    // This avoids composite index requirements
    return _db
        .collection("daily_progress")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getInternProgressByIntern(
    String internId,
  ) {
    // Return empty stream if internId is empty to prevent query errors
    if (internId.isEmpty) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    try {
      return _db
          .collection("daily_progress")
          .where("internId", isEqualTo: internId)
          .orderBy("createdAt", descending: true)
          .snapshots()
          .handleError((error) {
        print('Error in getInternProgressByIntern stream: $error');
        // Re-throw the error so StreamBuilder can handle it
        throw error;
      });
    } catch (e) {
      print('Error creating getInternProgressByIntern stream: $e');
      // Return a stream that emits an error
      return Stream<QuerySnapshot<Map<String, dynamic>>>.error(e);
    }
  }

  Future<List<Map<String, dynamic>>> getInternProgressForDate(
    DateTime date,
  ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final snapshot = await _db
        .collection("daily_progress")
        .where("date", isEqualTo: dateStr)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> deleteProgressSubmission(String progressId) async {
    await _db.collection("daily_progress").doc(progressId).delete();
  }

  /// Update remarks on a daily progress submission
  Future<void> updateProgressRemarks(
    String progressId,
    String remarks,
    String? adminId,
  ) async {
    // Get the progress document to find the intern ID before updating
    final progressDoc = await _db.collection("daily_progress").doc(progressId).get();
    
    if (!progressDoc.exists) {
      print('Error: Progress document not found: $progressId');
      return;
    }
    
    final progressData = progressDoc.data();
    final internId = progressData?["internId"] as String?;
    final topicName = progressData?["topicName"] as String? ?? "";
    final previousRemarks = progressData?["remarks"] as String? ?? "";

    print('updateProgressRemarks: progressId=$progressId, internId=$internId, remarks length=${remarks.length}');

    await _db.collection("daily_progress").doc(progressId).update({
      "remarks": remarks,
      "remarksUpdatedAt": FieldValue.serverTimestamp(),
      if (adminId != null) "remarksUpdatedBy": adminId,
    });

    // Send notification to intern about remarks
    // Only send if remarks are not empty and internId exists
    if (internId != null && internId.isNotEmpty && remarks.trim().isNotEmpty) {
      try {
        print('=== SENDING REMARKS NOTIFICATION ===');
        print('Intern ID: $internId');
        print('Topic: $topicName');
        print('Remarks length: ${remarks.length}');
        
        // Verify intern exists in employees collection
        final internDoc = await _db.collection('employees').doc(internId).get();
        if (!internDoc.exists) {
          print('ERROR: Intern document not found in employees collection: $internId');
          print('Progress data: ${progressData?.keys.toList()}');
          // Still try to send notification - maybe the user exists but document structure is different
        } else {
          final internData = internDoc.data();
          final internName = internData?['name'] as String? ?? 'Unknown';
          final hasToken = internData?.containsKey('fcmToken') == true;
          print('Intern found: $internName, Has FCM token: $hasToken');
        }
        
        final notificationService = NotificationService();
        final isNewRemarks = previousRemarks.trim().isEmpty;
        
        final title = isNewRemarks ? "New Remarks on Your Progress" : "Remarks Updated";
        final body = isNewRemarks
            ? "Admin added remarks on your progress: $topicName"
            : "Admin updated remarks on your progress: $topicName";
        
        print('Notification title: $title');
        print('Notification body: $body');
        
        // Ensure all data values are strings for FCM compatibility
        final notificationData = <String, String>{
          'type': 'progress_remarks',
          'progressId': progressId,
          'topicName': topicName,
          'isNew': isNewRemarks ? 'true' : 'false', // Explicitly use string 'true'/'false'
        };
        
        await notificationService.sendNotificationToUser(
          userId: internId,
          title: title,
          body: body,
          data: notificationData,
        );
        print('=== REMARKS NOTIFICATION REQUEST CREATED ===');
      } catch (e, stackTrace) {
        print('=== ERROR SENDING REMARKS NOTIFICATION ===');
        print('Error: $e');
        print('Stack trace: $stackTrace');
        // Re-throw to ensure the error is visible
        rethrow;
      }
    } else {
      print('=== SKIPPING REMARKS NOTIFICATION ===');
      print('Reason: internId=${internId?.isEmpty ?? true}, remarks empty=${remarks.trim().isEmpty}');
      print('InternId value: $internId');
      print('Remarks value: ${remarks.substring(0, remarks.length > 50 ? 50 : remarks.length)}...');
    }
  }
}
